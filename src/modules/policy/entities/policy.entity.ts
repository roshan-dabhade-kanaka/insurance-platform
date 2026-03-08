import {
    Entity,
    Column,
    ManyToOne,
    OneToMany,
    JoinColumn,
    Index,
    Unique,
} from 'typeorm';
import { BaseTenantEntity } from '../../../common/entities/base-tenant.entity';
import { PolicyStatus } from '../../../common/enums';
import { CoverageOption } from '../../product/entities/product.entity';

// ─────────────────────────────────────────────────────────────────────────────
// Policy — the issued insurance contract.
//
// State machine:
//   PENDING_ISSUANCE → IN_FORCE → LAPSED | SUSPENDED | CANCELLED | EXPIRED
//   LAPSED | CANCELLED → REINSTATED (with new reinstatement record)
//   IN_FORCE → MATURED
//
// Temporal workflow: PolicyLifecycleWorkflow handles renewals, lapse notices,
// reinstatement processing.
// ─────────────────────────────────────────────────────────────────────────────
@Entity('policies')
@Index(['tenantId', 'status', 'policyNumber'])
@Index(['tenantId', 'quoteId'], { unique: true })
@Index(['tenantId', 'policyHolderRef'])
@Index(['policyNumber'], { unique: true })
export class Policy extends BaseTenantEntity {
    /** Human-readable policy number e.g. "POL-2024-000456" */
    @Column({ name: 'policy_number', length: 60 })
    policyNumber!: string;

    @Column({ name: 'quote_id', type: 'uuid' })
    quoteId!: string;

    @Column({ name: 'product_version_id', type: 'uuid' })
    productVersionId!: string;

    /** External policyholder / customer CRM reference */
    @Column({ name: 'policy_holder_ref', length: 200 })
    policyHolderRef!: string;

    /** Full policyholder data snapshot at issuance */
    @Column({ name: 'policy_holder_data', type: 'jsonb' })
    policyHolderData!: Record<string, unknown>;

    @Column({ type: 'enum', enum: PolicyStatus, default: PolicyStatus.PENDING_ISSUANCE })
    status!: PolicyStatus;

    @Column({ name: 'inception_date', type: 'date' })
    inceptionDate!: string;

    @Column({ name: 'expiry_date', type: 'date' })
    expiryDate!: string;

    @Column({ name: 'annual_premium', type: 'numeric', precision: 14, scale: 2 })
    annualPremium!: string;

    @Column({ name: 'premium_snapshot_id', type: 'uuid' })
    premiumSnapshotId!: string;

    @Column({ name: 'issued_at', type: 'timestamptz', nullable: true })
    issuedAt!: Date | null;

    @Column({ name: 'issued_by', type: 'uuid', nullable: true })
    issuedBy!: string | null;

    /** Temporal workflow run ID */
    @Column({ name: 'temporal_workflow_id', type: 'varchar', length: 255, nullable: true })
    temporalWorkflowId!: string | null;

    /** Parent policy ID for reinstatements — creates renewal chain */
    @Column({ name: 'parent_policy_id', type: 'uuid', nullable: true })
    parentPolicyId!: string | null;

    @OneToMany(() => PolicyCoverage, (c) => c.policy)
    coverages!: PolicyCoverage[];

    @OneToMany(() => PolicyRider, (r) => r.policy)
    policyRiders!: PolicyRider[];

    @OneToMany(() => PolicyStatusHistory, (h) => h.policy)
    statusHistory!: PolicyStatusHistory[];

    @OneToMany(() => PolicyEndorsement, (e) => e.policy)
    endorsements!: PolicyEndorsement[];
}

// ─────────────────────────────────────────────────────────────────────────────
// PolicyCoverage — active coverages on an issued policy
// ─────────────────────────────────────────────────────────────────────────────
@Entity('policy_coverages')
@Index(['tenantId', 'policyId'])
export class PolicyCoverage extends BaseTenantEntity {
    @Column({ name: 'policy_id', type: 'uuid' })
    policyId!: string;

    @ManyToOne(() => Policy, (p) => p.coverages, { onDelete: 'CASCADE' })
    @JoinColumn({ name: 'policy_id' })
    policy!: Policy;

    @Column({ name: 'coverage_option_id', type: 'uuid' })
    coverageOptionId!: string;

    @ManyToOne(() => CoverageOption)
    @JoinColumn({ name: 'coverage_option_id' })
    coverageOption!: CoverageOption;

    @Column({ name: 'sum_insured', type: 'numeric', precision: 14, scale: 2 })
    sumInsured!: string;

    @Column({ name: 'deductible_id', type: 'uuid', nullable: true })
    deductibleId!: string | null;

    @Column({ name: 'is_active', default: true })
    isActive!: boolean;

    @Column({ name: 'deductible_amount', type: 'numeric', precision: 14, scale: 2, default: 0 })
    deductibleAmount!: string;

    @Column({ name: 'waiting_period_days', type: 'int', default: 0 })
    waitingPeriodDays!: number;

    @Column({ type: 'jsonb', default: {} })
    parameters!: Record<string, unknown>;
}

// ─────────────────────────────────────────────────────────────────────────────
// PolicyRider — active riders on an issued policy
// ─────────────────────────────────────────────────────────────────────────────
@Entity('policy_riders')
@Index(['tenantId', 'policyId'])
export class PolicyRider extends BaseTenantEntity {
    @Column({ name: 'policy_id', type: 'uuid' })
    policyId!: string;

    @ManyToOne(() => Policy, (p) => p.policyRiders, { onDelete: 'CASCADE' })
    @JoinColumn({ name: 'policy_id' })
    policy!: Policy;

    @Column({ name: 'rider_id', type: 'uuid' })
    riderId!: string;

    @Column({ name: 'rider_premium', type: 'numeric', precision: 14, scale: 2, default: 0 })
    riderPremium!: string;

    @Column({ name: 'is_active', default: true })
    isActive!: boolean;
}

// ─────────────────────────────────────────────────────────────────────────────
// PolicyStatusHistory — immutable lifecycle audit trail
// ─────────────────────────────────────────────────────────────────────────────
@Entity('policy_status_history')
@Index(['tenantId', 'policyId', 'occurredAt'])
export class PolicyStatusHistory extends BaseTenantEntity {
    @Column({ name: 'policy_id', type: 'uuid' })
    policyId!: string;

    @ManyToOne(() => Policy, (p) => p.statusHistory, { onDelete: 'CASCADE' })
    @JoinColumn({ name: 'policy_id' })
    policy!: Policy;

    @Column({ name: 'from_status', type: 'enum', enum: PolicyStatus, nullable: true })
    fromStatus!: PolicyStatus | null;

    @Column({ name: 'to_status', type: 'enum', enum: PolicyStatus })
    toStatus!: PolicyStatus;

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
// PolicyEndorsement — mid-term policy changes (coverage adjustments, corrections)
// ─────────────────────────────────────────────────────────────────────────────
export enum EndorsementType {
    COVERAGE_CHANGE = 'COVERAGE_CHANGE',
    BENEFICIARY_CHANGE = 'BENEFICIARY_CHANGE',
    ADDRESS_CHANGE = 'ADDRESS_CHANGE',
    PREMIUM_ADJUSTMENT = 'PREMIUM_ADJUSTMENT',
    POLICY_CORRECTION = 'POLICY_CORRECTION',
}

export enum EndorsementStatus {
    DRAFT = 'DRAFT',
    APPROVED = 'APPROVED',
    APPLIED = 'APPLIED',
    REJECTED = 'REJECTED',
}

@Entity('policy_endorsements')
@Index(['tenantId', 'policyId', 'effectiveDate'])
export class PolicyEndorsement extends BaseTenantEntity {
    @Column({ name: 'policy_id', type: 'uuid' })
    policyId!: string;

    @ManyToOne(() => Policy, (p) => p.endorsements, { onDelete: 'CASCADE' })
    @JoinColumn({ name: 'policy_id' })
    policy!: Policy;

    @Column({ name: 'endorsement_type', type: 'enum', enum: EndorsementType })
    endorsementType!: EndorsementType;

    @Column({ name: 'status', type: 'enum', enum: EndorsementStatus, default: EndorsementStatus.DRAFT })
    status!: EndorsementStatus;

    @Column({ name: 'effective_date', type: 'date' })
    effectiveDate!: string;

    /** Delta of changes applied */
    @Column({ name: 'change_details', type: 'jsonb' })
    changeDetails!: Record<string, unknown>;

    @Column({ name: 'premium_adjustment', type: 'numeric', precision: 14, scale: 2, default: 0 })
    premiumAdjustment!: string;

    @Column({ name: 'approved_by', type: 'uuid', nullable: true })
    approvedBy!: string | null;

    @Column({ name: 'approved_at', type: 'timestamptz', nullable: true })
    approvedAt!: Date | null;

    @Column({ type: 'text', nullable: true })
    notes!: string | null;
}
