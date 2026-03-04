import { Entity, Column, ManyToOne, JoinColumn, Index } from 'typeorm';
import { BaseTenantEntity } from '../../../common/entities/base-tenant.entity';

// ─────────────────────────────────────────────────────────────────────────────
// EligibilityRule
//
// Stores json-rules-engine compatible rule definitions for evaluating
// whether an applicant is eligible for a product version.
//
// Rule evaluation pattern (NestJS service):
//   const { Engine } = require('json-rules-engine');
//   const engine = new Engine();
//   engine.addRule(eligibilityRule.ruleLogic);
//   const { events } = await engine.run(applicantFacts);
// ─────────────────────────────────────────────────────────────────────────────
@Entity('eligibility_rules')
@Index(['tenantId', 'productVersionId', 'isActive'])
@Index(['ruleLogic']) // GIN normally, let migrate handle it
export class EligibilityRule extends BaseTenantEntity {
    @Column({ name: 'product_version_id', type: 'uuid' })
    productVersionId!: string;

    @Column({ length: 200 })
    name!: string;

    @Column({ type: 'text', nullable: true })
    description!: string;

    /**
     * json-rules-engine rule object.
     * Schema: { conditions: { all|any: [...] }, event: { type, params } }
     */
    @Column({ name: 'rule_logic', type: 'jsonb' })
    ruleLogic!: Record<string, unknown>;

    /** Higher priority rules are evaluated first */
    @Column({ type: 'int', default: 0 })
    priority!: number;

    @Column({ name: 'is_active', default: true })
    isActive!: boolean;
}

// ─────────────────────────────────────────────────────────────────────────────
// PricingRule
//
// Factor-based premium calculation rules stored as JSONB.
// Evaluated by the premium calculation service via json-rules-engine.
//
// Example ruleExpression:
// {
//   "baseRate": 500,
//   "factors": [
//     { "name": "age_band", "type": "lookup", "table": "age_rate_table" },
//     { "name": "smoker",   "type": "multiplier", "values": { "true": 1.5, "false": 1.0 } }
//   ],
//   "discounts": [{ "name": "loyalty", "maxPct": 10 }]
// }
// ─────────────────────────────────────────────────────────────────────────────
@Entity('pricing_rules')
@Index(['tenantId', 'productVersionId', 'isActive'])
@Index(['ruleExpression'])
export class PricingRule extends BaseTenantEntity {
    @Column({ name: 'product_version_id', type: 'uuid' })
    productVersionId!: string;

    @Column({ length: 200 })
    name!: string;

    @Column({ name: 'rule_expression', type: 'jsonb' })
    ruleExpression!: Record<string, unknown>;

    @Column({ name: 'effective_from', type: 'date', nullable: true })
    effectiveFrom!: string | null;

    @Column({ name: 'effective_to', type: 'date', nullable: true })
    effectiveTo!: string | null;

    @Column({ name: 'is_active', default: true })
    isActive!: boolean;
}

// ─────────────────────────────────────────────────────────────────────────────
// RateTable + RateTableEntry — actuarial lookup tables referenced by PricingRule
// ─────────────────────────────────────────────────────────────────────────────
@Entity('rate_tables')
@Index(['tenantId', 'code'], { unique: true })
export class RateTable extends BaseTenantEntity {
    @Column({ length: 100 })
    code!: string;

    @Column({ length: 200 })
    name!: string;

    @Column({ type: 'text', nullable: true })
    description!: string;
}

@Entity('rate_table_entries')
@Index(['tenantId', 'rateTableId', 'bandKey'])
export class RateTableEntry extends BaseTenantEntity {
    @Column({ name: 'rate_table_id', type: 'uuid' })
    rateTableId!: string;

    @ManyToOne(() => RateTable, { onDelete: 'CASCADE' })
    @JoinColumn({ name: 'rate_table_id' })
    rateTable!: RateTable;

    /** Lookup key — e.g. "18-25" for age band */
    @Column({ name: 'band_key', length: 100 })
    bandKey!: string;

    @Column({ type: 'numeric', precision: 10, scale: 6 })
    rate!: string;

    @Column({ type: 'jsonb', default: {} })
    metadata!: Record<string, unknown>;
}

// ─────────────────────────────────────────────────────────────────────────────
// FraudRule
//
// Fraud detection rules evaluated during FRAUD_REVIEW claim phase.
// Uses json-rules-engine. Severity gates automatic vs manual review.
// ─────────────────────────────────────────────────────────────────────────────
import { FraudRiskSeverity } from '../../../common/enums';

@Entity('fraud_rules')
@Index(['tenantId', 'isActive'])
@Index(['ruleLogic'])
export class FraudRule extends BaseTenantEntity {
    @Column({ length: 200 })
    name!: string;

    @Column({ type: 'text', nullable: true })
    description!: string;

    /**
     * json-rules-engine rule object evaluated against claim facts.
     * Triggered flags contribute to the FraudReview overall_score.
     */
    @Column({ name: 'rule_logic', type: 'jsonb' })
    ruleLogic!: Record<string, unknown>;

    @Column({ type: 'enum', enum: FraudRiskSeverity, default: FraudRiskSeverity.MEDIUM })
    severity!: FraudRiskSeverity;

    /** Score contribution when this rule fires (0–100) */
    @Column({ name: 'score_weight', type: 'int', default: 10 })
    scoreWeight!: number;

    @Column({ name: 'is_active', default: true })
    isActive!: boolean;
}
