import { Controller, Post, Param, Body, Headers, Get, BadRequestException, UseGuards } from '@nestjs/common';
import { AuditAction } from '../../audit/decorators/audit-action.decorator';
import { AuditEntityType } from '../../../common/enums';
import { PolicyService } from '../services/policy.service';
import { IssuePolicyDto } from '../dto/policy.dto';
import { JwtAuthGuard } from '../../iam/guards/jwt-auth.guard';
import { RolesGuard } from '../../iam/guards/roles.guard';
import { Roles } from '../../iam/decorators/roles.decorator';
import { UserRole } from '../../iam/entities/user.entity';

@Controller('policies')
@UseGuards(JwtAuthGuard, RolesGuard)
export class PolicyController {
    constructor(private readonly policyService: PolicyService) { }

    @Get()
    async findAll(@Headers('x-tenant-id') tenantId: string) {
        if (!tenantId) {
            throw new BadRequestException('x-tenant-id header is required');
        }
        return this.policyService.findAll(tenantId);
    }

    @Post(':quoteId/issue')
    @Roles(UserRole.UNDERWRITER, UserRole.AGENT, UserRole.ADMIN)
    @AuditAction(AuditEntityType.POLICY, 'ISSUE')
    async issuePolicy(
        @Headers('x-tenant-id') tenantId: string,
        @Param('quoteId') quoteId: string,
        @Body() dto: IssuePolicyDto,
    ) {
        if (!tenantId) {
            throw new BadRequestException('x-tenant-id header is required');
        }

        return this.policyService.issue({
            ...dto,
            tenantId,
            quoteId,
        });
    }
}
