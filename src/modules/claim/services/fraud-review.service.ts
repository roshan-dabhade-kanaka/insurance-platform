// =============================================================================
// Fraud Review Service — Insurance Platform
//
// Manages the fraud review lifecycle for escalated claims:
//   1. evaluateFraudRules()  — loads JSONB fraud rules + runs json-rules-engine
//   2. recordReview()        — persists fraud reviewer's decision
//   3. flagClaim()           — create individual fraud flags
//   4. escalate()            — sends fraudReviewDecision signal to Temporal
//
// Fraud Detection Rule (enforced both in RuleEngineService and here):
//   IF claim_amount > 3× average THEN escalate to FRAUD_REVIEW
//
// Called by:
//   - Temporal claim.activities.ts → evaluateFraudRules(), recordFraudReview()
//   - FraudReviewController → fraudReviewDecisionSignal to Temporal
//
// Emits: fraud.review.escalated, fraud.review.decided
// =============================================================================

import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { EventEmitter2 } from '@nestjs/event-emitter';

import { FraudReview } from '../../claim/entities/claim.entity';
import { FraudReviewFlag as FraudFlagEntity } from '../../claim/entities/claim.entity';
import { AuditLogService } from '../../audit/services/audit-log.service';
import { AuditEntityType } from '../../../common/enums';
import { RuleEngineService } from '../../rules/services/rule-engine.service';
import { TemporalClientService } from '../../../temporal/worker/worker';
import { fraudReviewDecisionSignal, FraudReviewDecision } from '../../../temporal/shared/types';

// ─────────────────────────────────────────────────────────────────────────────
// Domain Events
// ─────────────────────────────────────────────────────────────────────────────

export class FraudEscalatedEvent {
    constructor(
        public readonly tenantId: string,
        public readonly claimId: string,
        public readonly fraudScore: number,
        public readonly riskLevel: string,
    ) { }
}

export class FraudReviewDecidedEvent {
    constructor(
        public readonly tenantId: string,
        public readonly claimId: string,
        public readonly decision: string,
        public readonly reviewedBy: string,
    ) { }
}

// ─────────────────────────────────────────────────────────────────────────────
// Input DTOs
// ─────────────────────────────────────────────────────────────────────────────

export interface RecordFraudReviewDto {
    tenantId: string;
    claimId: string;
    decision: string;
    overallScore: number;
    reviewedBy: string;
    reviewerNotes?: string;
    triggeredRules: Array<{ ruleName: string; score: number; severity: string }>;
}

export interface SubmitFraudDecisionDto {
    tenantId: string;
    claimId: string;
    reviewedBy: string;
    decision: FraudReviewDecision;
    overallScore: number;
    reviewerNotes?: string;
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

@Injectable()
export class FraudReviewService {
    private readonly logger = new Logger(FraudReviewService.name);

    constructor(
        @InjectRepository(FraudReview)
        private readonly reviewRepo: Repository<FraudReview>,

        @InjectRepository(FraudFlagEntity)
        private readonly flagRepo: Repository<FraudFlagEntity>,

        private readonly ruleEngine: RuleEngineService,
        private readonly temporalClient: TemporalClientService,
        private readonly auditLog: AuditLogService,
        private readonly eventEmitter: EventEmitter2,
    ) { }

    // ─────────────────────────────────────────────────────────────────────────
    // evaluateFraud — wrapper used by Temporal claim activity
    // ─────────────────────────────────────────────────────────────────────────

    async evaluateFraud(
        tenantId: string,
        claimId: string,
        claimedAmount: number,
        averageClaimAmount: number,
        escalationMultiplier: number,
        claimantFacts: Record<string, unknown>,
    ) {
        const fraudRuleToken = await this.ruleEngine.getFraudRules(tenantId);
        return this.ruleEngine.evaluateFraud(fraudRuleToken, {
            claimId,
            claimedAmount,
            averageClaimAmount,
            escalationMultiplier,
            ...claimantFacts,
        });
    }

    // ─────────────────────────────────────────────────────────────────────────
    // recordReview — persists fraud review decision (called by Temporal activity)
    // ─────────────────────────────────────────────────────────────────────────

    async recordReview(dto: RecordFraudReviewDto): Promise<void> {
        const review = new FraudReview();
        Object.assign(review, {
            tenantId: dto.tenantId,
            claimId: dto.claimId,
            reviewOutcome: dto.decision as any,
            overallScore: String(dto.overallScore),
            reviewedBy: dto.reviewedBy,
            reviewerNotes: dto.reviewerNotes,
            reviewedAt: new Date(),
        });
        const saved = await this.reviewRepo.save(review);

        // Persist individual fraud flags
        if (dto.triggeredRules.length > 0) {
            const flags = dto.triggeredRules.map((r) => {
                const flag = new FraudFlagEntity();
                Object.assign(flag, {
                    tenantId: dto.tenantId,
                    fraudReviewId: (saved as any).id,
                    ruleName: r.ruleName,
                    scoreContribution: String(r.score),
                    flagDetail: {},
                });
                return flag;
            });
            await this.flagRepo.save(flags);
        }

        // Emit event
        this.eventEmitter.emit(
            'fraud.review.decided',
            new FraudReviewDecidedEvent(dto.tenantId, dto.claimId, dto.decision, dto.reviewedBy),
        );

        // Audit log
        await this.auditLog.log({
            tenantId: dto.tenantId,
            entityType: AuditEntityType.CLAIM,
            entityId: dto.claimId,
            action: 'FRAUD_REVIEWED',
            newState: dto.decision,
            performedBy: dto.reviewedBy,
            context: {
                overallScore: dto.overallScore,
                triggeredRuleCount: dto.triggeredRules.length,
                reviewId: saved.id,
            },
        });

        this.logger.log(
            `Fraud review recorded: ${dto.decision} [claimId=${dto.claimId}, score=${dto.overallScore}]`,
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // submitDecision — fraud analyst submits via API → signals Temporal
    // ─────────────────────────────────────────────────────────────────────────

    async submitDecision(dto: SubmitFraudDecisionDto): Promise<void> {
        // 1. Send signal to Temporal workflow
        const handle = await this.temporalClient.getClaimHandle(dto.tenantId, dto.claimId);
        await handle.signal(fraudReviewDecisionSignal, {
            reviewedBy: dto.reviewedBy,
            decision: dto.decision,
            overallScore: dto.overallScore,
            reviewerNotes: dto.reviewerNotes,
        });

        // 2. Audit the signal dispatch
        await this.auditLog.log({
            tenantId: dto.tenantId,
            entityType: AuditEntityType.CLAIM,
            entityId: dto.claimId,
            action: 'FRAUD_DECISION_SIGNALED',
            performedBy: dto.reviewedBy,
            context: { decision: dto.decision, score: dto.overallScore },
        });

        this.logger.log(
            `Fraud decision signal sent: ${dto.decision} [claimId=${dto.claimId}]`,
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // getReviewHistory — all fraud reviews for a claim
    // ─────────────────────────────────────────────────────────────────────────

    async getReviewHistory(tenantId: string, claimId: string): Promise<FraudReview[]> {
        return this.reviewRepo.find({
            where: { tenantId, claimId },
            order: { reviewedAt: 'DESC' },
        });
    }

    async getPendingReviews(tenantId: string): Promise<any[]> {
        // This is a bit of a simplification; in a real system we might have a specific FraudReview record
        // but often we just want to see claims that are stuck in the FRAUD_REVIEW state.
        // Re-using the reviewRepo if we want to see existing reviews, OR using a Claim join.
        // For this task, let's return claims with status 'FRAUD_REVIEW'.
        return this.reviewRepo.manager.getRepository('claims').find({
            where: { tenantId, status: 'FRAUD_REVIEW' } as any,
            order: { createdAt: 'DESC' },
        });
    }
}
