import { Controller, Get, Query, Headers, BadRequestException, UseGuards } from '@nestjs/common';
import { AuditLogService } from '../services/audit-log.service';
import { JwtAuthGuard } from '../../iam/guards/jwt-auth.guard';
import { RolesGuard } from '../../iam/guards/roles.guard';
import { Roles } from '../../iam/decorators/roles.decorator';
import { UserRole } from '../../iam/entities/user.entity';

@Controller('audit')
@UseGuards(JwtAuthGuard, RolesGuard)
export class AuditController {
    constructor(private readonly auditService: AuditLogService) { }

    @Get('logs')
    @Roles(UserRole.COMPLIANCE_OFFICER, UserRole.ADMIN)
    async getLogs(
        @Headers('x-tenant-id') tenantId: string,
        @Query('page') page?: number,
        @Query('size') size?: number,
        @Query('entityType') entityType?: string,
        @Query('changedBy') changedBy?: string, // Mapping changedBy to performedBy
        @Query('from') from?: string,
        @Query('to') to?: string,
    ) {
        if (!tenantId) {
            throw new BadRequestException('x-tenant-id header is required');
        }

        return this.auditService.findAll(tenantId, {
            page: page ? Number(page) : 0,
            size: size ? Number(size) : 20,
            entityType,
            performedBy: changedBy,
            fromDate: from ? new Date(from) : undefined,
            toDate: to ? new Date(to) : undefined,
        });
    }

    @Get()
    @Roles(UserRole.COMPLIANCE_OFFICER, UserRole.ADMIN)
    async getAuditTrail(
        @Headers('x-tenant-id') tenantId: string,
        @Query('entityType') entityType?: string,
        @Query('entityId') entityId?: string,
    ) {
        if (!tenantId) {
            throw new BadRequestException('x-tenant-id header is required');
        }

        if (entityId && entityType) {
            return this.auditService.getEntityHistory(tenantId, entityType, entityId);
        }

        return { message: 'Use /logs for general audit trail or specify entityId/entityType for history' };
    }

    @Get(':id')
    @Roles(UserRole.COMPLIANCE_OFFICER, UserRole.ADMIN)
    async getLogDetail(
        @Headers('x-tenant-id') tenantId: string,
        @Query('id') id: string,
    ) {
        if (!tenantId) {
            throw new BadRequestException('x-tenant-id header is required');
        }
        // return this.auditService.findById(tenantId, id);
        return { message: 'Audit log detail endpoint' };
    }
}
