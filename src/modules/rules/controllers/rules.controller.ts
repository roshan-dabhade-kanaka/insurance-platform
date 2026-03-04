import { Controller, Get, Post, Body, Query, Header, Headers as NestHeaders } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { EligibilityRuleService } from '../services/eligibility-rule.service';
import { PricingRuleService, PremiumCalculationInput, PremiumCalculationOutput } from '../services/pricing-rule.service';
import { RuleLoaderService } from '../services/rule-loader.service';

@ApiTags('rules')
@Controller('rules')
export class RulesController {
    constructor(
        private readonly eligibilityService: EligibilityRuleService,
        private readonly pricingService: PricingRuleService,
        private readonly ruleLoader: RuleLoaderService,
    ) { }

    @Get()
    @ApiOperation({ summary: 'Get all rules (eligibility and pricing)' })
    @Header('Cache-Control', 'no-store')
    async findAll(
        @Query('productVersionId') productVersionId: string,
        @NestHeaders('x-tenant-id') tenantIdFromHeader: string,
        @Query('tenantId') tenantIdFromQuery?: string,
    ) {
        const tenantId = tenantIdFromQuery || tenantIdFromHeader;
        const [eligibility, pricing] = await Promise.all([
            this.ruleLoader.loadEligibilityRules(tenantId, productVersionId),
            this.ruleLoader.loadPricingRules(tenantId, productVersionId),
        ]);
        return { eligibility, pricing };
    }

    @Post('calculate-premium')
    @ApiOperation({ summary: 'Test premium calculation breakdown' })
    async calculatePremium(@Body() input: PremiumCalculationInput): Promise<PremiumCalculationOutput> {
        return this.pricingService.calculate(input);
    }
}
