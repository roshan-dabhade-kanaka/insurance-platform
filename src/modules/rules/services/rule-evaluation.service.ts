// =============================================================================
// Rule Evaluation Service — Insurance Platform
//
// Core wrapper around json-rules-engine's Engine class.
// Provides a reusable, testable abstraction that:
//   - Creates an Engine instance per evaluation (stateless, safe for concurrency)
//   - Adds rules from LoadedRule[] (rules stored as JSONB in PostgreSQL)
//   - Adds computed facts (dynamic values derived from input facts)
//   - Runs the engine and returns typed events
//
// All specialist services (Eligibility, Pricing, Risk, Fraud) delegate to this.
// =============================================================================

import { Injectable, Logger } from '@nestjs/common';
import { Engine, EngineResult, RuleResult } from 'json-rules-engine';

import {
    LoadedRule,
    RuleEvaluationResult,
    RuleEvent,
    JsonRulesEngineRule,
} from '../interfaces/rule-types.interface';

export interface ComputedFact {
    name: string;
    /** A static value or a function that receives the current facts and returns a value */
    valueOrFn: unknown | ((facts: Record<string, unknown>) => unknown | Promise<unknown>);
}

export interface EvaluationOptions {
    /** Computed (dynamic) facts that the engine can resolve on demand */
    computedFacts?: ComputedFact[];
    /** If true, log every triggered event at DEBUG level */
    verbose?: boolean;
}

@Injectable()
export class RuleEvaluationService {
    private readonly logger = new Logger(RuleEvaluationService.name);

    /**
     * Evaluate a set of loaded rules against a facts object.
     *
     * @param rules    Rules loaded from the DB via RuleLoaderService
     * @param facts    The applicant/claim/vehicle fact values for this evaluation
     * @param options  Optional computed facts and verbosity
     * @returns        Triggered events + failure names + pass/fail summary
     */
    async evaluate(
        rules: LoadedRule[],
        facts: Record<string, unknown>,
        options: EvaluationOptions = {},
    ): Promise<RuleEvaluationResult> {
        if (rules.length === 0) {
            return { triggeredEvents: [], failedRuleNames: [], allRulesPassed: true };
        }

        // Create a fresh Engine per evaluation — Engines are not thread-safe to reuse
        const engine = new Engine([], { allowUndefinedFacts: true });

        // ── Register rules ──────────────────────────────────────────────────────
        for (const rule of rules) {
            try {
                const engineRule: JsonRulesEngineRule = {
                    name: rule.ruleId,          // use ruleId as name for tracking
                    priority: rule.priority,
                    ...rule.ruleDefinition,     // spread conditions + event from JSONB
                };
                engine.addRule(engineRule as any);
            } catch (err) {
                this.logger.error(
                    `Invalid rule definition [ruleId=${rule.ruleId}, name=${rule.name}]`,
                    err,
                );
                // Skip bad rules — don't fail the entire evaluation
            }
        }

        // ── Register computed facts (dynamic values) ────────────────────────────
        if (options.computedFacts?.length) {
            for (const cf of options.computedFacts) {
                if (typeof cf.valueOrFn === 'function') {
                    engine.addFact(cf.name, cf.valueOrFn as (params: unknown, almanac: unknown) => unknown);
                } else {
                    engine.addFact(cf.name, cf.valueOrFn);
                }
            }
        }

        // ── Run the engine ──────────────────────────────────────────────────────
        let engineResult: EngineResult;
        try {
            engineResult = await engine.run(facts);
        } catch (err) {
            this.logger.error('Engine run failed', err);
            throw new RuleEngineError(`Rule engine evaluation failed: ${(err as Error).message}`, err);
        }

        // ── Map results back to typed events ────────────────────────────────────

        // Build a ruleId → LoadedRule lookup for enriching results
        const ruleIdMap = new Map(rules.map((r) => [r.ruleId, r]));

        const triggeredEvents: RuleEvent[] = engineResult.events.map((evt) => {
            const matchedRule = ruleIdMap.get(evt.type) ?? this.findByName(rules, evt.type);
            return {
                type: evt.type,
                params: (evt.params ?? {}) as Record<string, unknown>,
                ruleName: matchedRule?.name ?? evt.type,
                ruleId: matchedRule?.ruleId ?? evt.type,
                priority: matchedRule?.priority ?? 1,
            };
        });

        // Also collect triggered rule events (json-rules-engine v6+ uses results)
        const passedEvents = this.extractEventsFromResults(engineResult.results, ruleIdMap);
        const allTriggered = this.deduplicateEvents([...triggeredEvents, ...passedEvents]);

        const failedRuleNames = engineResult.failureResults.map(
            (r: RuleResult) => ruleIdMap.get(r.name ?? '')?.name ?? r.name ?? 'unknown',
        );

        if (options.verbose) {
            allTriggered.forEach((ev) =>
                this.logger.debug(`[RULE HIT] ${ev.ruleName} → ${ev.type}`, ev.params),
            );
        }

        return {
            triggeredEvents: allTriggered,
            failedRuleNames,
            allRulesPassed: engineResult.failureResults.length === 0,
        };
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Private helpers
    // ─────────────────────────────────────────────────────────────────────────

    private findByName(rules: LoadedRule[], name: string): LoadedRule | undefined {
        return rules.find((r) => r.name === name);
    }

    private extractEventsFromResults(
        results: RuleResult[],
        ruleIdMap: Map<string, LoadedRule>,
    ): RuleEvent[] {
        return results.map((result) => {
            const matchedRule = ruleIdMap.get(result.name ?? '');
            return {
                type: result.event?.type ?? result.name ?? 'unknown',
                params: ((result.event?.params ?? {}) as Record<string, unknown>),
                ruleName: matchedRule?.name ?? result.name ?? 'unknown',
                ruleId: matchedRule?.ruleId ?? result.name ?? 'unknown',
                priority: matchedRule?.priority ?? 1,
            };
        });
    }

    private deduplicateEvents(events: RuleEvent[]): RuleEvent[] {
        const seen = new Set<string>();
        return events.filter((ev) => {
            const key = `${ev.ruleId}:${ev.type}`;
            if (seen.has(key)) return false;
            seen.add(key);
            return true;
        });
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom error
// ─────────────────────────────────────────────────────────────────────────────

export class RuleEngineError extends Error {
    constructor(message: string, public readonly cause?: unknown) {
        super(message);
        this.name = 'RuleEngineError';
    }
}
