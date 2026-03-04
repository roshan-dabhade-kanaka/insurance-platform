import { Controller, Get, Query, UseGuards, Req, UnauthorizedException } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { DashboardService, DashboardStats, PremiumTrendPoint } from './dashboard.service';
import { JwtAuthGuard } from '../iam/guards/jwt-auth.guard';

@ApiTags('dashboard')
@Controller('dashboard')
export class DashboardController {
    constructor(private readonly dashboardService: DashboardService) { }

    @Get('stats')
    @ApiOperation({ summary: 'Get dashboard KPIs (active policies, premiums, pending claims, UW queue)' })
    async getStats(@Query('tenantId') tenantId?: string): Promise<DashboardStats> {
        return this.dashboardService.getStats(tenantId || undefined);
    }

    @Get('stats/me')
    @UseGuards(JwtAuthGuard)
    @ApiBearerAuth()
    @ApiOperation({ summary: 'Get dashboard KPIs for current user (my policies, my claims)' })
    async getStatsMe(@Req() req: { user?: { userId: string; tenantId?: string } }, @Query('tenantId') tenantId?: string): Promise<DashboardStats> {
        const userId = req.user?.userId;
        if (!userId) throw new UnauthorizedException();
        return this.dashboardService.getStatsForUser(userId, tenantId || req.user?.tenantId);
    }

    @Get('premium-trends')
    @ApiOperation({ summary: 'Get monthly premium trends for the last 6 months' })
    async getPremiumTrends(@Query('tenantId') tenantId?: string): Promise<PremiumTrendPoint[]> {
        return this.dashboardService.getPremiumTrends(tenantId || undefined);
    }
}
