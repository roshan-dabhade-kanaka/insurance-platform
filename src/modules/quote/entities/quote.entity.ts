import {
    Entity,
    Column,
    ManyToOne,
    OneToMany,
    JoinColumn,
    Index,
} from 'typeorm';
import { BaseTenantEntity } from '../../../common/entities/base-tenant.entity';
import { QuoteStatus } from '../../../common/enums';

// ─────────────────────────────────────────────────────────────────────────────
// Quote — lifecycle state machine for a product pricing quotation
//
// State machine:
//   DRAFT → PENDING_ELIGIBILITY → ELIGIBLE | INELIGIBLE
//   ELIGIBLE → RATED → PRESENTED → ACCEPTED | DECLINED | EXPIRED
//
// Temporal workflow: QuoteWorkflow drives state transitions.
// ─────────────────────────────────────────────────────────────────────────────
@Entity('quotes')
@Index(['tenantId', 'status', 'createdAt'])          // ← sub-300ms quote listing
@Index(['tenantId', 'applicantRef'])
@Index(['tenantId', 'productVersionId', 'status'])
@Index(['quoteNumber'], { unique: true })
export class Quote extends BaseTenantEntity {
    /** Human-readable quote number e.g. "QT-2024-000123" */
    @Column({ name: 'quote_number', length: 50 })
    quoteNumber!: string;

    @Column({ name: 'product_version_id', type: 'uuid' })
    productVersionId!: string;

    /** External applicant / lead identifier */
    @Column({ name: 'applicant_ref', length: 200 })
    applicantRef!: string;

    /** Full applicant data snapshot at time of quoting */
    @Column({ name: 'applicant_data', type: 'jsonb' })
    applicantData!: Record<string, unknown>;

    @Column({ type: 'enum', enum: QuoteStatus, default: QuoteStatus.DRAFT })
    status!: QuoteStatus;

    @Column({ name: 'expires_at', type: 'timestamptz', nullable: true })
    expiresAt!: Date | null;

    /** Temporal workflow run ID — for workflow correlation */
    @Column({ name: 'temporal_workflow_id', type: 'varchar', length: 255, nullable: true })
    temporalWorkflowId!: string | null;

    /** Agent or channel that originated this quote */
    @Column({ name: 'originated_by', type: 'uuid', nullable: true })
    originatedBy!: string | null;

    @Column({ name: 'assigned_to', type: 'uuid', nullable: true })
    assignedTo!: string | null;

    @Column({ type: 'jsonb', default: {} })
    metadata!: Record<string, unknown>;

    @OneToMany(() => QuoteLineItem, (li) => li.quote)
    lineItems!: QuoteLineItem[];

    @OneToMany(() => QuoteStatusHistory, (h) => h.quote)
    statusHistory!: QuoteStatusHistory[];

    @OneToMany(() => PremiumSnapshot, (s) => s.quote)
    premiumSnapshots!: PremiumSnapshot[];
}

// ─────────────────────────────────────────────────────────────────────────────
// QuoteLineItem — per-coverage breakdown within a quote
// ─────────────────────────────────────────────────────────────────────────────
@Entity('quote_line_items')
@Index(['tenantId', 'quoteId'])
export class QuoteLineItem extends BaseTenantEntity {
    @Column({ name: 'quote_id', type: 'uuid' })
    quoteId!: string;

    @ManyToOne(() => Quote, (q) => q.lineItems, { onDelete: 'CASCADE' })
    @JoinColumn({ name: 'quote_id' })
    quote!: Quote;

    @Column({ name: 'coverage_option_id', type: 'uuid' })
    coverageOptionId!: string;

    @Column({ name: 'rider_id', type: 'uuid', nullable: true })
    riderId!: string | null;

    @Column({ name: 'sum_insured', type: 'numeric', precision: 14, scale: 2 })
    sumInsured!: string;

    @Column({ name: 'deductible_id', type: 'uuid', nullable: true })
    deductibleId!: string | null;

    @Column({ name: 'calculated_premium', type: 'numeric', precision: 14, scale: 2, nullable: true })
    calculatedPremium!: string | null;

    @Column({ type: 'jsonb', default: {} })
    parameters!: Record<string, unknown>;
}

// ─────────────────────────────────────────────────────────────────────────────
// QuoteStatusHistory — immutable audit trail for every quote state transition
// ─────────────────────────────────────────────────────────────────────────────
@Entity('quote_status_history')
@Index(['tenantId', 'quoteId', 'occurredAt'])
export class QuoteStatusHistory extends BaseTenantEntity {
    @Column({ name: 'quote_id', type: 'uuid' })
    quoteId!: string;

    @ManyToOne(() => Quote, (q) => q.statusHistory, { onDelete: 'CASCADE' })
    @JoinColumn({ name: 'quote_id' })
    quote!: Quote;

    @Column({ name: 'from_status', type: 'enum', enum: QuoteStatus, nullable: true })
    fromStatus!: QuoteStatus | null;

    @Column({ name: 'to_status', type: 'enum', enum: QuoteStatus })
    toStatus!: QuoteStatus;

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
// PremiumSnapshot — immutable point-in-time premium calculation record.
// One snapshot per pricing rule evaluation; quoted premium is always referenced
// from the most recent snapshot linked to the accepted quote.
// ─────────────────────────────────────────────────────────────────────────────
@Entity('premium_snapshots')
@Index(['tenantId', 'quoteId', 'calculatedAt'])
export class PremiumSnapshot extends BaseTenantEntity {
    @Column({ name: 'quote_id', type: 'uuid' })
    quoteId!: string;

    @ManyToOne(() => Quote, (q) => q.premiumSnapshots, { onDelete: 'CASCADE' })
    @JoinColumn({ name: 'quote_id' })
    quote!: Quote;

    @Column({ name: 'product_version_id', type: 'uuid' })
    productVersionId!: string;

    @Column({ name: 'pricing_rule_id', type: 'uuid', nullable: true })
    pricingRuleId!: string | null;

    @Column({ name: 'base_premium', type: 'numeric', precision: 14, scale: 2 })
    basePremium!: string;

    @Column({ name: 'rider_surcharge', type: 'numeric', precision: 14, scale: 2, default: 0 })
    riderSurcharge!: string;

    @Column({ name: 'risk_loading', type: 'numeric', precision: 14, scale: 2, default: 0 })
    riskLoading!: string;

    @Column({ name: 'discount_amount', type: 'numeric', precision: 14, scale: 2, default: 0 })
    discountAmount!: string;

    @Column({ name: 'tax_amount', type: 'numeric', precision: 14, scale: 2, default: 0 })
    taxAmount!: string;

    @Column({ name: 'total_premium', type: 'numeric', precision: 14, scale: 2 })
    totalPremium!: string;

    /** Complete snapshot of every input value used in this calculation */
    @Column({ name: 'calculation_inputs', type: 'jsonb' })
    calculationInputs!: Record<string, unknown>;

    /** Itemized factor breakdown for transparency / audit */
    @Column({ name: 'factor_breakdown', type: 'jsonb', default: [] })
    factorBreakdown!: Array<{ factor: string; value: unknown; rate: number; amount: number }>;

    @Column({ name: 'calculated_at', type: 'timestamptz', default: () => 'NOW()' })
    calculatedAt!: Date;

    @Column({ name: 'calculated_by', type: 'uuid', nullable: true })
    calculatedBy!: string | null;

    @Column({ name: 'is_locked', default: false })
    isLocked!: boolean;
}
