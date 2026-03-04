// =============================================================================
// Pricing Rule Service & Premium Calculator — Insurance Platform
//
// Evaluates JSONB pricing rules to compute the full premium breakdown.
// No hardcoded premium logic — all rates, factors, and adjustments come from
// the `pricing_rules.rule_expression` JSONB column.
//
// Pricing Factor Types:
//   PERCENTAGE  → adjust current running total by ±N%
//   FLAT        → add/subtract a flat amount
//   MULTIPLIER  → multiply the running total by factor
//   LOOKUP      → fetch rate from rate_table_entries by band key
//
// Temporal integration:
//   Implements IPremiumService.calculate()
//   Called by quote.activities.ts → calculatePremium()
// =============================================================================

import { Injectable, Logger, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Not, In } from 'typeorm';

import { RuleLoaderService, LoadedPricingRule } from './rule-loader.service';
import {
    PricingFacts,
    PremiumBreakdown,
    AppliedFactor,
    PricingFactor,
    PricingRuleExpression,
} from '../interfaces/rule-types.interface';
import { RateTableEntry } from '../entities/rules.entity';
import { Quote, PremiumSnapshot } from '../../quote/entities/quote.entity';
import { ProductVersion } from '../../product/entities/product.entity';

/** Input line item shape for premium calculation (sumInsured may be number from API) */
export interface QuoteLineItemInput {
    sumInsured: number | string;
    coverageOptionId: string;
}

// ─────────────────────────────────────────────────────────────────────────────
// Input/Output Types
// ─────────────────────────────────────────────────────────────────────────────

export interface PremiumCalculationInput {
    tenantId: string;
    quoteId: string;
    productVersionId: string;
    lineItems: QuoteLineItemInput[];
    riskProfileId: string;
    loadingPercentage: number;       // from RiskScoreService result
    applicantData: Record<string, unknown>;
}

export interface PremiumCalculationOutput {
    snapshotId: string;
    basePremium: number;
    riderSurcharge: number;
    riskLoading: number;
    discountAmount: number;
    taxAmount: number;
    totalPremium: number;
    breakdown: PremiumBreakdown[];   // one per line item
}

export interface LockSnapshotResult {
    locked: boolean;
    lockedAt: string;
}

@Injectable()
export class PricingRuleService {
    private readonly logger = new Logger(PricingRuleService.name);

    private readonly TAX_RATE = 0.18; // 18% GST — configurable via env if needed

    constructor(
        private readonly ruleLoader: RuleLoaderService,

        @InjectRepository(RateTableEntry)
        private readonly rateTableEntryRepo: Repository<RateTableEntry>,

        @InjectRepository(PremiumSnapshot)
        private readonly snapshotRepo: Repository<PremiumSnapshot>,

        @InjectRepository(Quote)
        private readonly quoteRepo: Repository<Quote>,

        @InjectRepository(ProductVersion)
        private readonly productVersionRepo: Repository<ProductVersion>,
    ) { }

    // ─────────────────────────────────────────────────────────────────────────
    // Main calculation entrypoint
    // ─────────────────────────────────────────────────────────────────────────

    async calculate(input: PremiumCalculationInput): Promise<PremiumCalculationOutput> {
        const [quote, productVersion] = await Promise.all([
            this.quoteRepo.findOne({ where: { id: input.quoteId, tenantId: input.tenantId } }),
            this.productVersionRepo.findOne({ where: { id: input.productVersionId, tenantId: input.tenantId } }),
        ]);

        if (!quote) throw new NotFoundException(`Quote not found: ${input.quoteId}`);
        if (!productVersion) throw new NotFoundException(`Product version not found: ${input.productVersionId}`);

        const pricingRules = await this.ruleLoader.loadPricingRules(
            input.tenantId,
            input.productVersionId,
        );

        if (pricingRules.length === 0) {
            throw new BadRequestException(`No active pricing rules found for product version ${input.productVersionId}. Please configure a Pricing Rule first.`);
        }

        const lineItemBreakdowns: PremiumBreakdown[] = [];
        let totalBasePremium = 0;
        let totalRiderSurcharge = 0;
        let totalDiscountAmount = 0;
        let totalTaxAmount = 0;

        // Evaluate pricing for each line item independently
        for (const lineItem of input.lineItems) {
            const facts: PricingFacts = {
                sumInsured: typeof lineItem.sumInsured === 'string' ? Number(lineItem.sumInsured) : lineItem.sumInsured,
                coverageCode: lineItem.coverageOptionId,
                ...input.applicantData,
                loadingPercentage: input.loadingPercentage,
            } as PricingFacts;

            // Find the applicable pricing rule for this coverage
            const applicableRule = this.findApplicableRule(pricingRules, lineItem.coverageOptionId);

            if (!applicableRule) {
                this.logger.warn(`No pricing rule matched coverageOptionId=${lineItem.coverageOptionId}`);
                continue;
            }

            const breakdown = await this.computePremium(
                applicableRule.expression,
                facts,
                input.tenantId,
            );

            lineItemBreakdowns.push(breakdown);

            totalBasePremium += breakdown.basePremium;
            totalDiscountAmount += breakdown.appliedFactors
                .filter((f) => f.direction === 'DECREASE')
                .reduce((sum, f) => sum + f.adjustmentValue, 0);
            totalTaxAmount += breakdown.taxAmount;
        }

        // Apply risk loading (from RiskScoreService) as a top-level surcharge
        const riskLoading = (totalBasePremium * input.loadingPercentage) / 100;
        const subtotal = totalBasePremium + riskLoading - totalDiscountAmount;
        const taxOnRiskLoading = riskLoading * this.TAX_RATE;
        const grandTotal = subtotal + totalTaxAmount + taxOnRiskLoading;

        // Persist an immutable premium snapshot
        const snapshot = this.snapshotRepo.create({
            tenantId: input.tenantId,
            quoteId: input.quoteId,
            productVersionId: input.productVersionId,
            calculationInputs: {
                lineItems: input.lineItems,
                applicantData: input.applicantData,
                loadingPercentage: input.loadingPercentage,
                riskProfileId: input.riskProfileId,
            },
            basePremium: String(totalBasePremium),
            riderSurcharge: String(totalRiderSurcharge),
            riskLoading: String(riskLoading),
            discountAmount: String(totalDiscountAmount),
            taxAmount: String(totalTaxAmount + taxOnRiskLoading),
            totalPremium: String(grandTotal),
            isLocked: false,
            factorBreakdown: lineItemBreakdowns as any,
        } as any);

        const saved = await this.snapshotRepo.save(snapshot);

        this.logger.log(
            `Premium calculated: base=${totalBasePremium} loading=${riskLoading} total=${grandTotal} [quoteId=${input.quoteId}]`,
        );

        const savedOne = Array.isArray(saved) ? saved[0] : saved;
        return {
            snapshotId: savedOne.id,
            basePremium: totalBasePremium,
            riderSurcharge: totalRiderSurcharge,
            riskLoading,
            discountAmount: totalDiscountAmount,
            taxAmount: totalTaxAmount + taxOnRiskLoading,
            totalPremium: grandTotal,
            breakdown: lineItemBreakdowns,
        };
    }

    /**
     * Lock the premium snapshot — called immediately after UW approval.
     * Prevents recalculation of an approved quote.
     */
    async lockSnapshot(tenantId: string, snapshotId: string): Promise<LockSnapshotResult> {
        const lockedAt = new Date();
        await this.snapshotRepo.update(
            { id: snapshotId, tenantId },
            { isLocked: true },
        );
        this.logger.log(`Premium snapshot locked: ${snapshotId}`);
        return { locked: true, lockedAt: lockedAt.toISOString() };
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Premium computation for a single line item
    // All pricing logic reads from PricingRuleExpression — no hardcoding
    // ─────────────────────────────────────────────────────────────────────────

    private async computePremium(
        expression: PricingRuleExpression,
        facts: PricingFacts,
        tenantId: string,
    ): Promise<PremiumBreakdown> {
        let running = expression.baseRate;
        const appliedFactors: AppliedFactor[] = [];

        for (const factor of expression.factors) {
            if (!this.isFactorApplicable(factor, facts)) continue;

            const before = running;
            let adjustment = 0;

            switch (factor.type) {
                case 'PERCENTAGE': {
                    // Example: smoker=true → increase by 20%
                    // Rule: { type: "PERCENTAGE", fact: "smoker", operator: "equal", value: true, adjustment: 20, direction: "INCREASE" }
                    adjustment = (running * (factor.adjustment ?? 0)) / 100;
                    running = factor.direction === 'INCREASE' ? running + adjustment : running - adjustment;
                    break;
                }

                case 'FLAT': {
                    // Example: disability rider → flat +200
                    adjustment = factor.adjustment ?? 0;
                    running = factor.direction === 'INCREASE' ? running + adjustment : running - adjustment;
                    break;
                }

                case 'MULTIPLIER': {
                    // Example: risk band HIGH → multiply by 1.5
                    const multiplier = factor.adjustment ?? 1;
                    adjustment = running * (multiplier - 1);
                    running = running * multiplier;
                    break;
                }

                case 'LOOKUP': {
                    // Example: age band lookup from rate_table_entries
                    // Rule: { type: "LOOKUP", fact: "age", table: "AGE_RATE_TABLE", interpolate: false }
                    const lookupRate = await this.fetchRateFromTable(
                        tenantId,
                        factor.table!,
                        facts[factor.fact!],
                    );
                    if (lookupRate !== null) {
                        adjustment = lookupRate;
                        running += lookupRate;
                    }
                    break;
                }
            }

            appliedFactors.push({
                name: factor.name,
                type: factor.type,
                direction: factor.direction,
                adjustmentValue: Math.abs(adjustment),
                adjustmentPct: factor.type === 'PERCENTAGE' ? factor.adjustment : undefined,
                beforeAmount: before,
                afterAmount: running,
            });
        }

        // Apply floor / ceiling from rule expression
        if (expression.minimumPremium !== undefined) {
            running = Math.max(running, expression.minimumPremium);
        }
        if (expression.maximumPremium !== undefined) {
            running = Math.min(running, expression.maximumPremium);
        }

        const taxAmount = running * this.TAX_RATE;
        const totalPremium = running + taxAmount;

        return {
            basePremium: expression.baseRate,
            appliedFactors,
            subtotalBeforeTax: running,
            taxRate: this.TAX_RATE,
            taxAmount,
            totalPremium,
        };
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Factor applicability check
    // ─────────────────────────────────────────────────────────────────────────

    private isFactorApplicable(factor: PricingFactor, facts: PricingFacts): boolean {
        if (!factor.fact || factor.operator === undefined || factor.value === undefined) {
            // LOOKUP type or condition-only factors — always apply; condition checked separately
            return true;
        }

        const factValue = facts[factor.fact];
        return this.compare(factValue, factor.operator, factor.value);
    }

    private compare(
        factValue: unknown,
        operator: string,
        value: unknown,
    ): boolean {
        switch (operator) {
            case 'equal': return factValue === value;
            case 'notEqual': return factValue !== value;
            case 'greaterThan': return (factValue as number) > (value as number);
            case 'greaterThanInclusive': return (factValue as number) >= (value as number);
            case 'lessThan': return (factValue as number) < (value as number);
            case 'lessThanInclusive': return (factValue as number) <= (value as number);
            case 'in': return Array.isArray(value) && value.includes(factValue);
            case 'notIn': return Array.isArray(value) && !value.includes(factValue);
            case 'contains': return Array.isArray(factValue) && factValue.includes(value);
            case 'doesNotContain': return Array.isArray(factValue) && !factValue.includes(value);
            default: return false;
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // LOOKUP helper — rate table query
    // ─────────────────────────────────────────────────────────────────────────

    private async fetchRateFromTable(
        tenantId: string,
        tableCode: string,
        factValue: unknown,
    ): Promise<number | null> {
        // Band key lookup: finds the rate_table_entry where band_key = factValue
        const entry = await this.rateTableEntryRepo
            .createQueryBuilder('rte')
            .innerJoin('rte.rateTable', 'rt')
            .where('rt.code = :tableCode', { tableCode })
            .andWhere('rt.tenant_id = :tenantId', { tenantId })
            .andWhere('rte.band_key = :exact', { exact: String(factValue) })
            .getOne();

        return entry ? Number(entry.rate) : null;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Find matching pricing rule for a given coverage option
    // ─────────────────────────────────────────────────────────────────────────

    private findApplicableRule(
        rules: LoadedPricingRule[],
        coverageOptionId: string,
    ): LoadedPricingRule | undefined {
        // Look for a rule scoped to the specific coverage, or fall back to a wildcard rule
        return (
            rules.find((r) => r.name.includes(coverageOptionId)) ??
            rules.find((r) => r.name.toLowerCase().includes('default')) ??
            rules[0]
        );
    }
}
