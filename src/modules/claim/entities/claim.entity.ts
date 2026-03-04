import {
    Entity,
    Column,
    ManyToOne,
    OneToMany,
    JoinColumn,
    Index,
} from 'typeorm';
import { BaseTenantEntity } from '../../../common/entities/base-tenant.entity';
import {
    ClaimStatus,
    ClaimValidationStatus,
    ClaimValidationType,
    InvestigationStatus,
    FraudReviewOutcome,
    FraudRiskSeverity,
} from '../../../common/enums';

// ─────────────────────────────────────────────────────────────────────────────
// Claim — master claim record.
//
// State machine:
//   SUBMITTED → VALIDATED | VALIDATION_FAILED
//   VALIDATED → UNDER_INVESTIGATION | FRAUD_REVIEW | ASSESSED
//   FRAUD_REVIEW → ASSESSED | REJECTED | ESCALATED
//   ASSESSED → APPROVED | REJECTED
//   APPROVED → PARTIALLY_PAID | PAID
//   CLOSED → REOPENED (creates new top-level claim with parent_claim_id)
//
// Temporal workflow: ClaimWorkflow manages the entire state machine.
// ─────────────────────────────────────────────────────────────────────────────
@Entity('claims')
@Index(['tenantId', 'policyId', 'status'])           // ← sub-200ms claim validation
@Index(['tenantId', 'status', 'createdAt'])
@Index(['tenantId', 'claimNumber'], { unique: true })
@Index(['tenantId', 'parentClaimId'])
export class Claim extends BaseTenantEntity {
    /** Human-readable claim number e.g. "CLM-2024-007890" */
    @Column({ name: 'claim_number', length: 60 })
    claimNumber!: string;

    @Column({ name: 'policy_id', type: 'uuid' })
    policyId!: string;

    @Column({ name: 'policy_coverage_id', type: 'uuid' })
    policyCoverageId!: string;

    @Column({ type: 'enum', enum: ClaimStatus, default: ClaimStatus.SUBMITTED })
    status!: ClaimStatus;

    @Column({ name: 'loss_date', type: 'date' })
    lossDate!: string;

    @Column({ name: 'reported_date', type: 'date' })
    reportedDate!: string;

    @Column({ name: 'claimed_amount', type: 'numeric', precision: 14, scale: 2 })
    claimedAmount!: string;

    @Column({ name: 'approved_amount', type: 'numeric', precision: 14, scale: 2, nullable: true })
    approvedAmount!: string | null;

    @Column({ name: 'paid_amount', type: 'numeric', precision: 14, scale: 2, default: 0 })
    paidAmount!: string;

    /** Narrative description of the loss event */
    @Column({ name: 'loss_description', type: 'text' })
    lossDescription!: string;

    /** Raw claimant input data (form fields, structured answers) */
    @Column({ name: 'claimant_data', type: 'jsonb' })
    claimantData!: Record<string, unknown>;

    /** Temporal workflow run ID */
    @Column({ name: 'temporal_workflow_id', type: 'varchar', length: 255, nullable: true })
    temporalWorkflowId!: string | null;

    /** Self-referential FK for reopened claims — tracks claim lineage */
    @Column({ name: 'parent_claim_id', type: 'uuid', nullable: true })
    parentClaimId!: string | null;

    @ManyToOne(() => Claim, { nullable: true })
    @JoinColumn({ name: 'parent_claim_id' })
    parentClaim!: Claim | null;

    /** Maximum 3 reopens to prevent infinite cycles */
    @Column({ name: 'reopen_count', type: 'int', default: 0 })
    reopenCount!: number;

    @Column({ name: 'submitted_by', type: 'uuid', nullable: true })
    submittedBy!: string | null;

    @Column({ name: 'reopen_reason', type: 'text', nullable: true })
    reopenReason!: string | null;

    @Column({ name: 'assigned_adjuster_id', type: 'uuid', nullable: true })
    assignedAdjusterId!: string | null;

    @OneToMany(() => ClaimItem, (i) => i.claim)
    items!: ClaimItem[];

    @OneToMany(() => ClaimDocument, (d) => d.claim)
    documents!: ClaimDocument[];

    @OneToMany(() => ClaimStatusHistory, (h) => h.claim)
    statusHistory!: ClaimStatusHistory[];
}

// ─────────────────────────────────────────────────────────────────────────────
// ClaimItem — line items for individual loss components within a claim
// ─────────────────────────────────────────────────────────────────────────────
@Entity('claim_items')
@Index(['tenantId', 'claimId'])
export class ClaimItem extends BaseTenantEntity {
    @Column({ name: 'claim_id', type: 'uuid' })
    claimId!: string;

    @ManyToOne(() => Claim, (c) => c.items, { onDelete: 'CASCADE' })
    @JoinColumn({ name: 'claim_id' })
    claim!: Claim;

    @Column({ length: 200 })
    description!: string;

    @Column({ name: 'claimed_amount', type: 'numeric', precision: 14, scale: 2 })
    claimedAmount!: string;

    @Column({ name: 'approved_amount', type: 'numeric', precision: 14, scale: 2, nullable: true })
    approvedAmount!: string | null;

    @Column({ type: 'jsonb', default: {} })
    metadata!: Record<string, unknown>;
}

// ─────────────────────────────────────────────────────────────────────────────
// ClaimDocument — supporting documents linked to a claim (S3 references)
// ─────────────────────────────────────────────────────────────────────────────
@Entity('claim_documents')
@Index(['tenantId', 'claimId'])
export class ClaimDocument extends BaseTenantEntity {
    @Column({ name: 'claim_id', type: 'uuid' })
    claimId!: string;

    @ManyToOne(() => Claim, (c) => c.documents, { onDelete: 'CASCADE' })
    @JoinColumn({ name: 'claim_id' })
    claim!: Claim;

    @Column({ name: 'document_type', length: 100 })
    documentType!: string;

    @Column({ name: 'file_name', length: 300 })
    fileName!: string;

    @Column({ name: 's3_key', length: 500 })
    s3Key!: string;

    @Column({ name: 'mime_type', length: 100 })
    mimeType!: string;

    @Column({ name: 'file_size_bytes', type: 'bigint', nullable: true })
    fileSizeBytes!: string | null;

    @Column({ name: 'uploaded_by', type: 'uuid' })
    uploadedBy!: string;
}

// ─────────────────────────────────────────────────────────────────────────────
// ClaimStatusHistory — immutable lifecycle audit trail
// ─────────────────────────────────────────────────────────────────────────────
@Entity('claim_status_history')
@Index(['tenantId', 'claimId', 'occurredAt'])
export class ClaimStatusHistory extends BaseTenantEntity {
    @Column({ name: 'claim_id', type: 'uuid' })
    claimId!: string;

    @ManyToOne(() => Claim, (c) => c.statusHistory, { onDelete: 'CASCADE' })
    @JoinColumn({ name: 'claim_id' })
    claim!: Claim;

    @Column({ name: 'from_status', type: 'enum', enum: ClaimStatus, nullable: true })
    fromStatus!: ClaimStatus | null;

    @Column({ name: 'to_status', type: 'enum', enum: ClaimStatus })
    toStatus!: ClaimStatus;

    @Column({ type: 'text', nullable: true })
    reason!: string | null;

    @Column({ name: 'triggered_by', type: 'uuid', nullable: true })
    triggeredBy!: string | null;

    @Column({ name: 'occurred_at', type: 'timestamptz', default: () => 'NOW()' })
    occurredAt!: Date;

    @Column({ type: 'jsonb', default: {} })
    context!: Record<string, unknown>;
}

// ─────────────────────────────────────────────────────────────────────────────
// ClaimValidation — system and manual validation check results
// ─────────────────────────────────────────────────────────────────────────────
@Entity('claim_validations')
@Index(['tenantId', 'claimId', 'validationType'])
export class ClaimValidation extends BaseTenantEntity {
    @Column({ name: 'claim_id', type: 'uuid' })
    claimId!: string;

    @Column({ name: 'validation_type', type: 'enum', enum: ClaimValidationType })
    validationType!: ClaimValidationType;

    @Column({ type: 'enum', enum: ClaimValidationStatus })
    status!: ClaimValidationStatus;

    /** Detailed validation output (rule name, threshold vs actual, etc.) */
    @Column({ name: 'validation_detail', type: 'jsonb', default: {} })
    validationDetail!: Record<string, unknown>;

    @Column({ name: 'validated_at', type: 'timestamptz', default: () => 'NOW()' })
    validatedAt!: Date;

    /** NULL = automated system check; non-null = manual reviewer */
    @Column({ name: 'validated_by', type: 'uuid', nullable: true })
    validatedBy!: string | null;
}

// ─────────────────────────────────────────────────────────────────────────────
// ClaimInvestigation — investigation assignment and case tracking
// ─────────────────────────────────────────────────────────────────────────────
@Entity('claim_investigations')
@Index(['tenantId', 'claimId'])
@Index(['tenantId', 'assignedInvestigatorId', 'status'])
export class ClaimInvestigation extends BaseTenantEntity {
    @Column({ name: 'claim_id', type: 'uuid' })
    claimId!: string;

    @Column({ name: 'assigned_investigator_id', type: 'uuid', nullable: true })
    assignedInvestigatorId!: string | null;

    @Column({ type: 'enum', enum: InvestigationStatus, default: InvestigationStatus.OPEN })
    status!: InvestigationStatus;

    @Column({ name: 'investigation_type', type: 'varchar', length: 100, nullable: true })
    investigationType!: string | null;

    @Column({ name: 'started_at', type: 'timestamptz', nullable: true })
    startedAt!: Date | null;

    @Column({ name: 'due_date', type: 'date', nullable: true })
    dueDate!: string | null;

    @Column({ name: 'completed_at', type: 'timestamptz', nullable: true })
    completedAt!: Date | null;

    @Column({ name: 'findings', type: 'text', nullable: true })
    findings!: string | null;

    @Column({ name: 'evidence_summary', type: 'jsonb', default: [] })
    evidenceSummary!: Array<Record<string, unknown>>;

    @OneToMany(() => InvestigationActivity, (a) => a.investigation)
    activities!: InvestigationActivity[];
}

@Entity('investigation_activities')
@Index(['tenantId', 'investigationId', 'performedAt'])
export class InvestigationActivity extends BaseTenantEntity {
    @Column({ name: 'investigation_id', type: 'uuid' })
    investigationId!: string;

    @ManyToOne(() => ClaimInvestigation, (i) => i.activities, { onDelete: 'CASCADE' })
    @JoinColumn({ name: 'investigation_id' })
    investigation!: ClaimInvestigation;

    @Column({ name: 'activity_type', length: 100 })
    activityType!: string;

    @Column({ type: 'text' })
    description!: string;

    @Column({ name: 'performed_by', type: 'uuid' })
    performedBy!: string;

    @Column({ name: 'performed_at', type: 'timestamptz', default: () => 'NOW()' })
    performedAt!: Date;

    @Column({ type: 'jsonb', default: {} })
    attachments!: Record<string, unknown>;
}

// ─────────────────────────────────────────────────────────────────────────────
// FraudReview — aggregated fraud scoring result per claim
// ─────────────────────────────────────────────────────────────────────────────
@Entity('fraud_reviews')
@Index(['tenantId', 'claimId'])
@Index(['tenantId', 'reviewOutcome'])
export class FraudReview extends BaseTenantEntity {
    @Column({ name: 'claim_id', type: 'uuid' })
    claimId!: string;

    @Column({ name: 'overall_score', type: 'numeric', precision: 5, scale: 2, default: 0 })
    overallScore!: string;

    @Column({ name: 'risk_level', type: 'enum', enum: FraudRiskSeverity, nullable: true })
    riskLevel!: FraudRiskSeverity | null;

    @Column({ name: 'review_outcome', type: 'enum', enum: FraudReviewOutcome, nullable: true })
    reviewOutcome!: FraudReviewOutcome | null;

    @Column({ name: 'reviewed_at', type: 'timestamptz', nullable: true })
    reviewedAt!: Date | null;

    @Column({ name: 'reviewed_by', type: 'uuid', nullable: true })
    reviewedBy!: string | null;

    @Column({ name: 'reviewer_notes', type: 'text', nullable: true })
    reviewerNotes!: string | null;

    @OneToMany(() => FraudReviewFlag, (f) => f.fraudReview)
    flags!: FraudReviewFlag[];
}

@Entity('fraud_review_flags')
@Index(['tenantId', 'fraudReviewId'])
export class FraudReviewFlag extends BaseTenantEntity {
    @Column({ name: 'fraud_review_id', type: 'uuid' })
    fraudReviewId!: string;

    @ManyToOne(() => FraudReview, (r) => r.flags, { onDelete: 'CASCADE' })
    @JoinColumn({ name: 'fraud_review_id' })
    fraudReview!: FraudReview;

    @Column({ name: 'fraud_rule_id', type: 'uuid' })
    fraudRuleId!: string;

    /** Name of the triggered rule */
    @Column({ name: 'rule_name', length: 200 })
    ruleName!: string;

    @Column({ name: 'score_contribution', type: 'numeric', precision: 5, scale: 2 })
    scoreContribution!: string;

    @Column({ name: 'flag_detail', type: 'jsonb', default: {} })
    flagDetail!: Record<string, unknown>;
}

// ─────────────────────────────────────────────────────────────────────────────
// ClaimAssessment — adjuster's final assessment and recommended payout amount
// ─────────────────────────────────────────────────────────────────────────────
@Entity('claim_assessments')
@Index(['tenantId', 'claimId'])
export class ClaimAssessment extends BaseTenantEntity {
    @Column({ name: 'claim_id', type: 'uuid' })
    claimId!: string;

    @Column({ name: 'assessed_by', type: 'uuid' })
    assessedBy!: string;

    @Column({ name: 'assessed_amount', type: 'numeric', precision: 14, scale: 2 })
    assessedAmount!: string;

    @Column({ name: 'deductible_applied', type: 'numeric', precision: 14, scale: 2, default: 0 })
    deductibleApplied!: string;

    @Column({ name: 'net_payout', type: 'numeric', precision: 14, scale: 2 })
    netPayout!: string;

    @Column({ name: 'assessment_notes', type: 'text', nullable: true })
    assessmentNotes!: string | null;

    /** Itemized assessment breakdown */
    @Column({ name: 'line_item_assessment', type: 'jsonb', default: [] })
    lineItemAssessment!: Array<{
        claimItemId: string;
        claimedAmount: number;
        approvedAmount: number;
        rejectionReason?: string;
    }>;

    @Column({ name: 'assessed_at', type: 'timestamptz', default: () => 'NOW()' })
    assessedAt!: Date;

    /** Reserve amount set aside for this claim */
    @Column({ name: 'reserve_amount', type: 'numeric', precision: 14, scale: 2, nullable: true })
    reserveAmount!: string | null;
}
