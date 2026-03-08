// =============================================================================
// Finance Payout Service — Insurance Platform
//
// Manages the full payout lifecycle for approved claims:
//   1. createPayoutRequest() — create PayoutRequest record, set to PENDING_APPROVAL
//   2. recordApproval()      — persist finance team's approval decision
//   3. disburse()            — idempotent fund disbursement with idempotency key
//   4. submitApproval()      — finance analyst signals Temporal via financeApprovalSignal
//
// Partial Payout support:
//   - Finance approval may include partialInstallments[]
//   - Each installment tracked in PayoutPartialRecord
//   - Each disbursement tracked in PayoutDisbursement
//
// Idempotency:
//   - idempotencyKey = workflowId:installment:N prevents double-disburse on retry
//   - If an existing DISBURSED record exists for the key, return it without re-processing
//
// Emits: finance.payout.approved, finance.payout.disbursed, finance.payout.rejected
// =============================================================================

import { Injectable, Logger, NotFoundException, ConflictException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { EventEmitter2 } from '@nestjs/event-emitter';

import { PayoutRequest } from '../entities/finance.entity';
import { PayoutApproval } from '../entities/finance.entity';
import { PayoutPartialRecord } from '../entities/finance.entity';
import { PayoutDisbursement } from '../entities/finance.entity';
import { AuditLogService } from '../../audit/services/audit-log.service';
import { AuditEntityType, DisbursementStatus, ApprovalDecision } from '../../../common/enums';
import { TemporalClientService } from '../../../temporal/worker/worker';
import { financeApprovalSignal, FinanceDecision } from '../../../temporal/shared/types';

// ─────────────────────────────────────────────────────────────────────────────
// Domain Events
// ─────────────────────────────────────────────────────────────────────────────

export class PayoutApprovedEvent {
    constructor(
        public readonly tenantId: string,
        public readonly payoutRequestId: string,
        public readonly claimId: string,
        public readonly approvedAmount: number,
        public readonly approverId: string,
    ) { }
}

export class PayoutDisbursedEvent {
    constructor(
        public readonly tenantId: string,
        public readonly payoutRequestId: string,
        public readonly claimId: string,
        public readonly amount: number,
        public readonly transactionRef: string,
        public readonly installmentNumber?: number,
    ) { }
}

export class PayoutRejectedEvent {
    constructor(
        public readonly tenantId: string,
        public readonly payoutRequestId: string,
        public readonly claimId: string,
        public readonly reason?: string,
    ) { }
}

// ─────────────────────────────────────────────────────────────────────────────
// Input DTOs
// ─────────────────────────────────────────────────────────────────────────────

export interface CreatePayoutRequestDto {
    tenantId: string;
    claimId: string;
    assessmentId: string;
    netPayout: number;
    currencyCode: string;
    payeeDetails: Record<string, unknown>;
    requestedBy: string;
    partialInstallments?: Array<{
        installmentNumber: number;
        amount: number;
        scheduledDate: string;
    }>;
}

export interface RecordFinanceApprovalDto {
    tenantId: string;
    payoutRequestId: string;
    approval: {
        approverId: string;
        decision: FinanceDecision;
        approvedAmount?: number;
        partialInstallments?: Array<{
            installmentNumber: number;
            amount: number;
            scheduledDate: string;
        }>;
        notes?: string;
    };
}

export interface DisburseDto {
    tenantId: string;
    payoutRequestId: string;
    claimId: string;
    installmentNumber?: number;
    amount: number;
    payeeDetails: Record<string, unknown>;
    idempotencyKey: string;
}

export interface SubmitFinanceDecisionDto {
    tenantId: string;
    claimId: string;
    approverId: string;
    decision: FinanceDecision;
    approvedAmount?: number;
    partialInstallments?: Array<{
        installmentNumber: number;
        amount: number;
        scheduledDate: string;
    }>;
    notes?: string;
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

@Injectable()
export class FinancePayoutService {
    private readonly logger = new Logger(FinancePayoutService.name);

    constructor(
        @InjectRepository(PayoutRequest)
        private readonly payoutRequestRepo: Repository<PayoutRequest>,

        @InjectRepository(PayoutApproval)
        private readonly approvalRepo: Repository<PayoutApproval>,

        @InjectRepository(PayoutPartialRecord)
        private readonly partialRecordRepo: Repository<PayoutPartialRecord>,

        @InjectRepository(PayoutDisbursement)
        private readonly disbursementRepo: Repository<PayoutDisbursement>,

        private readonly temporalClient: TemporalClientService,
        private readonly auditLog: AuditLogService,
        private readonly eventEmitter: EventEmitter2,
    ) { }

    // ─────────────────────────────────────────────────────────────────────────
    // createPayoutRequest — called by Temporal claim activity
    // ─────────────────────────────────────────────────────────────────────────

    async createPayoutRequest(
        dto: CreatePayoutRequestDto,
    ): Promise<{ payoutRequestId: string }> {
        const request = this.payoutRequestRepo.create({
            tenantId: dto.tenantId,
            claimId: dto.claimId,
            assessmentId: dto.assessmentId,
            requestedAmount: dto.netPayout.toString(),
            totalAmount: dto.netPayout.toString(),
            currencyCode: dto.currencyCode,
            payeeDetails: dto.payeeDetails,
            requestedBy: dto.requestedBy,
            status: 'PENDING_APPROVAL' as any,
        });

        const saved = await this.payoutRequestRepo.save(request) as any as PayoutRequest;

        // If partial installments specified, pre-create the installment schedule
        if (dto.partialInstallments?.length) {
            const partialRecords = dto.partialInstallments.map((inst) =>
                this.partialRecordRepo.create({
                    tenantId: dto.tenantId,
                    payoutRequestId: saved.id,
                    installmentNumber: inst.installmentNumber,
                    amount: inst.amount.toString(),
                    scheduledDate: new Date(inst.scheduledDate).toISOString().split('T')[0],
                    status: 'SCHEDULED' as any,
                } as any) as any as PayoutPartialRecord,
            );
            await this.partialRecordRepo.save(partialRecords);
        }

        await this.auditLog.log({
            tenantId: dto.tenantId,
            entityType: AuditEntityType.PAYOUT,
            entityId: saved.id,
            action: 'PAYOUT_REQUEST_CREATED',
            newState: 'PENDING_APPROVAL',
            context: { claimId: dto.claimId, requestedAmount: dto.netPayout },
        });

        this.logger.log(`Payout request created [payoutRequestId=${saved.id}, claimId=${dto.claimId}]`);
        return { payoutRequestId: saved.id };
    }

    // ─────────────────────────────────────────────────────────────────────────
    // recordApproval — called by Temporal activity after finance signal received
    // ─────────────────────────────────────────────────────────────────────────

    async recordApproval(dto: RecordFinanceApprovalDto): Promise<void> {
        const request = await this.findRequestOrFail(dto.tenantId, dto.payoutRequestId);

        const approval = this.approvalRepo.create({
            tenantId: dto.tenantId,
            payoutRequestId: dto.payoutRequestId,
            approvalLevel: request.currentApprovalLevel,
            approverId: dto.approval.approverId,
            decision: this.mapFinanceDecisionToApprovalDecision(dto.approval.decision) as any,
            approvedAmount: dto.approval.approvedAmount != null ? String(dto.approval.approvedAmount) : null,
            notes: dto.approval.notes,
            decidedAt: new Date(),
        });
        await this.approvalRepo.save(approval);

        // Update payout request status
        const newStatus = this.mapDecisionToStatus(dto.approval.decision);
        await this.payoutRequestRepo.update(
            { id: dto.payoutRequestId },
            {
                status: newStatus as any,
                approvedAmount: dto.approval.approvedAmount != null ? String(dto.approval.approvedAmount) : null,
            },
        );

        // Emit events
        if (dto.approval.decision === FinanceDecision.REJECT) {
            this.eventEmitter.emit(
                'finance.payout.rejected',
                new PayoutRejectedEvent(
                    dto.tenantId,
                    dto.payoutRequestId,
                    request.claimId,
                    dto.approval.notes,
                ),
            );
        } else {
            this.eventEmitter.emit(
                'finance.payout.approved',
                new PayoutApprovedEvent(
                    dto.tenantId,
                    dto.payoutRequestId,
                    request.claimId,
                    Number(dto.approval.approvedAmount ?? request.requestedAmount),
                    dto.approval.approverId,
                ),
            );
        }

        // Audit log — Payout authorization event
        await this.auditLog.log({
            tenantId: dto.tenantId,
            entityType: AuditEntityType.PAYOUT,
            entityId: dto.payoutRequestId,
            action: 'PAYOUT_AUTHORIZATION',
            newState: dto.approval.decision as any,
            performedBy: dto.approval.approverId,
            context: {
                approvedAmount: dto.approval.approvedAmount,
                claimId: request.claimId,
                notes: dto.approval.notes,
            },
        });

        this.logger.log(
            `Payout approval recorded: ${dto.approval.decision} [payoutRequestId=${dto.payoutRequestId}]`,
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // disburse — idempotent fund disbursement
    //
    // Idempotency: checks `idempotency_key` before calling payment gateway.
    // If already DISBURSED, returns the existing record without re-processing.
    // ─────────────────────────────────────────────────────────────────────────

    async disburse(
        dto: DisburseDto,
    ): Promise<{ disbursementId: string; transactionRef: string; status: 'DISBURSED' | 'FAILED' }> {
        // Idempotency guard — check if already disbursed for this key
        const existing = await this.disbursementRepo.findOne({
            where: { idempotencyKey: dto.idempotencyKey, tenantId: dto.tenantId },
        });

        if (existing) {
            this.logger.warn(
                `Duplicate disburse call [idempotencyKey=${dto.idempotencyKey}] — returning existing record`,
            );
            return {
                disbursementId: existing.id,
                transactionRef: existing.transactionRef ?? '',
                status: existing.status as 'DISBURSED' | 'FAILED',
            };
        }

        // Call payment gateway (stubbed — replace with actual payment adapter)
        const transactionRef = await this.callPaymentGateway(dto);

        const disbursement = this.disbursementRepo.create({
            tenantId: dto.tenantId,
            payoutRequestId: dto.payoutRequestId,
            installmentNumber: dto.installmentNumber ?? 1,
            amount: String(dto.amount),
            transactionRef,
            idempotencyKey: dto.idempotencyKey,
            status: DisbursementStatus.DISBURSED,
            processedAt: new Date(),
        });

        const saved = await this.disbursementRepo.save(disbursement);

        // Update partial record if applicable
        if (dto.installmentNumber) {
            await this.partialRecordRepo.update(
                { payoutRequestId: dto.payoutRequestId, installmentNumber: dto.installmentNumber },
                { status: DisbursementStatus.DISBURSED, disbursedDate: new Date().toISOString().slice(0, 10) },
            );
        }

        // Update payout request to PARTIALLY_DISBURSED or DISBURSED
        await this.updatePayoutRequestAfterDisbursal(dto.tenantId, dto.payoutRequestId);

        // Emit event
        this.eventEmitter.emit(
            'finance.payout.disbursed',
            new PayoutDisbursedEvent(
                dto.tenantId,
                dto.payoutRequestId,
                dto.claimId,
                Number(dto.amount),
                transactionRef,
                dto.installmentNumber,
            ),
        );

        // Audit log
        await this.auditLog.log({
            tenantId: dto.tenantId,
            entityType: AuditEntityType.PAYOUT,
            entityId: dto.payoutRequestId,
            action: 'DISBURSED',
            newState: 'DISBURSED',
            context: {
                claimId: dto.claimId,
                amount: dto.amount,
                transactionRef,
                installmentNumber: dto.installmentNumber,
                idempotencyKey: dto.idempotencyKey,
            },
        });

        this.logger.log(
            `Payout disbursed [payoutRequestId=${dto.payoutRequestId}, amount=${dto.amount}, txRef=${transactionRef}]`,
        );

        return { disbursementId: saved.id, transactionRef, status: 'DISBURSED' };
    }

    // ─────────────────────────────────────────────────────────────────────────
    // submitApproval — finance analyst submits via API → signals Temporal
    // ─────────────────────────────────────────────────────────────────────────

    async submitApproval(dto: SubmitFinanceDecisionDto): Promise<void> {
        try {
            const handle = await this.temporalClient.getClaimHandle(dto.tenantId, dto.claimId);

            await handle.signal(financeApprovalSignal, {
                approverId: dto.approverId,
                decision: dto.decision,
                approvedAmount: dto.approvedAmount,
                partialInstallments: dto.partialInstallments,
                notes: dto.notes,
            });
        } catch (err: any) {
            this.logger.error(`Failed to signal financeApproval: ${err.message}. Manual approval fallback.`);

            try {
                // Fallback: find the pending payout request and record approval manually
                const request = await this.payoutRequestRepo.findOne({
                    where: {
                        claimId: dto.claimId,
                        tenantId: dto.tenantId,
                        status: 'PENDING_APPROVAL' as any
                    }
                });

                if (request) {
                    await this.recordApproval({
                        tenantId: dto.tenantId,
                        payoutRequestId: request.id,
                        approval: {
                            approverId: dto.approverId,
                            decision: dto.decision,
                            approvedAmount: dto.approvedAmount,
                            notes: dto.notes,
                            partialInstallments: dto.partialInstallments
                        }
                    });
                } else {
                    throw new Error(`No PENDING_APPROVAL payout request found for claim ${dto.claimId}`);
                }
            } catch (fallbackErr: any) {
                this.logger.error(`Manual fallback failed: ${fallbackErr.message}`, fallbackErr.stack);
                throw new BadRequestException(`DEBUG (Approve): ${fallbackErr.message}`);
            }
        }

        try {
            await this.auditLog.log({
                tenantId: dto.tenantId,
                entityType: 'CLAIM',
                entityId: dto.claimId,
                action: 'FINANCE_DECISION_SIGNALED',
                performedBy: dto.approverId,
                context: {
                    decision: dto.decision,
                    approvedAmount: dto.approvedAmount,
                    installmentCount: dto.partialInstallments?.length,
                },
            });

            this.logger.log(`Finance approval signal sent: ${dto.decision} [claimId=${dto.claimId}]`);
        } catch (auditErr: any) {
            this.logger.error(`Audit log failed after finance approval: ${auditErr.message}`);
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Private helpers
    // ─────────────────────────────────────────────────────────────────────────

    private async callPaymentGateway(dto: DisburseDto): Promise<string> {
        // Stub — replace with actual payment gateway adapter (e.g. Razorpay, Stripe, NEFT)
        // Must be idempotent on the gateway side too (pass idempotencyKey as external reference)
        this.logger.debug(`[STUB] Calling payment gateway for ${dto.amount} [key=${dto.idempotencyKey}]`);
        return `TXN-${Date.now()}-${Math.random().toString(36).slice(2, 8).toUpperCase()}`;
    }

    private async updatePayoutRequestAfterDisbursal(
        tenantId: string,
        payoutRequestId: string,
    ): Promise<void> {
        const remaining = await this.partialRecordRepo.count({
            where: { payoutRequestId, tenantId, status: DisbursementStatus.SCHEDULED },
        });

        const newStatus = remaining === 0 ? 'DISBURSED' : 'PARTIALLY_DISBURSED';
        await this.payoutRequestRepo.update({ id: payoutRequestId }, { status: newStatus as any });
    }

    private mapDecisionToStatus(decision: FinanceDecision): string {
        switch (decision) {
            case FinanceDecision.APPROVE_FULL: return 'APPROVED';
            case FinanceDecision.APPROVE_PARTIAL: return 'APPROVED';
            case FinanceDecision.REJECT: return 'REJECTED';
            case FinanceDecision.ESCALATE: return 'ESCALATED';
            default: return 'PENDING_APPROVAL';
        }
    }

    private mapFinanceDecisionToApprovalDecision(decision: FinanceDecision): ApprovalDecision {
        switch (decision) {
            case FinanceDecision.APPROVE_FULL:
            case FinanceDecision.APPROVE_PARTIAL:
                return ApprovalDecision.APPROVED;
            case FinanceDecision.REJECT:
                return ApprovalDecision.REJECTED;
            case FinanceDecision.ESCALATE:
                return ApprovalDecision.ESCALATED;
            default:
                return ApprovalDecision.PENDING;
        }
    }

    async getProcessedToday(tenantId: string): Promise<{ amount: number; count: number }> {
        const today = new Date().toISOString().slice(0, 10);
        const result = await this.disbursementRepo
            .createQueryBuilder('d')
            .select('SUM(CAST(d.amount AS NUMERIC))', 'totalAmount')
            .addSelect('COUNT(d.id)', 'count')
            .where('d.tenantId = :tenantId', { tenantId })
            .andWhere('d.status = :status', { status: DisbursementStatus.DISBURSED })
            .andWhere('d.processedAt >= :start', { start: `${today}T00:00:00Z` })
            .getRawOne();

        return {
            amount: parseFloat(result.totalAmount || '0'),
            count: parseInt(result.count || '0', 10),
        };
    }

    async getPendingPayouts(tenantId: string): Promise<PayoutRequest[]> {
        return this.payoutRequestRepo.find({
            where: { tenantId, status: 'PENDING_APPROVAL' as any },
            order: { createdAt: 'DESC' },
        });
    }

    private async findRequestOrFail(tenantId: string, id: string): Promise<PayoutRequest> {
        const r = await this.payoutRequestRepo.findOne({ where: { id, tenantId } });
        if (!r) throw new NotFoundException(`Payout request not found: ${id}`);
        return r;
    }
}
