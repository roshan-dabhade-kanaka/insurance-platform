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
import { UnderwritingStatus, UnderwritingDecisionOutcome, ApprovalDecision } from '../../../common/enums';

// ─────────────────────────────────────────────────────────────────────────────
// UnderwritingCase — one case per Quote requiring manual UW review.
// Temporal workflow: UnderwritingWorkflow manages SLA timers and escalations.
// ─────────────────────────────────────────────────────────────────────────────
@Entity('underwriting_cases')
@Index(['tenantId', 'status'])
@Index(['tenantId', 'quoteId'], { unique: true })
@Index(['tenantId', 'assignedUnderwriterId', 'status'])
export class UnderwritingCase extends BaseTenantEntity {
    @Column({ name: 'quote_id', type: 'uuid' })
    quoteId!: string;

    @Column({ name: 'risk_profile_id', type: 'uuid', nullable: true })
    riskProfileId!: string | null;

    @Column({ type: 'enum', enum: UnderwritingStatus, default: UnderwritingStatus.PENDING })
    status!: UnderwritingStatus;

    /** Underwriter currently owning the case */
    @Column({ name: 'assigned_underwriter_id', type: 'uuid', nullable: true })
    assignedUnderwriterId!: string | null;

    @Column({ name: 'current_approval_level', type: 'int', default: 1 })
    currentApprovalLevel!: number;

    /** Temporal workflow run ID for this UW case */
    @Column({ name: 'temporal_workflow_id', type: 'varchar', length: 255, nullable: true })
    temporalWorkflowId!: string | null;

    @Column({ name: 'sla_due_at', type: 'timestamptz', nullable: true })
    slaDueAt!: Date | null;

    @Column({ name: 'completed_at', type: 'timestamptz', nullable: true })
    completedAt!: Date | null;

    /** Final UW notes / conditions placed on approval */
    @Column({ name: 'underwriter_notes', type: 'text', nullable: true })
    underwriterNotes!: string | null;

    /** Conditions or exclusions attached to a conditional approval */
    @Column({ name: 'conditions', type: 'jsonb', default: [] })
    conditions!: Array<{ code: string; description: string; mandatory: boolean }>;

    @OneToMany(() => UnderwritingDecision, (d) => d.underwritingCase)
    decisions!: UnderwritingDecision[];

    @OneToMany(() => UnderwritingLock, (l) => l.underwritingCase)
    locks!: UnderwritingLock[];
}

// ─────────────────────────────────────────────────────────────────────────────
// UnderwritingLock — optimistic concurrency lock preventing double-processing.
//
// Workflow:
//  1. Underwriter calls AcquireLock → INSERT with lock_token + lock_expires_at
//  2. Submit decision → UPDATE using WHERE lock_token = :token (optimistic check)
//  3. On mismatch → 409 Conflict returned to caller
//  4. Background job (Temporal activity) expires stale locks
// ─────────────────────────────────────────────────────────────────────────────
@Entity('underwriting_locks')
@Unique(['caseId'])
@Index(['tenantId', 'lockedBy'])
@Index(['lockExpiresAt'])  // for background expiry sweep
export class UnderwritingLock extends BaseTenantEntity {
    @Column({ name: 'case_id', type: 'uuid' })
    caseId!: string;

    @ManyToOne(() => UnderwritingCase, (c) => c.locks, { onDelete: 'CASCADE' })
    @JoinColumn({ name: 'case_id' })
    underwritingCase!: UnderwritingCase;

    @Column({ name: 'locked_by', type: 'uuid' })
    lockedBy!: string;

    @Column({ name: 'locked_at', type: 'timestamptz', default: () => 'NOW()' })
    lockedAt!: Date;

    @Column({ name: 'lock_expires_at', type: 'timestamptz' })
    lockExpiresAt!: Date;

    /** Optimistic concurrency token — must match on decision submit */
    @Column({ name: 'lock_token', type: 'uuid', default: () => 'gen_random_uuid()' })
    lockToken!: string;

    /** Soft release — false when lock has been released or expired */
    @Column({ name: 'is_active', default: true })
    isActive!: boolean;
}

// ─────────────────────────────────────────────────────────────────────────────
// UnderwritingDecision — individual approval / decline / refer action per level
// ─────────────────────────────────────────────────────────────────────────────
@Entity('underwriting_decisions')
@Index(['tenantId', 'underwritingCaseId', 'approvalLevel'])
export class UnderwritingDecision extends BaseTenantEntity {
    @Column({ name: 'underwriting_case_id', type: 'uuid' })
    underwritingCaseId!: string;

    @ManyToOne(() => UnderwritingCase, (c) => c.decisions, { onDelete: 'CASCADE' })
    @JoinColumn({ name: 'underwriting_case_id' })
    underwritingCase!: UnderwritingCase;

    @Column({ name: 'approval_level', type: 'int' })
    approvalLevel!: number;

    @Column({ name: 'decided_by', type: 'uuid' })
    decidedBy!: string;

    @Column({ name: 'outcome', type: 'enum', enum: UnderwritingDecisionOutcome })
    outcome!: UnderwritingDecisionOutcome;

    @Column({ type: 'text', nullable: true })
    notes!: string | null;

    /** Lock token used when this decision was submitted (for audit) */
    @Column({ name: 'lock_token_used', type: 'uuid', nullable: true })
    lockTokenUsed!: string | null;

    @Column({ name: 'decided_at', type: 'timestamptz', default: () => 'NOW()' })
    decidedAt!: Date;
}

// ─────────────────────────────────────────────────────────────────────────────
// ApprovalHierarchy — configurable multi-level UW approval chain per product
// ─────────────────────────────────────────────────────────────────────────────
@Entity('approval_hierarchies')
@Index(['tenantId', 'productVersionId', 'isActive'])
export class ApprovalHierarchy extends BaseTenantEntity {
    @Column({ name: 'product_version_id', type: 'uuid' })
    productVersionId!: string;

    @Column({ length: 200 })
    name!: string;

    @Column({ name: 'is_active', default: true })
    isActive!: boolean;

    @OneToMany(() => ApprovalHierarchyLevel, (l) => l.hierarchy)
    levels!: ApprovalHierarchyLevel[];
}

@Entity('approval_hierarchy_levels')
@Index(['hierarchyId', 'levelNumber'])
export class ApprovalHierarchyLevel extends BaseTenantEntity {
    @Column({ name: 'hierarchy_id', type: 'uuid' })
    hierarchyId!: string;

    @ManyToOne(() => ApprovalHierarchy, (h) => h.levels, { onDelete: 'CASCADE' })
    @JoinColumn({ name: 'hierarchy_id' })
    hierarchy!: ApprovalHierarchy;

    @Column({ name: 'level_number', type: 'int' })
    levelNumber!: number;

    @Column({ name: 'level_name', length: 150 })
    levelName!: string;

    /** Role required at this level e.g. "SENIOR_UNDERWRITER" */
    @Column({ name: 'required_role_id', type: 'uuid', nullable: true })
    requiredRoleId!: string | null;

    /** Sum insured threshold above which this level is triggered */
    @Column({ name: 'sum_insured_threshold', type: 'numeric', precision: 14, scale: 2, nullable: true })
    sumInsuredThreshold!: string | null;

    /** Risk band threshold that triggers this level */
    @Column({ name: 'risk_band_threshold', type: 'varchar', length: 50, nullable: true })
    riskBandThreshold!: string | null;

    @Column({ name: 'sla_hours', type: 'int', default: 24 })
    slaHours!: number;
}
