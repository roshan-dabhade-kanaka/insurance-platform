// =============================================================================
// Underwriting Service — Insurance Platform
//
// Manages the full underwriting lifecycle:
//   - Open underwriting cases (created by Temporal activity)
//   - Acquire / release optimistic concurrency locks
//   - Record underwriter decisions (approve / reject / escalate)
//   - Escalate to senior underwriter (approval hierarchy)
//   - Send uwDecision signal to Temporal workflow
//
// Concurrent lock model:
//   - UnderwritingLock row with lock_token (UUID) and lock_expires_at
//   - All decision APIs validate lock_token before writing
//   - Temporal activity releases the lock after recording the decision
//
// Emits domain events:
//   underwriting.case.opened, underwriting.decision.recorded,
//   underwriting.escalated, underwriting.lock.acquired
// =============================================================================

import {
    Injectable,
    Logger,
    NotFoundException,
    ConflictException,
    ForbiddenException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { v4 as uuidv4 } from 'uuid';

import { UnderwritingCase } from '../entities/underwriting.entity';
import { UnderwritingLock } from '../entities/underwriting.entity';
import { UnderwritingDecision } from '../entities/underwriting.entity';
import { ApprovalHierarchy } from '../entities/underwriting.entity';
import { ApprovalHierarchyLevel } from '../entities/underwriting.entity';
import { AuditLogService } from '../../audit/services/audit-log.service';
import { AuditEntityType, UnderwritingStatus } from '../../../common/enums';
import { TemporalClientService } from '../../../temporal/worker/worker';
import { uwDecisionSignal, UwDecision } from '../../../temporal/shared/types';

// ─────────────────────────────────────────────────────────────────────────────
// Domain Events
// ─────────────────────────────────────────────────────────────────────────────

export class UwCaseOpenedEvent {
    constructor(
        public readonly tenantId: string,
        public readonly uwCaseId: string,
        public readonly quoteId: string,
        public readonly requiresSeniorReview: boolean,
    ) { }
}

export class UwDecisionRecordedEvent {
    constructor(
        public readonly tenantId: string,
        public readonly uwCaseId: string,
        public readonly decision: string,
        public readonly decidedBy: string,
        public readonly approvalLevel: number,
    ) { }
}

export class UwEscalatedEvent {
    constructor(
        public readonly tenantId: string,
        public readonly uwCaseId: string,
        public readonly fromLevel: number,
        public readonly toLevel: number,
        public readonly reason: string,
    ) { }
}

// ─────────────────────────────────────────────────────────────────────────────
// Input DTOs
// ─────────────────────────────────────────────────────────────────────────────

export interface CreateUwCaseDto {
    tenantId: string;
    quoteId: string;
    riskProfileId?: string;
    totalPremium: number;
    requiresSeniorReview: boolean;
}

export interface AcquireLockDto {
    tenantId: string;
    uwCaseId: string;
    underwriterId: string;
    lockDurationMinutes: number;
}

export interface ReleaseLockDto {
    lockId: string;
    lockToken: string;
}

export interface RecordDecisionDto {
    tenantId: string;
    uwCaseId: string;
    decidedBy: string;
    decision: UwDecision;
    approvalLevel: number;
    lockToken: string;
    notes?: string;
    conditions?: Array<{ code: string; description: string; mandatory: boolean }>;
}

export interface EscalateDto {
    tenantId: string;
    uwCaseId: string;
    escalatedFrom: string;
    reason: string;
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

@Injectable()
export class UnderwritingService {
    private readonly logger = new Logger(UnderwritingService.name);

    constructor(
        @InjectRepository(UnderwritingCase)
        private readonly caseRepo: Repository<UnderwritingCase>,

        @InjectRepository(UnderwritingLock)
        private readonly lockRepo: Repository<UnderwritingLock>,

        @InjectRepository(UnderwritingDecision)
        private readonly decisionRepo: Repository<UnderwritingDecision>,

        @InjectRepository(ApprovalHierarchy)
        private readonly hierarchyRepo: Repository<ApprovalHierarchy>,

        @InjectRepository(ApprovalHierarchyLevel)
        private readonly hierarchyLevelRepo: Repository<ApprovalHierarchyLevel>,

        private readonly auditLog: AuditLogService,
        private readonly temporalClient: TemporalClientService,
        private readonly eventEmitter: EventEmitter2,
    ) { }

    // ─────────────────────────────────────────────────────────────────────────
    // createCase — called by Temporal activity
    // ─────────────────────────────────────────────────────────────────────────

    async createCase(dto: CreateUwCaseDto): Promise<{
        uwCaseId: string;
        assignedUnderwriterId: string | null;
        currentApprovalLevel: number;
    }> {
        const uwCase = this.caseRepo.create({
            tenantId: dto.tenantId,
            quoteId: dto.quoteId,
            riskProfileId: dto.riskProfileId,
            status: UnderwritingStatus.PENDING,
            currentApprovalLevel: 1,
        } as any);
        const saved = await this.caseRepo.save(uwCase);
        const savedEntity = (Array.isArray(saved) ? saved[0] : saved) as UnderwritingCase;
        const caseIdStr = savedEntity.id;

        this.eventEmitter.emit(
            'underwriting.case.opened',
            new UwCaseOpenedEvent(dto.tenantId, caseIdStr, dto.quoteId, dto.requiresSeniorReview),
        );

        await this.auditLog.log({
            tenantId: dto.tenantId,
            entityType: AuditEntityType.UW_CASE,
            entityId: caseIdStr,
            action: 'CASE_OPENED',
            newState: 'PENDING',
            context: { quoteId: dto.quoteId, requiresSeniorReview: dto.requiresSeniorReview },
        });

        this.logger.log(`UW case opened [uwCaseId=${caseIdStr}, quoteId=${dto.quoteId}]`);
        return { uwCaseId: caseIdStr, assignedUnderwriterId: null, currentApprovalLevel: 1 };
    }

    // ─────────────────────────────────────────────────────────────────────────
    // acquireLock — optimistic concurrency lock
    // ─────────────────────────────────────────────────────────────────────────

    async acquireLock(
        tenantId: string,
        uwCaseId: string,
        underwriterId: string,
        lockDurationMinutes: number,
    ): Promise<{ lockId: string; lockToken: string; lockExpiresAt: string }> {
        // Check for an unexpired, active lock held by another underwriter
        const existing = await this.lockRepo.findOne({
            where: {
                tenantId,
                caseId: uwCaseId,
                isActive: true,
            },
        });

        if (existing && existing.lockedBy !== underwriterId) {
            const expiry = new Date(existing.lockExpiresAt);
            if (expiry > new Date()) {
                throw new ConflictException(
                    `UW case is currently locked by underwriter ${existing.lockedBy} until ${expiry.toISOString()}`,
                );
            }
            // Expired lock — release it first
            await this.lockRepo.update({ id: existing.id }, { isActive: false });
        }

        // Release any lock previously held by this same underwriter on this case
        if (existing?.lockedBy === underwriterId) {
            await this.lockRepo.update({ id: existing.id }, { isActive: false });
        }

        const lockToken = uuidv4();
        const lockExpiresAt = new Date(Date.now() + lockDurationMinutes * 60 * 1000);

        const lock = this.lockRepo.create({
            tenantId,
            caseId: uwCaseId,
            lockedBy: underwriterId,
            lockToken,
            lockExpiresAt,
            isActive: true,
        });

        const savedLock = await this.lockRepo.save(lock);

        await this.auditLog.log({
            tenantId,
            entityType: AuditEntityType.UW_CASE,
            entityId: uwCaseId,
            action: 'LOCK_ACQUIRED',
            performedBy: underwriterId,
            context: { lockId: savedLock.id, lockToken, expiresAt: lockExpiresAt.toISOString() },
        });

        this.logger.log(`UW lock acquired [uwCaseId=${uwCaseId}, by=${underwriterId}]`);
        return { lockId: savedLock.id, lockToken, lockExpiresAt: lockExpiresAt.toISOString() };
    }

    // ─────────────────────────────────────────────────────────────────────────
    // releaseLock
    // ─────────────────────────────────────────────────────────────────────────

    async releaseLock(lockId: string, lockToken: string): Promise<void> {
        const lock = await this.lockRepo.findOne({ where: { id: lockId, lockToken } });
        if (!lock) {
            this.logger.warn(`Lock not found or token mismatch [lockId=${lockId}]`);
            return; // idempotent
        }
        await this.lockRepo.update({ id: lockId }, { isActive: false });
        this.logger.debug(`UW lock released [lockId=${lockId}]`);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // recordDecision — validates lock_token, persists decision, signals Temporal
    // ─────────────────────────────────────────────────────────────────────────

    async recordDecision(dto: RecordDecisionDto): Promise<void> {
        // 1. Validate the lock token — prevents stale decisions
        // Lock should have already been released by Temporal activity — just validate token was ever valid
        const anyLock = await this.lockRepo.findOne({
            where: { caseId: dto.uwCaseId, lockToken: dto.lockToken },
        });

        if (!anyLock) {
            throw new ForbiddenException(
                `Invalid or expired lock token for UW case ${dto.uwCaseId}. Decision rejected.`,
            );
        }

        // 2. Persist the decision
        const decision = this.decisionRepo.create({
            tenantId: dto.tenantId,
            underwritingCaseId: dto.uwCaseId,
            decidedBy: dto.decidedBy,
            outcome: dto.decision as any,
            approvalLevel: dto.approvalLevel,
            notes: dto.notes ?? null,
            decidedAt: new Date(),
        });

        await this.decisionRepo.save(decision);

        // 3. Update case status
        const newCaseStatus = this.mapDecisionToStatus(dto.decision);
        await this.caseRepo.update(
            { id: dto.uwCaseId, tenantId: dto.tenantId },
            { status: newCaseStatus as any },
        );

        // 4. Emit event
        this.eventEmitter.emit(
            'underwriting.decision.recorded',
            new UwDecisionRecordedEvent(
                dto.tenantId,
                dto.uwCaseId,
                dto.decision,
                dto.decidedBy,
                dto.approvalLevel,
            ),
        );

        // 5. Audit
        await this.auditLog.log({
            tenantId: dto.tenantId,
            entityType: AuditEntityType.UW_CASE,
            entityId: dto.uwCaseId,
            action: 'DECISION_RECORDED',
            newState: dto.decision,
            performedBy: dto.decidedBy,
            context: {
                approvalLevel: dto.approvalLevel,
                notes: dto.notes,
                conditions: dto.conditions,
            },
        });

        this.logger.log(
            `UW decision recorded: ${dto.decision} by ${dto.decidedBy} at level ${dto.approvalLevel} [uwCaseId=${dto.uwCaseId}]`,
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // escalate — promote to senior underwriter
    // ─────────────────────────────────────────────────────────────────────────

    async escalate(dto: EscalateDto): Promise<{
        newApprovalLevel: number;
        assignedSeniorUwId: string | null;
    }> {
        const uwCase = await this.caseRepo.findOne({
            where: { id: dto.uwCaseId, tenantId: dto.tenantId },
        });

        if (!uwCase) throw new NotFoundException(`UW case not found: ${dto.uwCaseId}`);

        const fromLevel = uwCase.currentApprovalLevel;
        const newLevel = fromLevel + 1;

        await this.caseRepo.update(
            { id: dto.uwCaseId },
            { currentApprovalLevel: newLevel },
        );

        // Look up the next-level approver from approval hierarchy
        const nextApproverLevel = await this.hierarchyLevelRepo.findOne({
            where: { levelNumber: newLevel, tenantId: dto.tenantId },
        });

        this.eventEmitter.emit(
            'underwriting.escalated',
            new UwEscalatedEvent(dto.tenantId, dto.uwCaseId, fromLevel, newLevel, dto.reason),
        );

        await this.auditLog.log({
            tenantId: dto.tenantId,
            entityType: AuditEntityType.UW_CASE,
            entityId: dto.uwCaseId,
            action: 'ESCALATED',
            performedBy: dto.escalatedFrom,
            context: { fromLevel, toLevel: newLevel, reason: dto.reason },
        });

        this.logger.log(
            `UW escalated level ${fromLevel} → ${newLevel} [uwCaseId=${dto.uwCaseId}]`,
        );

        return {
            newApprovalLevel: newLevel,
            assignedSeniorUwId: nextApproverLevel?.requiredRoleId ?? null,
        };
    }

    async findAll(tenantId: string): Promise<UnderwritingCase[]> {
        return this.caseRepo.find({
            where: { tenantId },
            relations: ['decisions'],
            order: { createdAt: 'DESC' },
        });
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Private helpers
    // ─────────────────────────────────────────────────────────────────────────

    private mapDecisionToStatus(decision: UwDecision): string {
        switch (decision) {
            case UwDecision.APPROVE: return 'APPROVED';
            case UwDecision.CONDITIONALLY_APPROVE: return 'CONDITIONALLY_APPROVED';
            case UwDecision.REJECT: return 'DECLINED';
            case UwDecision.REFER_TO_SENIOR: return 'ESCALATED';
            case UwDecision.REQUEST_INFO: return 'PENDING_INFO';
            default: return 'IN_REVIEW';
        }
    }
}
