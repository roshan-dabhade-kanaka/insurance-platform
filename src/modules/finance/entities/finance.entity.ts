import {
    Entity,
    Column,
    ManyToOne,
    OneToMany,
    JoinColumn,
    Index,
} from 'typeorm';
import { BaseTenantEntity } from '../../../common/entities/base-tenant.entity';
import { PayoutStatus, DisbursementStatus, ApprovalDecision } from '../../../common/enums';

// ─────────────────────────────────────────────────────────────────────────────
// PayoutRequest — finance instruction generated from an approved ClaimAssessment
//
// Supports partial payout: net_payout is split into PayoutPartialRecord
// installments. Full payout = single installment = net_payout total.
// ─────────────────────────────────────────────────────────────────────────────
@Entity('payout_requests')
@Index(['tenantId', 'claimId'])
@Index(['tenantId', 'status'])
export class PayoutRequest extends BaseTenantEntity {
    @Column({ name: 'claim_id', type: 'uuid' })
    claimId!: string;

    @Column({ name: 'assessment_id', type: 'uuid' })
    assessmentId!: string;

    @Column({ type: 'enum', enum: PayoutStatus, default: PayoutStatus.PENDING_APPROVAL })
    status!: PayoutStatus;

    @Column({ name: 'total_amount', type: 'numeric', precision: 14, scale: 2 })
    totalAmount!: string;

    @Column({ name: 'requested_amount', type: 'numeric', precision: 14, scale: 2 })
    requestedAmount!: string;

    @Column({ name: 'currency_code', length: 5, default: 'INR' })
    currencyCode!: string;

    /** Payee bank / wallet details */
    @Column({ name: 'payee_details', type: 'jsonb' })
    payeeDetails!: Record<string, unknown>;

    @Column({ name: 'requested_by', type: 'uuid' })
    requestedBy!: string;

    @Column({ name: 'approved_amount', type: 'numeric', precision: 14, scale: 2, nullable: true })
    approvedAmount!: string | null;

    @Column({ name: 'current_approval_level', type: 'int', default: 1 })
    currentApprovalLevel!: number;

    @Column({ name: 'temporal_workflow_id', type: 'varchar', length: 255, nullable: true })
    temporalWorkflowId!: string | null;

    @OneToMany(() => PayoutApproval, (a) => a.payoutRequest)
    approvals!: PayoutApproval[];

    @OneToMany(() => PayoutPartialRecord, (p) => p.payoutRequest)
    partialRecords!: PayoutPartialRecord[];

    @OneToMany(() => PayoutDisbursement, (d) => d.payoutRequest)
    disbursements!: PayoutDisbursement[];
}

// ─────────────────────────────────────────────────────────────────────────────
// PayoutApproval — multi-level finance approval chain
// ─────────────────────────────────────────────────────────────────────────────
@Entity('payout_approvals')
@Index(['tenantId', 'payoutRequestId', 'approvalLevel'])
export class PayoutApproval extends BaseTenantEntity {
    @Column({ name: 'payout_request_id', type: 'uuid' })
    payoutRequestId!: string;

    @ManyToOne(() => PayoutRequest, (p) => p.approvals, { onDelete: 'CASCADE' })
    @JoinColumn({ name: 'payout_request_id' })
    payoutRequest!: PayoutRequest;

    @Column({ name: 'approval_level', type: 'int' })
    approvalLevel!: number;

    @Column({ name: 'approver_id', type: 'uuid' })
    approverId!: string;

    @Column({ type: 'enum', enum: ApprovalDecision, default: ApprovalDecision.PENDING })
    decision!: ApprovalDecision;

    @Column({ name: 'approved_amount', type: 'numeric', precision: 14, scale: 2, nullable: true })
    approvedAmount!: string | null;

    @Column({ type: 'text', nullable: true })
    notes!: string | null;

    @Column({ name: 'decided_at', type: 'timestamptz', nullable: true })
    decidedAt!: Date | null;
}

// ─────────────────────────────────────────────────────────────────────────────
// PayoutPartialRecord — tracks individual installments for partial payout
//
// Partial payout workflow:
//   1. Adjuster splits approved_amount into N installments
//   2. Each installment → PayoutPartialRecord with scheduled_date
//   3. Each installment triggers a separate PayoutDisbursement on processing date
//   4. PayoutRequest.status = PARTIALLY_DISBURSED until all installments complete
// ─────────────────────────────────────────────────────────────────────────────
@Entity('payout_partial_records')
@Index(['tenantId', 'payoutRequestId', 'installmentNumber'])
@Index(['tenantId', 'status', 'scheduledDate'])
export class PayoutPartialRecord extends BaseTenantEntity {
    @Column({ name: 'payout_request_id', type: 'uuid' })
    payoutRequestId!: string;

    @ManyToOne(() => PayoutRequest, (p) => p.partialRecords, { onDelete: 'CASCADE' })
    @JoinColumn({ name: 'payout_request_id' })
    payoutRequest!: PayoutRequest;

    @Column({ name: 'installment_number', type: 'int' })
    installmentNumber!: number;

    @Column({ type: 'numeric', precision: 14, scale: 2 })
    amount!: string;

    @Column({ name: 'scheduled_date', type: 'date' })
    scheduledDate!: string;

    @Column({ name: 'disbursed_date', type: 'date', nullable: true })
    disbursedDate!: string | null;

    @Column({ type: 'enum', enum: DisbursementStatus, default: DisbursementStatus.SCHEDULED })
    status!: DisbursementStatus;

    @Column({ type: 'text', nullable: true })
    notes!: string | null;
}

// ─────────────────────────────────────────────────────────────────────────────
// PayoutDisbursement — actual financial transaction record
// ─────────────────────────────────────────────────────────────────────────────
@Entity('payout_disbursements')
@Index(['tenantId', 'payoutRequestId'])
@Index(['tenantId', 'status', 'processedAt'])
export class PayoutDisbursement extends BaseTenantEntity {
    @Column({ name: 'payout_request_id', type: 'uuid' })
    payoutRequestId!: string;

    @ManyToOne(() => PayoutRequest, (p) => p.disbursements, { onDelete: 'CASCADE' })
    @JoinColumn({ name: 'payout_request_id' })
    payoutRequest!: PayoutRequest;

    @Column({ name: 'partial_record_id', type: 'uuid', nullable: true })
    partialRecordId!: string | null;

    @Column({ type: 'numeric', precision: 14, scale: 2 })
    amount!: string;

    @Column({ type: 'enum', enum: DisbursementStatus, default: DisbursementStatus.PROCESSING })
    status!: DisbursementStatus;

    /** External payment gateway transaction ID */
    @Column({ name: 'transaction_ref', type: 'varchar', length: 300, nullable: true })
    transactionRef!: string | null;

    @Column({ name: 'idempotency_key', length: 200, unique: true })
    idempotencyKey!: string;

    @Column({ name: 'installment_number', type: 'int', default: 1 })
    installmentNumber!: number;

    /** Gateway response payload */
    @Column({ name: 'gateway_response', type: 'jsonb', nullable: true })
    gatewayResponse!: Record<string, unknown> | null;

    @Column({ name: 'processed_at', type: 'timestamptz', nullable: true })
    processedAt!: Date | null;

    @Column({ name: 'failure_reason', type: 'text', nullable: true })
    failureReason!: string | null;
}
