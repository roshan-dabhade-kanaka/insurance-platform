// =============================================================================
// Risk Score Calculator — Insurance Platform
//
// Evaluates risk rules (stored in eligibility_rules JSONB with "risk_*" event types)
// and computes a total risk score, risk band, and loading percentage.
//
// Event types handled (from rule_logic.event.type in JSONB):
//   "risk_score_add"   → add a numeric score (e.g. bmi > 30 → +25 points)
//   "risk_multiplier"  → multiply running total (e.g. Sports Car → ×1.5)
//   "risk_decline"     → applicant is uninsurable (e.g. HAZARDOUS + pre-existing)
//
// Risk Band mapping (configurable, currently:)
//   0–200   → LOW      → 0% loading
//   201–400 → STANDARD → 10% loading
//   401–700 → HIGH     → 30–50% loading
//   701+    → DECLINED
//
// Risk rule JSONB example in DB:
//   {
//     "conditions": { "all": [{ "fact": "vehicleType", "operator": "equal", "value": "Sports Car" }] },
//     "event": { "type": "risk_multiplier", "params": { "multiplier": 1.5, "category": "VEHICLE" } }
//   }
// =============================================================================

import { Injectable, Logger } from '@nestjs/common';
import { RuleLoaderService } from './rule-loader.service';
import { RuleEvaluationService } from './rule-evaluation.service';
import {
    RiskFacts,
    RiskScoreResult,
    RiskMultiplier,
    RiskScoreContribution,
    LoadedRule,
} from '../interfaces/rule-types.interface';

// ── Risk event type constants ─────────────────────────────────────────────────
const EVENT_RISK_SCORE_ADD = 'risk_score_add';
const EVENT_RISK_MULTIPLIER = 'risk_multiplier';
const EVENT_RISK_DECLINE = 'risk_decline';

// ── Band thresholds ───────────────────────────────────────────────────────────
interface RiskBandConfig {
    max: number;
    band: 'LOW' | 'STANDARD' | 'HIGH' | 'DECLINED';
    loadingPct: number;
}

const DEFAULT_RISK_BANDS: RiskBandConfig[] = [
    { max: 200, band: 'LOW', loadingPct: 0 },
    { max: 400, band: 'STANDARD', loadingPct: 10 },
    { max: 700, band: 'HIGH', loadingPct: 35 },
    { max: Infinity, band: 'DECLINED', loadingPct: 0 },
];

@Injectable()
export class RiskScoreService {
    private readonly logger = new Logger(RiskScoreService.name);

    private readonly BASE_SCORE = 100;  // everyone starts with 100

    constructor(
        private readonly ruleLoader: RuleLoaderService,
        private readonly evaluationEngine: RuleEvaluationService,
    ) { }

    /**
     * Compute the risk score and loading percentage for an applicant.
     *
     * @param tenantId         Multi-tenant scope
     * @param productVersionId Product version whose risk rules to load
     * @param riskThreshold    Score above which senior UW is required
     * @param facts            Applicant / vehicle / property risk facts
     * @returns RiskScoreResult with total score, band, loading percentage
     */
    async calculate(
        tenantId: string,
        productVersionId: string,
        riskThreshold: number,
        facts: RiskFacts,
    ): Promise<RiskScoreResult> {
        const rules: LoadedRule[] = await this.ruleLoader.loadRiskRules(tenantId, productVersionId);

        if (rules.length === 0) {
            this.logger.log(`No risk rules found [tenant=${tenantId}] — returning base score`);
            return this.buildResult(this.BASE_SCORE, [], [], riskThreshold);
        }

        this.logger.debug(`Evaluating ${rules.length} risk rules`, { tenantId, productVersionId });

        // Run risk rules through json-rules-engine
        const evalResult = await this.evaluationEngine.evaluate(
            rules,
            facts as unknown as Record<string, unknown>,
        );

        // ── Interpret events ──────────────────────────────────────────────────
        let runningScore = this.BASE_SCORE;
        const contributions: RiskScoreContribution[] = [];
        const multipliers: RiskMultiplier[] = [];
        const declineReasons: string[] = [];

        for (const ev of evalResult.triggeredEvents) {
            const params = ev.params;

            switch (ev.type) {
                case EVENT_RISK_SCORE_ADD: {
                    // e.g. bmi > 30 → add 50 points
                    const points = params['points'] as number ?? 0;
                    const reason = params['reason'] as string ?? ev.ruleName;
                    const factName = params['fact'] as string ?? 'unknown';

                    runningScore += points;

                    contributions.push({
                        factorName: factName,
                        factValue: facts[factName],
                        scoreAdded: points,
                        reason,
                    });

                    this.logger.debug(`Risk score +${points}: ${reason}`);
                    break;
                }

                case EVENT_RISK_MULTIPLIER: {
                    // e.g. Sports Car → multiply by 1.5
                    const multiplier = params['multiplier'] as number ?? 1;
                    const category = params['category'] as string ?? 'GENERAL';
                    const reason = params['reason'] as string ?? `${category} risk multiplier`;

                    multipliers.push({ category, multiplier, reason, ruleName: ev.ruleName });
                    this.logger.debug(`Risk multiplier ×${multiplier}: ${reason}`);
                    break;
                }

                case EVENT_RISK_DECLINE: {
                    // e.g. HAZARDOUS occupation + critical illness → decline
                    const reason = params['reason'] as string ?? `Declined by rule: ${ev.ruleName}`;
                    declineReasons.push(reason);
                    this.logger.warn(`Risk DECLINE triggered: ${reason}`);
                    break;
                }
            }
        }

        // Apply all multipliers to running score
        let totalScore = runningScore;
        for (const m of multipliers) {
            totalScore = Math.round(totalScore * m.multiplier);
        }

        return this.buildResult(totalScore, contributions, multipliers, riskThreshold, declineReasons);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Private helpers
    // ─────────────────────────────────────────────────────────────────────────

    private buildResult(
        totalScore: number,
        contributions: RiskScoreContribution[],
        multipliers: RiskMultiplier[],
        riskThreshold: number,
        declineReasons: string[] = [],
    ): RiskScoreResult {
        const isDeclined = declineReasons.length > 0;

        const bandConfig = isDeclined
            ? ({ band: 'DECLINED' as const, loadingPct: 0, max: Infinity } as RiskBandConfig)
            : this.getBandForScore(totalScore);

        return {
            baseScore: this.BASE_SCORE,
            contributions,
            multipliers,
            totalScore: isDeclined ? totalScore : totalScore,
            riskBand: isDeclined ? 'DECLINED' : bandConfig.band,
            loadingPercentage: bandConfig.loadingPct,
            isDeclined,
            declineReasons,
        };
    }

    private getBandForScore(score: number): RiskBandConfig {
        return (
            DEFAULT_RISK_BANDS.find((b) => score <= b.max) ??
            DEFAULT_RISK_BANDS[DEFAULT_RISK_BANDS.length - 1]
        );
    }
}
