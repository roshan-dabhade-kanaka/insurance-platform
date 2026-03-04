// =============================================================================
// Policy Service — Insurance Platform
//
// Handles policy issuance, activation, and lifecycle events:
//   1. issue()   — creates Policy record from approved quote + locks premium snapshot
//   2. activate() — transitions policy to IN_FORCE
//   3. lapse()   — marks policy as LAPSED (premium not paid)
//   4. cancel()  — cancels IN_FORCE policy with reason
//   5. reinstate() — reinstates a lapsed policy
//   6. validateForClaim() — called by claim activities to validate policy status
//
// Temporal integration:
//   - Issue() stores temporalWorkflowId and marks PremiumSnapshot.isLocked = true
//
// Emits: policy.issued, policy.activated, policy.lapsed, policy.cancelled
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

import { Policy } from '../entities/policy.entity';
import { PolicyStatusHistory } from '../entities/policy.entity';
import { PolicyCoverage } from '../entities/policy.entity';
import { PolicyRider } from '../entities/policy.entity';
import { PremiumSnapshot } from '../../quote/entities/quote.entity';
import { Quote } from '../../quote/entities/quote.entity';
import { AuditLogService } from '../../audit/services/audit-log.service';
import { AuditEntityType } from '../../../common/enums';

// ─────────────────────────────────────────────────────────────────────────────
// Domain Events
// ─────────────────────────────────────────────────────────────────────────────

export class PolicyIssuedEvent {
    constructor(
        public readonly tenantId: string,
        public readonly policyId: string,
        public readonly policyNumber: string,
        public readonly quoteId: string,
    ) { }
}

export class PolicyStatusChangedEvent {
    constructor(
        public readonly tenantId: string,
        public readonly policyId: string,
        public readonly fromStatus: string,
        public readonly toStatus: string,
        public readonly changedBy?: string,
        public readonly reason?: string,
    ) { }
}

// ─────────────────────────────────────────────────────────────────────────────
// Input DTOs
// ─────────────────────────────────────────────────────────────────────────────

export interface IssuePolicyDto {
    tenantId: string;
    quoteId: string;
    snapshotId?: string;
    conditions?: Array<{ code: string; description: string; mandatory: boolean }>;
}

export interface PolicyValidationInput {
    tenantId: string;
    claimId: string;
    policyId: string;
    lossDate: string;
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

@Injectable()
export class PolicyService {
    private readonly logger = new Logger(PolicyService.name);

    constructor(
        @InjectRepository(Policy)
        private readonly policyRepo: Repository<Policy>,

        @InjectRepository(PolicyStatusHistory)
        private readonly statusHistoryRepo: Repository<PolicyStatusHistory>,

        @InjectRepository(PolicyCoverage)
        private readonly coverageRepo: Repository<PolicyCoverage>,

        @InjectRepository(PolicyRider)
        private readonly riderRepo: Repository<PolicyRider>,

        @InjectRepository(PremiumSnapshot)
        private readonly snapshotRepo: Repository<PremiumSnapshot>,

        @InjectRepository(Quote)
        private readonly quoteRepo: Repository<Quote>,

        private readonly auditLog: AuditLogService,
        private readonly eventEmitter: EventEmitter2,
    ) { }

    // ─────────────────────────────────────────────────────────────────────────
    // issue — called by Temporal issuePolicy activity
    // ─────────────────────────────────────────────────────────────────────────

    async issue(dto: IssuePolicyDto): Promise<{ policyId: string; policyNumber: string }> {
        // Fetch approved quote (supports UUID or Quote Number)
        const quote = await this.findQuoteOrFail(dto.tenantId, dto.quoteId);

        // Handle optional snapshotId
        let snapshotId = dto.snapshotId;
        if (!snapshotId) {
            const latestSnapshot = await this.snapshotRepo.findOne({
                where: { quoteId: quote.id, tenantId: dto.tenantId },
                order: { calculatedAt: 'DESC' },
            });
            if (!latestSnapshot) {
                throw new BadRequestException(
                    `No premium calculation (snapshot) found for Quote: ${quote.quoteNumber} (ID: ${quote.id}). ` +
                    `Please calculate the premium first.`,
                );
            }
            snapshotId = latestSnapshot.id;
        }

        // Fetch premium snapshot
        const snapshot = await this.snapshotRepo.findOne({
            where: { id: snapshotId, tenantId: dto.tenantId },
        });
        if (!snapshot) throw new NotFoundException(`Snapshot not found: ${snapshotId}`);

        if (snapshot.isLocked) {
            this.logger.warn(`Snapshot ${snapshotId} is already locked — reusing for idempotent issue`);
        }

        // Lock the premium snapshot (prevents recalculation post-approval)
        await this.snapshotRepo.update({ id: snapshotId }, { isLocked: true });

        // Generate policy number
        const policyNumber = this.generatePolicyNumber(dto.tenantId);

        // Create policy record
        const policy = this.policyRepo.create({
            tenantId: dto.tenantId,
            quoteId: quote.id,
            productVersionId: quote.productVersionId,
            policyNumber,
            status: 'PENDING_ISSUANCE' as any,
            annualPremium: snapshot.totalPremium,
            premiumSnapshotId: snapshotId,
            inceptionDate: new Date().toISOString().split('T')[0],
            expiryDate: this.computeExpiryDate(new Date(), 365).toISOString().split('T')[0],
        });

        const saved = await this.policyRepo.save(policy) as any as Policy;

        // Copy coverages and riders from quote line items into policy
        await this.copyLineItemsToPolicyCoverages(dto.tenantId, quote.id, saved.id, quote.productVersionId);

        // Emit & audit
        this.eventEmitter.emit(
            'policy.issued',
            new PolicyIssuedEvent(dto.tenantId, saved.id, policyNumber, quote.id),
        );

        await this.auditLog.log({
            tenantId: dto.tenantId,
            entityType: AuditEntityType.POLICY,
            entityId: saved.id,
            action: 'ISSUED',
            newState: 'PENDING_ISSUANCE',
            context: { quoteId: quote.id, policyNumber, totalPremium: snapshot.totalPremium },
        });

        this.logger.log(`Policy issued [policyId=${saved.id}, number=${policyNumber}]`);
        return { policyId: saved.id, policyNumber };
    }

    // ─────────────────────────────────────────────────────────────────────────
    // activate — transitions PENDING_ISSUANCE → IN_FORCE
    // ─────────────────────────────────────────────────────────────────────────

    async activate(tenantId: string, policyId: string, activatedBy?: string): Promise<void> {
        await this.transitionStatus(
            tenantId, policyId, 'PENDING_ISSUANCE', 'IN_FORCE', activatedBy, 'Policy activated',
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // lapse
    // ─────────────────────────────────────────────────────────────────────────

    async lapse(tenantId: string, policyId: string, reason: string, changedBy?: string): Promise<void> {
        await this.transitionStatus(tenantId, policyId, 'IN_FORCE', 'LAPSED', changedBy, reason);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // cancel
    // ─────────────────────────────────────────────────────────────────────────

    async cancel(
        tenantId: string,
        policyId: string,
        reason: string,
        cancelledBy?: string,
    ): Promise<void> {
        const policy = await this.findOrFail(tenantId, policyId);
        const allowedFrom = ['IN_FORCE', 'LAPSED', 'PENDING_ISSUANCE'];
        if (!allowedFrom.includes(policy.status)) {
            throw new ConflictException(`Cannot cancel policy in status: ${policy.status}`);
        }
        await this.transitionStatus(tenantId, policyId, policy.status, 'CANCELLED', cancelledBy, reason);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // reinstate
    // ─────────────────────────────────────────────────────────────────────────

    async reinstate(
        tenantId: string,
        policyId: string,
        reinstatedBy?: string,
    ): Promise<void> {
        const policy = await this.findOrFail(tenantId, policyId);
        if (policy.status !== 'LAPSED') {
            throw new ConflictException(`Can only reinstate LAPSED policies, current: ${policy.status}`);
        }
        await this.transitionStatus(tenantId, policyId, 'LAPSED', 'REINSTATED', reinstatedBy, 'Policy reinstated');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // validateForClaim — called by Temporal claim.activities.ts
    // ─────────────────────────────────────────────────────────────────────────

    async validateForClaim(input: PolicyValidationInput): Promise<{
        isValid: boolean;
        policyStatus: string;
        inceptionDate: string;
        expiryDate: string;
        failureReason?: string;
    }> {
        const policy = await this.policyRepo.findOne({
            where: { id: input.policyId, tenantId: input.tenantId },
        });

        if (!policy) {
            return {
                isValid: false,
                policyStatus: 'NOT_FOUND',
                inceptionDate: '',
                expiryDate: '',
                failureReason: `Policy not found: ${input.policyId}`,
            };
        }

        const lossDate = new Date(input.lossDate);
        const validStatuses = ['IN_FORCE', 'REINSTATED'];
        const isActiveStatus = validStatuses.includes(policy.status);
        const isWithinTerm = lossDate >= new Date(policy.inceptionDate) && lossDate <= new Date(policy.expiryDate);

        return {
            isValid: isActiveStatus && isWithinTerm,
            policyStatus: policy.status,
            inceptionDate: policy.inceptionDate,
            expiryDate: policy.expiryDate,
            failureReason: !isActiveStatus
                ? `Policy is ${policy.status}`
                : !isWithinTerm
                    ? `Loss date ${input.lossDate} is outside policy term`
                    : undefined,
        };
    }

    // ─────────────────────────────────────────────────────────────────────────
    // validateCoverage — checks coverage exists and sum insured >= claimedAmount
    // ─────────────────────────────────────────────────────────────────────────

    async validateCoverage(input: {
        tenantId: string;
        claimId: string;
        policyId: string;
        policyCoverageId: string;
        claimedAmount: number;
        lossDate: string;
    }) {
        const coverage = await this.coverageRepo.findOne({
            where: { id: input.policyCoverageId, policyId: input.policyId, tenantId: input.tenantId },
        });

        if (!coverage) {
            return { isValid: false, sumInsured: 0, deductible: 0, maxPayable: 0, failureReason: 'Coverage not found' };
        }

        const maxPayable = Number(coverage.sumInsured) - (Number(coverage.deductibleAmount) ?? 0);
        const isValid = input.claimedAmount <= Number(coverage.sumInsured);

        return {
            isValid,
            sumInsured: coverage.sumInsured,
            deductible: Number(coverage.deductibleAmount) ?? 0,
            maxPayable,
            failureReason: !isValid
                ? `Claimed amount ${input.claimedAmount} exceeds sum insured ${coverage.sumInsured}`
                : undefined,
        };
    }

    // ─────────────────────────────────────────────────────────────────────────
    // checkWaitingPeriod
    // ─────────────────────────────────────────────────────────────────────────

    async checkWaitingPeriod(input: {
        tenantId: string;
        claimId: string;
        policyId: string;
        policyCoverageId: string;
        lossDate: string;
        inceptionDate: string;
    }) {
        const coverage = await this.coverageRepo.findOne({
            where: { id: input.policyCoverageId, tenantId: input.tenantId },
        });

        const waitingPeriodDays = coverage?.waitingPeriodDays ?? 0;
        const policyInception = coverage?.policy?.inceptionDate ? new Date(coverage.policy.inceptionDate) : new Date();
        const inception = new Date(input.inceptionDate || policyInception);
        const lossDate = new Date(input.lossDate);
        const daysSinceInception = Math.floor((lossDate.getTime() - inception.getTime()) / 86_400_000);
        const isPassed = daysSinceInception >= waitingPeriodDays;

        return {
            isPassed,
            waitingPeriodDays,
            daysSinceInception,
            failureReason: !isPassed
                ? `Loss date is within the ${waitingPeriodDays}-day waiting period (${daysSinceInception} days since inception)`
                : undefined,
        };
    }

    async findAll(tenantId: string): Promise<Policy[]> {
        return this.policyRepo.find({
            where: { tenantId },
            order: { createdAt: 'DESC' },
        });
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Private helpers
    // ─────────────────────────────────────────────────────────────────────────

    private async transitionStatus(
        tenantId: string,
        policyId: string,
        expectedFrom: string,
        toStatus: string,
        changedBy?: string,
        reason?: string,
    ): Promise<void> {
        const policy = await this.findOrFail(tenantId, policyId);
        if (policy.status !== expectedFrom) {
            throw new ConflictException(
                `Expected policy status ${expectedFrom}, got: ${policy.status}`,
            );
        }

        await this.policyRepo.update({ id: policyId }, { status: toStatus as any });

        await this.statusHistoryRepo.save(
            this.statusHistoryRepo.create({
                tenantId,
                policyId,
                fromStatus: expectedFrom as any,
                toStatus: toStatus as any,
                changedBy,
                changeReason: reason as any,
            } as any),
        );

        this.eventEmitter.emit(
            'policy.status.changed',
            new PolicyStatusChangedEvent(tenantId, policyId, expectedFrom, toStatus, changedBy, reason),
        );

        await this.auditLog.log({
            tenantId,
            entityType: AuditEntityType.POLICY,
            entityId: policyId,
            action: 'STATE_CHANGED',
            previousState: expectedFrom,
            newState: toStatus,
            performedBy: changedBy,
            context: { reason },
        });

        this.logger.log(`Policy status: ${expectedFrom} → ${toStatus} [policyId=${policyId}]`);
    }

    private async findQuoteOrFail(tenantId: string, quoteIdOrNumber: string): Promise<Quote> {
        const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

        if (uuidRegex.test(quoteIdOrNumber)) {
            const quote = await this.quoteRepo.findOne({ where: { id: quoteIdOrNumber, tenantId } });
            if (!quote) throw new NotFoundException(`Quote ID not found: ${quoteIdOrNumber}`);
            return quote;
        }

        const byNumber = await this.quoteRepo.findOne({ where: { quoteNumber: quoteIdOrNumber, tenantId } });
        if (!byNumber) throw new NotFoundException(`Quote Number not found: ${quoteIdOrNumber}`);
        return byNumber;
    }

    private async findOrFail(tenantId: string, policyId: string): Promise<Policy> {
        const p = await this.policyRepo.findOne({ where: { id: policyId, tenantId } });
        if (!p) throw new NotFoundException(`Policy not found: ${policyId}`);
        return p;
    }

    private async copyLineItemsToPolicyCoverages(
        tenantId: string,
        quoteId: string,
        policyId: string,
        productVersionId: string,
    ): Promise<void> {
        // In a full implementation this would copy QuoteLineItems into PolicyCoverage records
        // Placeholder — actual mapping requires QuoteLineItem repo injection
        this.logger.debug(`Coverage copy from quote ${quoteId} to policy ${policyId}`);
    }

    private generatePolicyNumber(tenantId: string): string {
        const prefix = tenantId.slice(0, 4).toUpperCase();
        const ts = Date.now().toString(36).toUpperCase();
        const rand = Math.random().toString(36).slice(2, 6).toUpperCase();
        return `${prefix}-${ts}-${rand}`;
    }

    private computeExpiryDate(from: Date, days: number): Date {
        const d = new Date(from);
        d.setDate(d.getDate() + days);
        return d;
    }
}
