// =============================================================================
// Rule Types & Interfaces — Insurance Platform
//
// Shared contracts for all rule evaluation services.
// These types mirror the JSONB structures stored in PostgreSQL tables:
//   eligibility_rules.rule_logic
//   pricing_rules.rule_expression
//   fraud_rules.rule_logic
// =============================================================================

// ─────────────────────────────────────────────────────────────────────────────
// json-rules-engine compatible rule schema
// All rules stored in PostgreSQL JSONB must conform to this structure so they
// can be loaded directly into the Engine without transformation.
// ─────────────────────────────────────────────────────────────────────────────

export interface JreCondition {
    fact: string;
    operator:
    | 'equal'
    | 'notEqual'
    | 'lessThan'
    | 'lessThanInclusive'
    | 'greaterThan'
    | 'greaterThanInclusive'
    | 'in'
    | 'notIn'
    | 'contains'
    | 'doesNotContain';
    value: unknown;
    path?: string;          // JSONPath into a fact that returns an object
}

export interface JreConditionGroup {
    all?: Array<JreCondition | JreConditionGroup>;
    any?: Array<JreCondition | JreConditionGroup>;
    not?: JreCondition | JreConditionGroup;
}

export interface JreEvent {
    type: string;
    params?: Record<string, unknown>;
}

/** A complete json-rules-engine rule object — stored as JSONB in PostgreSQL */
export interface JsonRulesEngineRule {
    name?: string;
    conditions: JreConditionGroup;
    event: JreEvent;
    priority?: number;        // higher = evaluated first; default 1
    onSuccess?: string;
    onFailure?: string;
}

// ─────────────────────────────────────────────────────────────────────────────
// Loaded Rule — enriched with DB metadata
// ─────────────────────────────────────────────────────────────────────────────

export interface LoadedRule {
    ruleId: string;
    tenantId: string;
    name: string;
    ruleDefinition: JsonRulesEngineRule;   // raw JSONB from DB
    priority: number;
    isActive: boolean;
}

// ─────────────────────────────────────────────────────────────────────────────
// Rule Evaluation Result — generic
// ─────────────────────────────────────────────────────────────────────────────

export interface RuleEvent {
    type: string;
    params: Record<string, unknown>;
    ruleName: string;
    ruleId: string;
    priority: number;
}

export interface RuleEvaluationResult {
    triggeredEvents: RuleEvent[];
    failedRuleNames: string[];
    allRulesPassed: boolean;
}

// ─────────────────────────────────────────────────────────────────────────────
// Eligibility Evaluation
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Facts supplied to the Eligibility Rule Engine.
 * Shape must match `fact` keys referenced in eligibility_rules.rule_logic JSONB.
 *
 * Example eligibility rule JSONB:
 * {
 *   "conditions": { "all": [{ "fact": "age", "operator": "greaterThan", "value": 65 }] },
 *   "event": { "type": "exclude_rider", "params": { "riderId": "PREMIUM_RIDER" } }
 * }
 */
export interface EligibilityFacts {
    age: number;
    smoker: boolean;
    bmi?: number;
    occupationClass?: string;         // OFFICE | MANUAL | HAZARDOUS
    existingConditions?: string[];
    residenceCountry?: string;
    annualIncome?: number;
    policyType?: string;
    coverageAmount?: number;
    vehicleType?: string;
    drivingRecord?: string;
    [key: string]: unknown;           // tenant-specific custom facts
}

export interface ExcludedRider {
    riderId: string;
    reason: string;
    ruleName: string;
}

export interface EligibilityEvaluationResult {
    isEligible: boolean;
    excludedRiders: ExcludedRider[];
    failedRules: Array<{ ruleName: string; reason: string }>;
    appliedLoadings: Array<{ reason: string; loadingPct: number }>;
    rawEvents: RuleEvent[];
}

// ─────────────────────────────────────────────────────────────────────────────
// Pricing Rule Evaluation
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Pricing rule JSONB stored in pricing_rules.rule_expression.
 *
 * Example:
 * {
 *   "baseRate": 500,
 *   "factors": [
 *     { "name": "smoker_loading",  "type": "PERCENTAGE", "fact": "smoker",      "operator": "equal",       "value": true,         "adjustment": 20,  "direction": "INCREASE" },
 *     { "name": "loyalty_discount","type": "PERCENTAGE", "fact": "policyYears", "operator": "greaterThan", "value": 5,            "adjustment": 10,  "direction": "DECREASE" },
 *     { "name": "age_loading",     "type": "LOOKUP",     "fact": "age",         "table": "age_rate_table", "interpolate": false }
 *   ]
 * }
 *
 * For LOOKUP type, the service fetches the rate from rate_table_entries by band_key.
 */
export interface PricingRuleExpression {
    baseRate: number;
    currency?: string;
    factors: PricingFactor[];
    minimumPremium?: number;
    maximumPremium?: number;
}

export type PricingFactorType = 'PERCENTAGE' | 'FLAT' | 'MULTIPLIER' | 'LOOKUP';
export type AdjustmentDirection = 'INCREASE' | 'DECREASE';

export interface PricingFactor {
    name: string;
    type: PricingFactorType;
    fact?: string;                   // fact name in applicant data
    operator?: JreCondition['operator'];
    value?: unknown;                 // comparison value for the condition
    adjustment?: number;             // for PERCENTAGE / FLAT / MULTIPLIER
    direction?: AdjustmentDirection;
    table?: string;                  // rate table code for LOOKUP type
    interpolate?: boolean;
    conditions?: JreConditionGroup;  // alternative to simple fact/operator/value
}

export interface PricingFacts {
    sumInsured: number;
    coverageCode: string;
    age: number;
    smoker: boolean;
    riskBand?: string;
    loadingPercentage?: number;
    vehicleType?: string;
    drivingRecord?: string;
    policyYears?: number;
    occupationClass?: string;
    bmi?: number;
    [key: string]: unknown;
}

export interface AppliedFactor {
    name: string;
    type: PricingFactorType;
    direction?: AdjustmentDirection;
    adjustmentValue: number;         // absolute amount applied
    adjustmentPct?: number;          // percentage applied if type is PERCENTAGE
    beforeAmount: number;
    afterAmount: number;
}

export interface PremiumBreakdown {
    basePremium: number;
    appliedFactors: AppliedFactor[];
    subtotalBeforeTax: number;
    taxRate: number;
    taxAmount: number;
    totalPremium: number;
}

// ─────────────────────────────────────────────────────────────────────────────
// Risk Score Calculation
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Risk rules JSONB — stored in eligibility_rules.rule_logic with
 * event.type = "risk_multiplier" | "risk_score_add" | "risk_decline"
 *
 * Example:
 * {
 *   "conditions": { "all": [{ "fact": "vehicleType", "operator": "equal", "value": "Sports Car" }] },
 *   "event": { "type": "risk_multiplier", "params": { "multiplier": 1.5, "category": "VEHICLE" } }
 * }
 */
export interface RiskFacts {
    age?: number;
    smoker?: boolean;
    bmi?: number;
    occupationClass?: string;
    vehicleType?: string;
    drivingRecord?: string;          // CLEAN | MINOR_VIOLATIONS | MAJOR_VIOLATIONS
    existingConditions?: string[];
    claimHistory?: number;           // number of claims in last 5 years
    electricalInstallationAge?: number;
    buildingMaterial?: string;
    [key: string]: unknown;
}

export interface RiskMultiplier {
    category: string;
    multiplier: number;
    reason: string;
    ruleName: string;
}

export interface RiskScoreContribution {
    factorName: string;
    factValue: unknown;
    scoreAdded: number;
    reason: string;
}

export interface RiskScoreResult {
    baseScore: number;
    contributions: RiskScoreContribution[];
    multipliers: RiskMultiplier[];
    totalScore: number;
    riskBand: 'LOW' | 'STANDARD' | 'HIGH' | 'DECLINED';
    loadingPercentage: number;
    isDeclined: boolean;
    declineReasons: string[];
}

// ─────────────────────────────────────────────────────────────────────────────
// Fraud Detection
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Fraud rule JSONB — stored in fraud_rules.rule_logic
 *
 * Example:
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
export interface FraudFacts {
    claimedAmount: number;
    averageClaimAmount: number;
    amount_to_average_ratio: number;   // pre-computed: claimedAmount / averageClaimAmount
    policyAgeDays: number;
    previousClaimsCount: number;
    claimantAge?: number;
    lossType?: string;
    providerCode?: string;
    isFirstClaim: boolean;
    timeSincePolicyInceptionDays: number;
    [key: string]: unknown;
}

export interface FraudFlag {
    ruleId: string;
    ruleName: string;
    severity: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL';
    scoreWeight: number;
    reason: string;
    flagDetail: Record<string, unknown>;
}

export interface FraudEvaluationResult {
    flags: FraudFlag[];
    totalScore: number;
    riskLevel: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL';
    shouldEscalate: boolean;
    escalationReason?: string;
}

// ─────────────────────────────────────────────────────────────────────────────
// Rule Loader Cache Entry
// ─────────────────────────────────────────────────────────────────────────────

export enum RuleType {
    ELIGIBILITY = 'ELIGIBILITY',
    PRICING = 'PRICING',
    RISK = 'RISK',
    FRAUD = 'FRAUD',
}

export interface RuleCacheEntry<T = LoadedRule[]> {
    data: T;
    cachedAt: number;
    ttlMs: number;
}
