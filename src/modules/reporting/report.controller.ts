import { Controller, Post, Body, Headers, BadRequestException, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { JwtAuthGuard } from '../iam/guards/jwt-auth.guard';
import { RolesGuard } from '../iam/guards/roles.guard';
import { Roles } from '../iam/decorators/roles.decorator';
import { UserRole } from '../iam/entities/user.entity';

@ApiTags('reports')
@Controller('reports')
@UseGuards(JwtAuthGuard, RolesGuard)
export class ReportController {
    @Post('generate')
    @Roles(UserRole.ADMIN, UserRole.UNDERWRITER)
    @ApiOperation({ summary: 'Generate a system report' })
    async generateReport(
        @Headers('x-tenant-id') tenantId: string,
        @Body() dto: { type: string; format?: string; filters?: any },
    ) {
        if (!tenantId) {
            throw new BadRequestException('x-tenant-id header is required');
        }
        // Placeholder implementation
        return {
            reportId: `REP-${Date.now()}`,
            status: 'GENERATING',
            estimatedCompletion: new Date(Date.now() + 30000).toISOString(),
            type: dto.type,
        };
    }
}
