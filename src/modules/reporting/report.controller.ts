import { Controller, Post, Body, Headers, BadRequestException, UseGuards, Res } from '@nestjs/common';
import { Response } from 'express';
import { ReportingService } from './reporting.service';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { JwtAuthGuard } from '../iam/guards/jwt-auth.guard';
import { RolesGuard } from '../iam/guards/roles.guard';
import { Roles } from '../iam/decorators/roles.decorator';
import { UserRole } from '../iam/entities/user.entity';

@ApiTags('reports')
@Controller('reports')
@UseGuards(JwtAuthGuard, RolesGuard)
export class ReportController {
    constructor(private readonly reportingService: ReportingService) { }

    @Post('generate')
    @Roles(UserRole.ADMIN, UserRole.UNDERWRITER)
    @ApiOperation({ summary: 'Generate a system report' })
    async generateReport(
        @Headers('x-tenant-id') tenantId: string,
        @Body() dto: { reportType: string; format?: string; fromDate?: string; toDate?: string },
        @Res() res: Response,
    ) {
        if (!tenantId) {
            throw new BadRequestException('x-tenant-id header is required');
        }

        if (dto.format) {
            const buffer = await this.reportingService.exportToFile(
                tenantId,
                dto.reportType,
                dto.format,
                dto.fromDate,
                dto.toDate,
            );

            const filename = `report_${dto.reportType.toLowerCase()}_${Date.now()}.${dto.format}`;
            res.setHeader('Content-Type', dto.format === 'xlsx' ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' : 'application/pdf');
            res.setHeader('Content-Disposition', `attachment; filename=${filename}`);
            res.send(buffer);
            return;
        }

        const data = await this.reportingService.generateSummary(
            tenantId,
            dto.reportType,
            dto.fromDate,
            dto.toDate,
        );

        res.json({
            reportId: `REP-${Date.now()}`,
            status: 'COMPLETED',
            generatedAt: new Date().toISOString(),
            data,
        });
    }
}
