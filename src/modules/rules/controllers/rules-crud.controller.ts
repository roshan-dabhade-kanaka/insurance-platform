import { Controller, Post, Body, Headers, BadRequestException } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { RulesCrudService } from '../services/rules-crud.service';

@ApiTags('rules')
@Controller('rules')
export class RulesCrudController {
    constructor(private readonly rulesCrudService: RulesCrudService) { }

    @Post('eligibility')
    @ApiOperation({ summary: 'Create a new eligibility rule' })
    async createEligibilityRule(
        @Headers('x-tenant-id') tenantId: string,
        @Body() dto: any,
    ) {
        if (!tenantId) throw new BadRequestException('x-tenant-id header is required');
        return this.rulesCrudService.createEligibilityRule(tenantId, dto);
    }

    @Post('pricing')
    @ApiOperation({ summary: 'Create a new pricing rule' })
    async createPricingRule(
        @Headers('x-tenant-id') tenantId: string,
        @Body() dto: any,
    ) {
        if (!tenantId) throw new BadRequestException('x-tenant-id header is required');
        return this.rulesCrudService.createPricingRule(tenantId, dto);
    }
}
