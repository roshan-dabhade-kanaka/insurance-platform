// =============================================================================
// Eligibility Rule Service — Insurance Platform
//
// Evaluates eligibility rules for a given applicant + product version.
// Uses json-rules-engine via RuleEvaluationService.
//
// Event types handled (from rule_logic JSONB):
//   "exclude_rider"     → remove a rider from the quote
//   "ineligible"        → applicant cannot be covered at all
//   "loading_required"  → extra premium loading due to a condition
//   "risk_multiplier"   → delegated to RiskScoreService; filtered out here
//
// Temporal integration:
//   Implements IRuleEngineService.evaluateEligibility()
//   Used by quote.activities.ts → evaluateEligibilityRules()
// =============================================================================

import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';

import { RuleLoaderService } from './rule-loader.service';
import { RuleEvaluationService } from './rule-evaluation.service';
import {
    EligibilityFacts,
    EligibilityEvaluationResult,
    ExcludedRider,
    LoadedRule,
    RuleEvent,
} from '../interfaces/rule-types.interface';

// ── Eligibility event type constants ─────────────────────────────────────────
const EVENT_EXCLUDE_RIDER = 'exclude_rider';
const EVENT_INELIGIBLE = 'ineligible';
const EVENT_LOADING_REQUIRED = 'loading_required';

@Injectable()
export class EligibilityRuleService {
    private readonly logger = new Logger(EligibilityRuleService.name);

    constructor(
        private readonly ruleLoader: RuleLoaderService,
        private readonly evaluationEngine: RuleEvaluationService,
    ) { }

    /**
     * Evaluate eligibility rules for an applicant.
     *
     * @param tenantId         Multi-tenant scope
     * @param productVersionId The specific product version whose rules to load
     * @param facts            Applicant data facts
     * @returns                Eligibility result with excluded riders + failed rules
     *
     * @example
     * // Rule in DB (eligibility_rules.rule_logic JSONB):
     * {
     *   "conditions": { "all": [{ "fact": "age", "operator": "greaterThan", "value": 65 }] },
     *   "event": { "type": "exclude_rider", "params": { "riderId": "PREMIUM_RIDER", "reason": "Age > 65" } }
     * }
     */
    async evaluate(
        tenantId: string,
        productVersionId: string,
        facts: EligibilityFacts,
    ): Promise<EligibilityEvaluationResult> {
        // 1. Load rules from DB (cached)
        const rules: LoadedRule[] = await this.ruleLoader.loadEligibilityRules(
            tenantId,
            productVersionId,
        );

        if (rules.length === 0) {
            this.logger.log(`No eligibility rules found [tenant=${tenantId}, version=${productVersionId}] — allowing all`);
            return this.buildResult(true, [], [], []);
        }

        this.logger.debug(`Evaluating ${rules.length} eligibility rules`, { tenantId, productVersionId });

        // 2. Add computed facts: e.g., has_preexisting_conditions derived from array
        const computedFacts = [
            {
                name: 'has_preexisting_conditions',
                valueOrFn: Array.isArray(facts.existingConditions) && facts.existingConditions.length > 0,
            },
            {
                name: 'existingCondition_count',
                valueOrFn: Array.isArray(facts.existingConditions) ? facts.existingConditions.length : 0,
            },
        ];

        // 3. Run the engine
        const result = await this.evaluationEngine.evaluate(
            rules,
            facts as unknown as Record<string, unknown>,
            { computedFacts },
        );

        // 4. Interpret triggered events
        const excludedRiders: ExcludedRider[] = [];
        const failedRules: Array<{ ruleName: string; reason: string }> = [];
        const appliedLoadings: Array<{ reason: string; loadingPct: number }> = [];
        let isIneligible = false;

        for (const ev of result.triggeredEvents) {
            switch (ev.type) {
                case EVENT_EXCLUDE_RIDER: {
                    const riderId = ev.params['riderId'] as string;
                    const reason = ev.params['reason'] as string ?? ev.ruleName;
                    if (riderId) {
                        excludedRiders.push({ riderId, reason, ruleName: ev.ruleName });
                        this.logger.debug(`Rider excluded: ${riderId} — ${reason}`);
                    }
                    break;
                }

                case EVENT_INELIGIBLE: {
                    isIneligible = true;
                    failedRules.push({
                        ruleName: ev.ruleName,
                        reason: (ev.params['reason'] as string) ?? `Ineligible: ${ev.ruleName}`,
                    });
                    this.logger.warn(`Applicant declared INELIGIBLE by rule: ${ev.ruleName}`);
                    break;
                }

                case EVENT_LOADING_REQUIRED: {
                    const loadingPct = ev.params['loadingPct'] as number ?? 0;
                    const reason = ev.params['reason'] as string ?? ev.ruleName;
                    if (loadingPct > 0) {
                        appliedLoadings.push({ reason, loadingPct });
                    }
                    break;
                }

                default:
                    // risk_multiplier and other events are handled by RiskScoreService — ignore here
                    break;
            }
        }

        return this.buildResult(
            !isIneligible,
            excludedRiders,
            failedRules,
            appliedLoadings,
            result.triggeredEvents,
        );
    }

    /**
     * Check if a specific rider is excluded for an applicant.
     * Useful for quick guard checks in the quote builder UI.
     */
    async isRiderExcluded(
        tenantId: string,
        productVersionId: string,
        riderId: string,
        facts: EligibilityFacts,
    ): Promise<{ excluded: boolean; reason?: string }> {
        const result = await this.evaluate(tenantId, productVersionId, facts);
        const match = result.excludedRiders.find((r) => r.riderId === riderId);
        return { excluded: !!match, reason: match?.reason };
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Private helpers
    // ─────────────────────────────────────────────────────────────────────────

    private buildResult(
        isEligible: boolean,
        excludedRiders: ExcludedRider[],
        failedRules: Array<{ ruleName: string; reason: string }>,
        appliedLoadings: Array<{ reason: string; loadingPct: number }>,
        rawEvents: RuleEvent[] = [],
    ): EligibilityEvaluationResult {
        return { isEligible, excludedRiders, failedRules, appliedLoadings, rawEvents };
    }
}
