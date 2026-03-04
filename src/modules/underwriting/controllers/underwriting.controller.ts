import { Controller, Post, Body, Param, Headers, Get, BadRequestException, UseGuards } from '@nestjs/common';
import { AuditAction } from '../../audit/decorators/audit-action.decorator';
import { AuditEntityType } from '../../../common/enums';
import { UnderwritingService } from '../services/underwriting.service';
import { RecordDecisionDto, EscalateDto, AcquireLockDto } from '../dto/underwriting.dto';
import { JwtAuthGuard } from '../../iam/guards/jwt-auth.guard';
import { RolesGuard } from '../../iam/guards/roles.guard';
import { Roles } from '../../iam/decorators/roles.decorator';
import { UserRole } from '../../iam/entities/user.entity';

@Controller('underwriting')
@UseGuards(JwtAuthGuard, RolesGuard)
export class UnderwritingController {
    constructor(private readonly underwritingService: UnderwritingService) { }

    @Get()
    async findAll(@Headers('x-tenant-id') tenantId: string) {
        if (!tenantId) {
            throw new BadRequestException('x-tenant-id header is required');
        }
        return this.underwritingService.findAll(tenantId);
    }

    @Post(':id/lock')
    @AuditAction(AuditEntityType.UW_CASE, 'ACQUIRE_LOCK')
    async acquireLock(
        @Headers('x-tenant-id') tenantId: string,
        @Param('id') id: string,
        @Body() dto: AcquireLockDto,
    ) {
        if (!tenantId) {
            throw new BadRequestException('x-tenant-id header is required');
        }

        return this.underwritingService.acquireLock(
            tenantId,
            id,
            dto.underwriterId,
            dto.lockDurationMinutes || 30,
        );
    }

    @Post(':id/approve')
    @Roles(UserRole.UNDERWRITER, UserRole.SENIOR_UNDERWRITER, UserRole.ADMIN)
    @AuditAction(AuditEntityType.UW_CASE, 'APPROVE')
    async approveCase(
        @Headers('x-tenant-id') tenantId: string,
        @Param('id') id: string,
        @Body() dto: RecordDecisionDto,
    ) {
        if (!tenantId) {
            throw new BadRequestException('x-tenant-id header is required');
        }

        return this.underwritingService.recordDecision({
            ...dto,
            tenantId,
            uwCaseId: id,
        });
    }

    @Post(':id/reject')
    @Roles(UserRole.UNDERWRITER, UserRole.SENIOR_UNDERWRITER, UserRole.ADMIN)
    @AuditAction(AuditEntityType.UW_CASE, 'REJECT')
    async rejectCase(
        @Headers('x-tenant-id') tenantId: string,
        @Param('id') id: string,
        @Body() dto: RecordDecisionDto,
    ) {
        if (!tenantId) {
            throw new BadRequestException('x-tenant-id header is required');
        }

        return this.underwritingService.recordDecision({
            ...dto,
            tenantId,
            uwCaseId: id,
        });
    }

    @Post(':id/escalate')
    @Roles(UserRole.UNDERWRITER, UserRole.ADMIN)
    @AuditAction(AuditEntityType.UW_CASE, 'ESCALATE')
    async escalateCase(
        @Headers('x-tenant-id') tenantId: string,
        @Param('id') id: string,
        @Body() dto: EscalateDto,
    ) {
        if (!tenantId) {
            throw new BadRequestException('x-tenant-id header is required');
        }

        return this.underwritingService.escalate({
            ...dto,
            tenantId,
            uwCaseId: id,
        });
    }
}
