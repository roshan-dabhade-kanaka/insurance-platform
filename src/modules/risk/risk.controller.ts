import { Controller, Post, Get, Body, Query } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { RiskService } from './risk.service';

@ApiTags('risk')
@Controller('risk')
export class RiskController {
    constructor(private readonly riskService: RiskService) { }

    @Post('assess')
    @ApiOperation({ summary: 'Submit risk assessment' })
    async assess(@Body() data: any, @Query('tenantId') tenantId: string) {
        return this.riskService.assess(tenantId, data);
    }

    @Get()
    @ApiOperation({ summary: 'Get all risk profiles' })
    async findAll(@Query('tenantId') tenantId?: string) {
        return this.riskService.findAll(tenantId);
    }
}
