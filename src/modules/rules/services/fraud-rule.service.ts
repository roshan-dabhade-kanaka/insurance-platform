// =============================================================================
// Fraud Rule Evaluator — Insurance Platform
//
// Evaluates fraud detection rules against a claim's facts using json-rules-engine.
// Rules are stored in fraud_rules.rule_logic (JSONB).
//
// Fraud Rule: IF claim_amount > 3× average THEN flag for fraud review
//
// Scoring model:
//   Each fraud rule carries a scoreWeight (0–100) and severity level.
//   Total fraud score = sum of all triggered rules' scoreWeights.
//
//   0–29   → LOW      → no escalation
//   30–49  → MEDIUM   → advisory flag only
//   50–74  → HIGH     → escalate to FRAUD_REVIEW
//   75+    → CRITICAL  → escalate + auto-reject threshold
//
// Amount multiplier rule (enforced outside json-rules-engine for determinism):
//   IF claimedAmount > escalationMultiplier × averageClaimAmount
//   THEN shouldEscalate = true regardless of score
//
// Temporal integration:
//   Implements IClaimRuleEngine.evaluateFraud()
//   Called by claim.activities.ts → evaluateFraudRules()
// =============================================================================

import { Injectable, Logger } from '@nestjs/common';
import { RuleLoaderService, LoadedFraudRule } from './rule-loader.service';
import { RuleEvaluationService } from './rule-evaluation.service';
import {
    FraudFacts,
    FraudEvaluationResult,
    FraudFlag,
} from '../interfaces/rule-types.interface';

// ── Scoring thresholds ────────────────────────────────────────────────────────
const ESCALATION_THRESHOLD = 50;      // total score above which we escalate
const CRITICAL_THRESHOLD = 75;

// ── Risk level classification ─────────────────────────────────────────────────
function classifyScore(score: number): FraudEvaluationResult['riskLevel'] {
    if (score >= CRITICAL_THRESHOLD) return 'CRITICAL';
    if (score >= ESCALATION_THRESHOLD) return 'HIGH';
    if (score >= 30) return 'MEDIUM';
    return 'LOW';
}

@Injectable()
export class FraudRuleService {
    private readonly logger = new Logger(FraudRuleService.name);

    constructor(
        private readonly ruleLoader: RuleLoaderService,
        private readonly evaluationEngine: RuleEvaluationService,
    ) { }

    /**
     * Evaluate fraud rules for a submitted claim.
     *
     * @param tenantId                  Multi-tenant scope
     * @param claimId                   Claim being evaluated (for logging)
     * @param claimedAmount             Amount on the claim
     * @param averageClaimAmount        Tenant-level historical average
     * @param escalationMultiplier      Default 3 — triggers escalation if claimedAmount > N × avg
     * @param claimantFacts             Additional facts (loss type, provider, etc.)
     * @returns FraudEvaluationResult   Flags, score, risk level, escalation decision
     *
     * @example
     * // Rule stored in fraud_rules.rule_logic JSONB:
     * {
     *   "conditions": {
     *     "all": [{ "fact": "amount_to_average_ratio", "operator": "greaterThan", "value": 3 }]
     *   },
     *   "event": {
     *     "type": "fraud_flag",
     *     "params": { "severity": "HIGH", "scoreWeight": 50, "reason": "Claim 3× above average" }
     *   }
     * }
     */
    async evaluate(
        tenantId: string,
        claimId: string,
        claimedAmount: number,
        averageClaimAmount: number,
        escalationMultiplier: number,
        claimantFacts: Record<string, unknown>,
    ): Promise<FraudEvaluationResult> {
        const rules: LoadedFraudRule[] = await this.ruleLoader.loadFraudRules(tenantId);

        // Compute derived facts used by rules (avoids division inside JSONB)
        const amountToAverageRatio =
            averageClaimAmount > 0 ? claimedAmount / averageClaimAmount : 0;

        const facts: FraudFacts = {
            claimedAmount,
            averageClaimAmount,
            amount_to_average_ratio: amountToAverageRatio,   // key fact for 3× rule
            isFirstClaim: (claimantFacts['previousClaimsCount'] as number ?? 0) === 0,
            previousClaimsCount: claimantFacts['previousClaimsCount'] as number ?? 0,
            policyAgeDays: claimantFacts['policyAgeDays'] as number ?? 0,
            timeSincePolicyInceptionDays: claimantFacts['timeSincePolicyInceptionDays'] as number ?? 0,
            ...claimantFacts,
        };

        this.logger.debug(`Evaluating fraud rules [claimId=${claimId}, ratio=${amountToAverageRatio.toFixed(2)}]`);

        // ── Run json-rules-engine ─────────────────────────────────────────────
        let flags: FraudFlag[] = [];
        let totalScore = 0;

        if (rules.length > 0) {
            // Build a ruleId → metadata map for enriching results
            const ruleMetaMap = new Map(rules.map((r) => [r.ruleId, r]));

            const evalResult = await this.evaluationEngine.evaluate(
                rules,
                facts as unknown as Record<string, unknown>,
            );

            for (const ev of evalResult.triggeredEvents) {
                if (ev.type !== 'fraud_flag') continue;

                const meta = ruleMetaMap.get(ev.ruleId);
                const severity = (ev.params['severity'] ?? meta?.severity ?? 'MEDIUM') as FraudFlag['severity'];
                const scoreWeight = (ev.params['scoreWeight'] ?? meta?.scoreWeight ?? 10) as number;
                const reason = (ev.params['reason'] ?? ev.ruleName) as string;

                flags.push({
                    ruleId: ev.ruleId,
                    ruleName: ev.ruleName,
                    severity,
                    scoreWeight,
                    reason,
                    flagDetail: ev.params,
                });

                totalScore += scoreWeight;
                this.logger.debug(`Fraud flag: ${ev.ruleName} [severity=${severity}, weight=${scoreWeight}]`);
            }
        }

        // ── Hard-coded Fraud Rule: amount > N × average ──────────────────────
        // This rule is enforced as code (not just JSONB) to guarantee it is ALWAYS
        // applied, even if no fraud rules exist in the DB for this tenant.
        const amountRuleTriggered = amountToAverageRatio > escalationMultiplier;
        const amountRuleAlreadyFlagged = flags.some((f) =>
            f.ruleName === 'AMOUNT_MULTIPLIER_THRESHOLD',
        );

        if (amountRuleTriggered && !amountRuleAlreadyFlagged) {
            const hardRuleScore = 50;
            const hardFlag: FraudFlag = {
                ruleId: 'SYSTEM:AMOUNT_MULTIPLIER',
                ruleName: 'AMOUNT_MULTIPLIER_THRESHOLD',
                severity: 'HIGH',
                scoreWeight: hardRuleScore,
                reason: `Claim amount (${claimedAmount}) exceeds ${escalationMultiplier}× tenant average (${averageClaimAmount})`,
                flagDetail: {
                    ratio: amountToAverageRatio,
                    threshold: escalationMultiplier,
                },
            };
            flags = [hardFlag, ...flags];
            totalScore += hardRuleScore;

            this.logger.warn(
                `Hard fraud rule triggered: amount ratio=${amountToAverageRatio.toFixed(2)} threshold=${escalationMultiplier} [claimId=${claimId}]`,
            );
        }

        // ── Classify and determine escalation ────────────────────────────────
        const riskLevel = classifyScore(totalScore);
        const shouldEscalate = amountRuleTriggered || totalScore >= ESCALATION_THRESHOLD;

        let escalationReason: string | undefined;
        if (shouldEscalate) {
            escalationReason = amountRuleTriggered
                ? `Claim amount ${amountToAverageRatio.toFixed(1)}× above average`
                : `Fraud score ${totalScore} exceeds escalation threshold ${ESCALATION_THRESHOLD}`;
        }

        this.logger.log(
            `Fraud evaluation complete [claimId=${claimId}]: score=${totalScore}, level=${riskLevel}, escalate=${shouldEscalate}`,
        );

        return {
            flags,
            totalScore,
            riskLevel,
            shouldEscalate,
            escalationReason,
        };
    }

    /**
     * Quick check — is the amount multiplier rule triggered?
     * Used in claim intake UI to show a warning before full evaluation.
     */
    isAmountFraudRuleTriggered(
        claimedAmount: number,
        averageClaimAmount: number,
        escalationMultiplier: number,
    ): boolean {
        if (averageClaimAmount <= 0) return false;
        return claimedAmount / averageClaimAmount > escalationMultiplier;
    }
}
