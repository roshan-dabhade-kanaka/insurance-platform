// =============================================================================
// Claim Service — Insurance Platform
//
// Handles full claim lifecycle orchestration:
//   1. submitClaim()       — create Claim record + start Temporal claimWorkflow
//   2. updateStatus()      — persist state transition + emit event (called by Temporal)
//   3. recordValidation()  — persist validation result (policy / coverage / waiting / dup)
//   4. checkDuplicate()    — cross-check existing claims for same policy + loss date
//   5. createInvestigation() — open an investigation record
//   6. createAssessment()  — persist adjuster assessment
//   7. reopen()            — create reopened claim child (self-referential)
//
// Temporal integration:
//   - submitClaim() starts claimWorkflow via TemporalClientService
//   - updateStatus() is called by Temporal claim activities
//   - All signal senders (financeApproval, fraudReview, etc.) go through controller
//     → TemporalClientService.getClaimHandle().signal()
//
// Emits: claim.submitted, claim.status.changed, claim.validated, claim.reopened
// =============================================================================

import {
    Injectable,
    Logger,
    NotFoundException,
    ConflictException,
    BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { ConfigService } from '@nestjs/config';

import { Claim } from '../entities/claim.entity';
import { ClaimStatusHistory } from '../entities/claim.entity';
import { ClaimValidation } from '../entities/claim.entity';
import { ClaimInvestigation } from '../entities/claim.entity';
import { ClaimAssessment } from '../entities/claim.entity';
import { AuditLogService } from '../../audit/services/audit-log.service';
import { AuditEntityType } from '../../../common/enums';
import { TemporalClientService } from '../../../temporal/worker/worker';
import { ClaimWorkflowInput, getClaimStatusQuery } from '../../../temporal/shared/types';
import { FinancePayoutService } from '../../finance/services/finance-payout.service';

// ─────────────────────────────────────────────────────────────────────────────
// Domain Events
// ─────────────────────────────────────────────────────────────────────────────

export class ClaimSubmittedEvent {
    constructor(
        public readonly tenantId: string,
        public readonly claimId: string,
        public readonly policyId: string,
        public readonly claimedAmount: number,
        public readonly submittedBy?: string,
    ) { }
}

export class ClaimStatusChangedEvent {
    constructor(
        public readonly tenantId: string,
        public readonly claimId: string,
        public readonly fromStatus: string,
        public readonly toStatus: string,
        public readonly changedBy?: string,
        public readonly reason?: string,
    ) { }
}

export class ClaimReopenedEvent {
    constructor(
        public readonly tenantId: string,
        public readonly originalClaimId: string,
        public readonly reopenedClaimId: string,
        public readonly reopenCount: number,
    ) { }
}

// ─────────────────────────────────────────────────────────────────────────────
// Input DTOs
// ─────────────────────────────────────────────────────────────────────────────

export interface SubmitClaimDto {
    tenantId: string;
    policyId: string;
    policyCoverageId: string;
    claimedAmount: number;
    lossDate: string;
    lossDescription: string;
    claimantData: Record<string, unknown>;
    submittedBy?: string;
    fraudEscalationMultiplier?: number;
    averageClaimAmount?: number;
    maxReopenCount?: number;
    partialPayoutEnabled?: boolean;
}

export interface UpdateClaimStatusDto {
    tenantId: string;
    claimId: string;
    status: string;
    reason?: string;
    context?: Record<string, unknown>;
    changedBy?: string;
}

export interface RecordValidationDto {
    tenantId: string;
    claimId: string;
    validationType: string;
    status: 'PASS' | 'FAIL' | 'WARNING';
    detail: Record<string, unknown>;
}

export interface CreateInvestigationDto {
    tenantId: string;
    claimId: string;
    investigationType?: string;
    assignedInvestigatorId?: string;
    investigatorId?: string;
    notes?: string;
}

export interface RecordAssessmentDto {
    tenantId: string;
    claimId: string;
    assessment: {
        assessedBy: string;
        assessedAmount: number;
        deductibleApplied: number;
        netPayout: number;
        lineItemAssessment: Array<{
            claimItemId: string;
            claimedAmount: number;
            approvedAmount: number;
            rejectionReason?: string;
        }>;
        assessmentNotes?: string;
    };
}

export interface ReopenClaimDto {
    tenantId: string;
    claimId: string;
    reopenedBy: string;
    reason: string;
    additionalEvidence?: Record<string, unknown>;
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

@Injectable()
export class ClaimService {
    private readonly logger = new Logger(ClaimService.name);

    private readonly MAX_REOPEN_COUNT = 3;

    constructor(
        @InjectRepository(Claim)
        private readonly claimRepo: Repository<Claim>,

        @InjectRepository(ClaimStatusHistory)
        private readonly statusHistoryRepo: Repository<ClaimStatusHistory>,

        @InjectRepository(ClaimValidation)
        private readonly validationRepo: Repository<ClaimValidation>,

        @InjectRepository(ClaimInvestigation)
        private readonly investigationRepo: Repository<ClaimInvestigation>,

        @InjectRepository(ClaimAssessment)
        private readonly assessmentRepo: Repository<ClaimAssessment>,

        private readonly temporalClient: TemporalClientService,
        private readonly auditLog: AuditLogService,
        private readonly eventEmitter: EventEmitter2,
        private readonly configService: ConfigService,
        private readonly financeService: FinancePayoutService,
    ) { }

    // ─────────────────────────────────────────────────────────────────────────
    // submitClaim — create claim + start Temporal workflow
    // ─────────────────────────────────────────────────────────────────────────

    async submitClaim(dto: SubmitClaimDto): Promise<Claim> {
        this.logger.log(`Submitting claim [tenant=${dto.tenantId}, policy=${dto.policyId}, amount=${dto.claimedAmount}]`);

        // 1. Validate the claimed amount against coverage sum insured (DB Check)
        const res = await this.claimRepo.manager.query(
            `SELECT sum_insured FROM policy_coverages WHERE id = $1 AND tenant_id = $2`,
            [dto.policyCoverageId, dto.tenantId]
        );
        if (!res || res.length === 0) {
            throw new BadRequestException(`Invalid coverage option selected or coverage not found.`);
        }
        const maxAmount = parseFloat(res[0].sum_insured);
        if (dto.claimedAmount > maxAmount) {
            throw new BadRequestException(`Claimed amount (₹${dto.claimedAmount}) cannot exceed the coverage sum insured (₹${maxAmount}).`);
        }

        // 2. Check for duplicates (same policy + same coverage + same loss window)
        const dupCheck = await this.checkDuplicate({
            tenantId: dto.tenantId,
            claimId: '00000000-0000-0000-0000-000000000000',
            policyId: dto.policyId,
            policyCoverageId: dto.policyCoverageId,
            lossDate: dto.lossDate,
            claimedAmount: dto.claimedAmount,
        });

        if (dupCheck.isDuplicate) {
            throw new ConflictException(
                `Potential duplicate claim detected: ${dupCheck.duplicateClaimId}. ${dupCheck.failureReason}`
            );
        }

        const claimNumber = this.generateClaimNumber(dto.tenantId);

        const claim = this.claimRepo.create({
            tenantId: dto.tenantId,
            claimNumber,
            policyId: dto.policyId,
            policyCoverageId: dto.policyCoverageId,
            claimedAmount: dto.claimedAmount.toString(),
            lossDate: new Date(dto.lossDate).toISOString().split('T')[0],
            reportedDate: new Date().toISOString().split('T')[0],
            lossDescription: dto.lossDescription,
            claimantData: dto.claimantData,
            status: 'SUBMITTED' as any,
            reopenCount: 0,
            submittedBy: (dto.submittedBy && dto.submittedBy !== 'unknown') ? dto.submittedBy : null,
        });

        const saved = await this.claimRepo.save(claim) as any as Claim;

        // Start Temporal Claim Workflow
        const workflowInput: ClaimWorkflowInput = {
            tenantId: dto.tenantId,
            claimId: saved.id,
            policyId: dto.policyId,
            policyCoverageId: dto.policyCoverageId,
            claimedAmount: dto.claimedAmount,
            lossDate: dto.lossDate,
            lossDescription: dto.lossDescription,
            claimantData: dto.claimantData,
            submittedBy: dto.submittedBy,
            fraudEscalationMultiplier: dto.fraudEscalationMultiplier ?? 3,
            averageClaimAmount: dto.averageClaimAmount ?? 50000,
            maxReopenCount: dto.maxReopenCount ?? this.MAX_REOPEN_COUNT,
            partialPayoutEnabled: dto.partialPayoutEnabled ?? true,
        };

        const temporalEnabled = this.configService.get<string>('TEMPORAL_ENABLED', 'true') !== 'false';
        let temporalWorkflowId: string | undefined;

        if (temporalEnabled) {
            try {
                const handle = await this.temporalClient.startClaimWorkflow(workflowInput);
                temporalWorkflowId = handle.workflowId;
                await this.claimRepo.update({ id: saved.id }, { temporalWorkflowId });
            } catch (err: any) {
                this.logger.error(`Failed to start Temporal workflow for claim ${saved.id}: ${err.message}`);
                // Don't fail the claim submission just because Temporal is down
            }
        }

        // Emit event
        this.eventEmitter.emit(
            'claim.submitted',
            new ClaimSubmittedEvent(
                dto.tenantId, saved.id, dto.policyId, dto.claimedAmount, dto.submittedBy,
            ),
        );

        // Audit log
        await this.auditLog.log({
            tenantId: dto.tenantId,
            entityType: AuditEntityType.CLAIM,
            entityId: saved.id,
            action: 'SUBMITTED',
            newState: 'SUBMITTED',
            performedBy: dto.submittedBy,
            context: {
                policyId: dto.policyId,
                claimedAmount: dto.claimedAmount,
                temporalWorkflowId,
            },
        });

        this.logger.log(`Claim submitted [claimId=${saved.id}, workflow=${temporalWorkflowId ?? 'NONE'}]`);
        return this.claimRepo.findOneOrFail({ where: { id: saved.id } });
    }


    // ─────────────────────────────────────────────────────────────────────────
    // updateStatus — called by Temporal claim activities
    // ─────────────────────────────────────────────────────────────────────────

    async updateStatus(
        tenantId: string,
        claimId: string,
        status: string,
        reason?: string,
        context?: Record<string, unknown>,
    ): Promise<void> {
        const claim = await this.findOrFail(tenantId, claimId);
        const oldStatus = claim.status;

        if (oldStatus === status) return; // idempotent

        await this.claimRepo.update({ id: claimId, tenantId }, { status: status as any });

        await this.statusHistoryRepo.save(
            this.statusHistoryRepo.create({
                tenantId,
                claimId,
                fromStatus: oldStatus as any,
                toStatus: status as any,
                reason: reason as any,
                context: (context ?? {}) as any,
            } as any),
        );

        this.eventEmitter.emit(
            'claim.status.changed',
            new ClaimStatusChangedEvent(tenantId, claimId, oldStatus, status, undefined, reason),
        );

        await this.auditLog.log({
            tenantId,
            entityType: AuditEntityType.CLAIM,
            entityId: claimId,
            action: 'STATE_CHANGED',
            previousState: oldStatus,
            newState: status,
            context: { reason, ...context },
        });

        this.logger.log(`Claim status: ${oldStatus} → ${status} [claimId=${claimId}]`);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // recordValidation — persist validation result (policy/coverage/waiting/dup)
    // ─────────────────────────────────────────────────────────────────────────

    async recordValidation(
        tenantId: string,
        claimId: string,
        data: { validationType: string; status: string; detail: Record<string, unknown> },
    ): Promise<void> {
        await this.validationRepo.save(
            this.validationRepo.create({
                tenantId,
                claimId,
                validationType: data.validationType as any,
                status: data.status as any,
                validationDetail: data.detail as any,
                validatedAt: new Date(),
            } as any),
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // checkDuplicate — looks for claims on same policy + same loss date ± 7 days
    // ─────────────────────────────────────────────────────────────────────────

    async checkDuplicate(input: {
        tenantId: string;
        claimId: string;
        policyId: string;
        policyCoverageId: string;
        lossDate: string;
        claimedAmount: number;
    }): Promise<{ isDuplicate: boolean; duplicateClaimId?: string; failureReason?: string }> {
        const lossDate = new Date(input.lossDate);
        const windowDays = 7;
        const fromDate = new Date(lossDate.getTime() - windowDays * 86_400_000);
        const toDate = new Date(lossDate.getTime() + windowDays * 86_400_000);

        const existing = await this.claimRepo
            .createQueryBuilder('c')
            .where('c.tenant_id = :tenantId', { tenantId: input.tenantId })
            .andWhere('c.policy_id = :policyId', { policyId: input.policyId })
            .andWhere('c.policy_coverage_id = :coverageId', { coverageId: input.policyCoverageId })
            .andWhere('c.id != :claimId', { claimId: input.claimId })
            .andWhere('c.loss_date BETWEEN :from AND :to', { from: fromDate, to: toDate })
            .andWhere("c.status NOT IN ('REJECTED', 'WITHDRAWN', 'CLOSED')")
            .getOne();

        if (existing) {
            return {
                isDuplicate: true,
                duplicateClaimId: existing.id,
                failureReason: `Possible duplicate of claim ${existing.id} for same coverage around the same loss date`,
            };
        }

        return { isDuplicate: false };
    }

    // ─────────────────────────────────────────────────────────────────────────
    // createInvestigation
    // ─────────────────────────────────────────────────────────────────────────

    async createInvestigation(
        input: CreateInvestigationDto,
    ): Promise<{ investigationId: string }> {
        const inv = this.investigationRepo.create({
            tenantId: input.tenantId,
            claimId: input.claimId,
            investigationType: input.investigationType ?? 'GENERAL',
            assignedInvestigatorId: input.assignedInvestigatorId,
            status: 'OPEN' as any,
            openedAt: new Date(),
        } as any) as any as ClaimInvestigation;
        const saved = await this.investigationRepo.save(inv) as ClaimInvestigation;

        // Signal Temporal that investigation has started/completed
        try {
            const handle = await this.temporalClient.getClaimHandle(input.tenantId, input.claimId);
            await handle.signal('investigationComplete', {
                investigatorId: input.assignedInvestigatorId ?? input.investigatorId ?? 'SYSTEM',
                findings: input.notes ?? 'Initial investigation started',
                evidenceSummary: [],
                recommendFraudReview: false,
            });
        } catch (err: any) {
            this.logger.error(`Failed to signal investigationComplete: ${err.message}. Manual status update fallback.`);
            // Fallback: manually update status so it shows in Assessment tab
            await this.updateStatus(input.tenantId, input.claimId, 'UNDER_INVESTIGATION', 'Temporal signal failed, using manual fallback');
        }

        await this.auditLog.log({
            tenantId: input.tenantId,
            entityType: AuditEntityType.CLAIM,
            entityId: input.claimId,
            action: 'INVESTIGATION_OPENED',
            context: { investigationId: saved.id },
        });

        return { investigationId: saved.id };
    }

    // ─────────────────────────────────────────────────────────────────────────
    // createAssessment — persist adjuster's assessment
    // ─────────────────────────────────────────────────────────────────────────

    async createAssessment(
        input: RecordAssessmentDto,
    ): Promise<{ assessmentId: string }> {
        const assessment = this.assessmentRepo.create({
            tenantId: input.tenantId,
            claimId: input.claimId,
            assessedBy: input.assessment.assessedBy,
            assessedAmount: input.assessment.assessedAmount.toString(),
            deductibleApplied: input.assessment.deductibleApplied.toString(),
            netPayout: input.assessment.netPayout.toString(),
            lineItemAssessment: input.assessment.lineItemAssessment as any,
            assessmentNotes: input.assessment.assessmentNotes,
            assessedAt: new Date(),
        } as any) as any as ClaimAssessment;
        const saved = await this.assessmentRepo.save(assessment) as ClaimAssessment;

        // Signal Temporal that assessment is complete
        try {
            const handle = await this.temporalClient.getClaimHandle(input.tenantId, input.claimId);
            await handle.signal('claimAssessment', {
                assessedBy: input.assessment.assessedBy,
                assessedAmount: input.assessment.assessedAmount,
                deductibleApplied: input.assessment.deductibleApplied,
                netPayout: input.assessment.netPayout,
                lineItemAssessment: input.assessment.lineItemAssessment,
                assessmentNotes: input.assessment.assessmentNotes,
            });
        } catch (err: any) {
            this.logger.error(`Failed to signal claimAssessment: ${err.message}. Manual status update fallback.`);
            // Fallback: manually update status to ASSESSMENT_DONE or similar
            await this.updateStatus(input.tenantId, input.claimId, 'ASSESSED', 'Temporal signal failed, using manual fallback');

            // Fallback: Manually create payout request so it shows up in Finance tab
            try {
                await this.financeService.createPayoutRequest({
                    tenantId: input.tenantId,
                    claimId: input.claimId,
                    assessmentId: saved.id,
                    netPayout: input.assessment.netPayout,
                    currencyCode: 'INR',
                    payeeDetails: {},
                    requestedBy: input.assessment.assessedBy,
                });
            } catch (payErr: any) {
                this.logger.error(`Manual payout creation failed: ${payErr.message}`);
            }
        }

        await this.auditLog.log({
            tenantId: input.tenantId,
            entityType: AuditEntityType.CLAIM,
            entityId: input.claimId,
            action: 'ASSESSED',
            context: {
                assessedAmount: input.assessment.assessedAmount,
                netPayout: input.assessment.netPayout,
                assessedBy: input.assessment.assessedBy,
                assessmentId: saved.id,
            },
        });

        return { assessmentId: saved.id };
    }

    // ─────────────────────────────────────────────────────────────────────────
    // reopen — create child claim (self-referential) with increment reopen_count
    // ─────────────────────────────────────────────────────────────────────────

    async reopen(input: ReopenClaimDto): Promise<void> {
        const claim = await this.findOrFail(input.tenantId, input.claimId);

        if (claim.reopenCount >= this.MAX_REOPEN_COUNT) {
            throw new ConflictException(
                `Claim has been reopened the maximum number of times (${this.MAX_REOPEN_COUNT})`,
            );
        }

        await this.claimRepo.update(
            { id: input.claimId, tenantId: input.tenantId },
            {
                status: 'REOPENED' as any,
                reopenCount: claim.reopenCount + 1,
                reopenReason: input.reason,
            },
        );

        this.eventEmitter.emit(
            'claim.reopened',
            new ClaimReopenedEvent(
                input.tenantId,
                input.claimId,
                input.claimId,
                claim.reopenCount + 1,
            ),
        );

        await this.auditLog.log({
            tenantId: input.tenantId,
            entityType: AuditEntityType.CLAIM,
            entityId: input.claimId,
            action: 'REOPENED',
            newState: 'REOPENED',
            performedBy: input.reopenedBy,
            context: {
                reason: input.reason,
                reopenCount: claim.reopenCount + 1,
                additionalEvidence: input.additionalEvidence,
            },
        });

        this.logger.log(`Claim reopened [claimId=${input.claimId}, count=${claim.reopenCount + 1}]`);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // getWorkflowState
    // ─────────────────────────────────────────────────────────────────────────

    async getWorkflowState(tenantId: string, claimId: string) {
        try {
            const handle = await this.temporalClient.getClaimHandle(tenantId, claimId);
            return await handle.query(getClaimStatusQuery);
        } catch (err: any) {
            this.logger.warn(`Failed to query Temporal state for claim ${claimId}: ${err.message}. Falling back to DB status.`);
            const claim = await this.findOrFail(tenantId, claimId);
            return {
                status: claim.status,
                updatedAt: claim.updatedAt,
            };
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Private helpers
    // ─────────────────────────────────────────────────────────────────────────

    async findAll(tenantId: string): Promise<Claim[]> {
        return this.claimRepo.find({
            where: { tenantId },
            order: { createdAt: 'DESC' },
        });
    }

    private async findOrFail(tenantId: string, claimId: string): Promise<Claim> {
        const c = await this.claimRepo.findOne({ where: { id: claimId, tenantId } });
        if (!c) throw new NotFoundException(`Claim not found: ${claimId}`);
        return c;
    }

    private generateClaimNumber(tenantId: string): string {
        const prefix = tenantId.slice(0, 4).toUpperCase();
        const ts = Date.now().toString(36).toUpperCase();
        const rand = Math.random().toString(36).slice(2, 6).toUpperCase();
        return `CLM-${prefix}-${ts}-${rand}`;
    }
}
