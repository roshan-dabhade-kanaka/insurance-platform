import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { EligibilityRule, PricingRule } from '../entities/rules.entity';
import { RuleLoaderService } from './rule-loader.service';

@Injectable()
export class RulesCrudService {
    constructor(
        @InjectRepository(EligibilityRule)
        private readonly eligibilityRepo: Repository<EligibilityRule>,
        @InjectRepository(PricingRule)
        private readonly pricingRepo: Repository<PricingRule>,
        private readonly ruleLoader: RuleLoaderService,
    ) { }

    async createEligibilityRule(tenantId: string, data: any): Promise<EligibilityRule> {
        const rule = this.eligibilityRepo.create({
            name: data.name,
            productVersionId: data.productVersionId ?? data.product_version_id,
            ruleLogic: data.ruleLogic ?? data.rule_logic,
            priority: data.priority ?? 0,
            isActive: data.isActive ?? data.is_active ?? true,
            tenantId,
        });
        const saved = await this.eligibilityRepo.save(rule);
        const result = Array.isArray(saved) ? saved[0] : saved;

        this.ruleLoader.invalidateTenantCache(tenantId);
        return result as EligibilityRule;
    }

    async createPricingRule(tenantId: string, data: any): Promise<PricingRule> {
        const rule = this.pricingRepo.create({
            name: data.name,
            productVersionId: data.productVersionId ?? data.product_version_id,
            ruleExpression: data.ruleExpression ?? data.rule_expression,
            isActive: data.isActive ?? data.is_active ?? true,
            tenantId,
        });
        const saved = await this.pricingRepo.save(rule);
        const result = Array.isArray(saved) ? saved[0] : saved;

        this.ruleLoader.invalidateTenantCache(tenantId);
        return result as PricingRule;
    }
}
