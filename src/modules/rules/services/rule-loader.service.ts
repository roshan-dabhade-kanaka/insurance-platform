// =============================================================================
// Rule Loader Service — Insurance Platform
//
// Loads rule definitions from PostgreSQL JSONB columns and caches them
// with a configurable TTL. All rules are tenant-scoped.
//
// Cache strategy:
//   - In-memory Map keyed by `{tenantId}:{productVersionId}:{ruleType}`
//   - Default TTL: 5 minutes (configurable via env RULE_CACHE_TTL_MS)
//   - Cache bust: call invalidateCache() after any rule update via admin API
//   - On cache miss: fetches from TypeORM repositories
//
// Temporal integration:
//   - Called by Temporal activities via IRuleEngineService interface
//   - Cache prevents repeated DB roundtrips within a single workflow execution
// =============================================================================

import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ConfigService } from '@nestjs/config';

import { EligibilityRule } from '../entities/rules.entity';
import { PricingRule } from '../entities/rules.entity';
import { FraudRule } from '../entities/rules.entity';
import {
    LoadedRule,
    RuleCacheEntry,
    RuleType,
    PricingRuleExpression,
    JsonRulesEngineRule,
} from '../interfaces/rule-types.interface';

// ─────────────────────────────────────────────────────────────────────────────
// Loaded Pricing Rule — enriched with the full expression JSONB
// ─────────────────────────────────────────────────────────────────────────────
export interface LoadedPricingRule {
    ruleId: string;
    tenantId: string;
    name: string;
    expression: PricingRuleExpression;
    isActive: boolean;
}

export interface LoadedFraudRule extends LoadedRule {
    scoreWeight: number;
    severity: string;
}

@Injectable()
export class RuleLoaderService {
    private readonly logger = new Logger(RuleLoaderService.name);

    /** In-memory rule cache — keyed by cache key string */
    private readonly cache = new Map<string, RuleCacheEntry>();

    private readonly defaultTtlMs: number;

    constructor(
        @InjectRepository(EligibilityRule)
        private readonly eligibilityRepo: Repository<EligibilityRule>,

        @InjectRepository(PricingRule)
        private readonly pricingRepo: Repository<PricingRule>,

        @InjectRepository(FraudRule)
        private readonly fraudRepo: Repository<FraudRule>,

        private readonly config: ConfigService,
    ) {
        this.defaultTtlMs = this.config.get<number>('RULE_CACHE_TTL_MS', 5 * 60 * 1000);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Eligibility Rules
    // ─────────────────────────────────────────────────────────────────────────

    async loadEligibilityRules(
        tenantId: string,
        productVersionId: string,
    ): Promise<LoadedRule[]> {
        const cacheKey = this.buildKey(tenantId, productVersionId, RuleType.ELIGIBILITY);
        const cached = this.get<LoadedRule[]>(cacheKey);
        if (cached) return cached;

        this.logger.debug(`Cache miss — loading eligibility rules [tenant=${tenantId}, version=${productVersionId}]`);

        const rows = await this.eligibilityRepo.find({
            where: { tenantId, productVersionId, isActive: true },
            order: { priority: 'DESC' },
        });

        const rules: LoadedRule[] = rows.map((r) => ({
            ruleId: r.id,
            tenantId: r.tenantId,
            name: r.name,
            ruleDefinition: r.ruleLogic as unknown as JsonRulesEngineRule,
            priority: r.priority,
            isActive: r.isActive,
        }));

        this.set(cacheKey, rules);
        return rules;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Pricing Rules
    // ─────────────────────────────────────────────────────────────────────────

    async loadPricingRules(
        tenantId: string,
        productVersionId: string,
    ): Promise<LoadedPricingRule[]> {
        const cacheKey = this.buildKey(tenantId, productVersionId, RuleType.PRICING);
        const cached = this.get<LoadedPricingRule[]>(cacheKey);
        if (cached) return cached;

        this.logger.debug(`Cache miss — loading pricing rules [tenant=${tenantId}, version=${productVersionId}]`);

        const today = new Date().toISOString().slice(0, 10);

        const rows = await this.pricingRepo
            .createQueryBuilder('pr')
            .where('pr.tenant_id = :tenantId', { tenantId })
            .andWhere('pr.product_version_id = :productVersionId', { productVersionId })
            .andWhere('pr.is_active = true')
            .andWhere('(pr.effective_from IS NULL OR pr.effective_from <= :today)', { today })
            .andWhere('(pr.effective_to IS NULL OR pr.effective_to >= :today)', { today })
            .orderBy('pr.created_at', 'ASC')
            .getMany();

        const rules: LoadedPricingRule[] = rows.map((r) => ({
            ruleId: r.id,
            tenantId: r.tenantId,
            name: r.name,
            expression: r.ruleExpression as unknown as PricingRuleExpression,
            isActive: r.isActive,
        }));

        this.set(cacheKey, rules);
        return rules;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Risk Rules (shared with eligibility_rules table, type differentiated by
    // event.type in the JSONB: "risk_multiplier" | "risk_score_add" | "risk_decline")
    // ─────────────────────────────────────────────────────────────────────────

    async loadRiskRules(
        tenantId: string,
        productVersionId: string,
    ): Promise<LoadedRule[]> {
        const cacheKey = this.buildKey(tenantId, productVersionId, RuleType.RISK);
        const cached = this.get<LoadedRule[]>(cacheKey);
        if (cached) return cached;

        this.logger.debug(`Cache miss — loading risk rules [tenant=${tenantId}, version=${productVersionId}]`);

        // Risk rules are tagged in rule_logic.event.type as "risk_*"
        // We use a JSONB contains query to filter them efficiently
        const rows = await this.eligibilityRepo
            .createQueryBuilder('er')
            .where('er.tenant_id = :tenantId', { tenantId })
            .andWhere('er.product_version_id = :productVersionId', { productVersionId })
            .andWhere('er.is_active = true')
            .andWhere("er.rule_logic->'event'->>'type' LIKE 'risk_%'")
            .orderBy('er.priority', 'DESC')
            .getMany();

        const rules: LoadedRule[] = rows.map((r) => ({
            ruleId: r.id,
            tenantId: r.tenantId,
            name: r.name,
            ruleDefinition: r.ruleLogic as unknown as JsonRulesEngineRule,
            priority: r.priority,
            isActive: r.isActive,
        }));

        this.set(cacheKey, rules);
        return rules;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Fraud Rules
    // ─────────────────────────────────────────────────────────────────────────

    async loadFraudRules(tenantId: string): Promise<LoadedFraudRule[]> {
        const cacheKey = this.buildKey(tenantId, '*', RuleType.FRAUD);
        const cached = this.get<LoadedFraudRule[]>(cacheKey);
        if (cached) return cached;

        this.logger.debug(`Cache miss — loading fraud rules [tenant=${tenantId}]`);

        const rows = await this.fraudRepo.find({
            where: { tenantId, isActive: true },
        });

        const rules: LoadedFraudRule[] = rows.map((r) => ({
            ruleId: r.id,
            tenantId: r.tenantId,
            name: r.name,
            ruleDefinition: r.ruleLogic as unknown as JsonRulesEngineRule,
            priority: 1,
            isActive: r.isActive,
            scoreWeight: r.scoreWeight,
            severity: r.severity,
        }));

        this.set(cacheKey, rules);
        return rules;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Cache Management
    // ─────────────────────────────────────────────────────────────────────────

    /** Invalidate all cached rules for a tenant (call after CRUD on rules) */
    invalidateTenantCache(tenantId: string): void {
        let count = 0;
        for (const key of this.cache.keys()) {
            if (key.startsWith(`${tenantId}:`)) {
                this.cache.delete(key);
                count++;
            }
        }
        this.logger.log(`Invalidated ${count} cache entries for tenant ${tenantId}`);
    }

    /** Invalidate a specific product version's rules */
    invalidateVersionCache(tenantId: string, productVersionId: string): void {
        for (const type of Object.values(RuleType)) {
            this.cache.delete(this.buildKey(tenantId, productVersionId, type));
        }
    }

    /** Clear the entire rule cache (useful in tests or on rule engine restart) */
    clearAll(): void {
        this.cache.clear();
        this.logger.log('Rule cache cleared');
    }

    getCacheStats(): { size: number; keys: string[] } {
        return { size: this.cache.size, keys: Array.from(this.cache.keys()) };
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Private helpers
    // ─────────────────────────────────────────────────────────────────────────

    private buildKey(tenantId: string, productVersionId: string, ruleType: RuleType): string {
        return `${tenantId}:${productVersionId}:${ruleType}`;
    }

    private get<T>(key: string): T | null {
        const entry = this.cache.get(key) as RuleCacheEntry<T> | undefined;
        if (!entry) return null;
        if (Date.now() - entry.cachedAt >= entry.ttlMs) {
            this.cache.delete(key);
            return null;
        }
        return entry.data;
    }

    private set<T>(key: string, data: T, ttlMs?: number): void {
        this.cache.set(key, {
            data,
            cachedAt: Date.now(),
            ttlMs: ttlMs ?? this.defaultTtlMs,
        } as RuleCacheEntry<LoadedRule[]>);
    }
}
