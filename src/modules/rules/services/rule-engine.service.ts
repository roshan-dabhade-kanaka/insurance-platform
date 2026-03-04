// =============================================================================
// Rule Engine Service — Composite Temporal Adapter
//
// This is the integration layer that Temporal activities consume.
// It adapts the individual rule services to match the interface contracts
// expected by quote.activities.ts and claim.activities.ts.
//
// Implements:
//   IRuleEngineService (from quote.activities.ts)
//   IClaimRuleEngine   (from claim.activities.ts)
//
// This single service is registered with both worker factories:
//   createQuoteActivities({ ruleEngine: this.ruleEngineService, ... })
//   createClaimActivities({ ruleEngine: this.ruleEngineService, ... })
// =============================================================================

import { Injectable } from '@nestjs/common';
import { EligibilityRuleService } from './eligibility-rule.service';
import { PricingRuleService } from './pricing-rule.service';
import { RiskScoreService } from './risk-score.service';
import { FraudRuleService } from './fraud-rule.service';
import {
    EligibilityFacts,
    RiskFacts,
} from '../interfaces/rule-types.interface';

// ── Interfaces (re-declared to keep this module self-contained) ───────────────

export interface EligibilityEvalIn {
    tenantId: string;
    quoteId: string;
    productVersionId: string;
    applicantData: Record<string, unknown>;
    riskProfileId: string;
}

export interface EligibilityEvalOut {
    isEligible: boolean;
    failedRules: Array<{ ruleName: string; reason: string }>;
}

export interface FraudEvalOut {
    shouldEscalate: boolean;
    overallScore: number;
    triggeredRules: Array<{ ruleName: string; score: number; severity: string }>;
    riskLevel: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL';
}

@Injectable()
export class RuleEngineService {
    constructor(
        private readonly eligibilityRuleService: EligibilityRuleService,
        private readonly pricingRuleService: PricingRuleService,
        private readonly riskScoreService: RiskScoreService,
        private readonly fraudRuleService: FraudRuleService,
    ) { }

    // ── IRuleEngineService (Quote activities adapter) ─────────────────────────

    async getEligibilityRules(
        tenantId: string,
        productVersionId: string,
    ): Promise<unknown[]> {
        // Rules are loaded lazily inside evaluateEligibility — this returns an opaque token
        return [{ tenantId, productVersionId }];
    }

    async evaluateEligibility(
        _rules: unknown[],
        facts: Record<string, unknown>,
    ): Promise<EligibilityEvalOut> {
        const { tenantId, productVersionId } = _rules[0] as {
            tenantId: string;
            productVersionId: string;
        };

        const result = await this.eligibilityRuleService.evaluate(
            tenantId,
            productVersionId,
            facts as unknown as EligibilityFacts,
        );

        return {
            isEligible: result.isEligible,
            failedRules: result.failedRules,
        };
    }

    // ── IClaimRuleEngine (Claim activities adapter) ───────────────────────────

    async getFraudRules(tenantId: string): Promise<unknown[]> {
        return [{ tenantId }];
    }

    async evaluateFraud(
        _rules: unknown[],
        facts: Record<string, unknown>,
    ): Promise<FraudEvalOut> {
        const { tenantId } = _rules[0] as { tenantId: string };

        const result = await this.fraudRuleService.evaluate(
            tenantId,
            facts['claimId'] as string ?? 'unknown',
            facts['claimedAmount'] as number,
            facts['averageClaimAmount'] as number,
            facts['escalationMultiplier'] as number ?? 3,
            facts,
        );

        return {
            shouldEscalate: result.shouldEscalate,
            overallScore: result.totalScore,
            triggeredRules: result.flags.map((f) => ({
                ruleName: f.ruleName,
                score: f.scoreWeight,
                severity: f.severity,
            })),
            riskLevel: result.riskLevel,
        };
    }

    // ── Direct access for NestJS services (not Temporal) ─────────────────────

    get eligibility(): EligibilityRuleService {
        return this.eligibilityRuleService;
    }

    get pricing(): PricingRuleService {
        return this.pricingRuleService;
    }

    get risk(): RiskScoreService {
        return this.riskScoreService;
    }

    get fraud(): FraudRuleService {
        return this.fraudRuleService;
    }
}
