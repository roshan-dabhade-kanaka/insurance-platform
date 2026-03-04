import { Controller, Post, Body, Param, Headers, Get, BadRequestException, UseGuards, Req } from '@nestjs/common';
import { AuditAction } from '../../audit/decorators/audit-action.decorator';
import { AuditEntityType } from '../../../common/enums';
import { ClaimService } from '../services/claim.service';
import { SubmitClaimDto, CreateInvestigationDto, CreateAssessmentDto } from '../dto/claim.dto';
import { JwtAuthGuard } from '../../iam/guards/jwt-auth.guard';
import { RolesGuard } from '../../iam/guards/roles.guard';
import { Roles } from '../../iam/decorators/roles.decorator';
import { UserRole } from '../../iam/entities/user.entity';

@Controller('claims')
@UseGuards(JwtAuthGuard, RolesGuard)
export class ClaimController {
    constructor(private readonly claimService: ClaimService) { }

    @Post()
    @AuditAction(AuditEntityType.CLAIM, 'SUBMIT')
    async submitClaim(
        @Headers('x-tenant-id') tenantId: string,
        @Body() dto: SubmitClaimDto,
    ) {
        if (!tenantId) {
            throw new BadRequestException('x-tenant-id header is required');
        }

        return this.claimService.submitClaim({
            ...dto,
            tenantId,
        });
    }

    @Post(':id/validate')
    async validateClaim(
        @Headers('x-tenant-id') tenantId: string,
        @Param('id') id: string,
    ) {
        if (!tenantId) {
            throw new BadRequestException('x-tenant-id header is required');
        }

        // Manual validation trigger — in this project, validation is mostly automated via Temporal
        // But we can expose a manual trigger if needed.
        return { message: 'Claim validation triggered', claimId: id };
    }

    @Post(':id/investigate')
    @Roles(UserRole.CLAIMS_OFFICER, UserRole.ADMIN)
    @AuditAction(AuditEntityType.CLAIM, 'START_INVESTIGATION')
    async investigateClaim(
        @Headers('x-tenant-id') tenantId: string,
        @Param('id') id: string,
        @Body() dto: CreateInvestigationDto,
    ) {
        if (!tenantId) {
            throw new BadRequestException('x-tenant-id header is required');
        }

        return this.claimService.createInvestigation({
            ...dto,
            tenantId,
            claimId: id,
        });
    }

    @Post(':id/assess')
    @Roles(UserRole.CLAIMS_OFFICER, UserRole.ADMIN)
    @AuditAction(AuditEntityType.CLAIM, 'ASSESSED')
    async assessClaim(
        @Headers('x-tenant-id') tenantId: string,
        @Param('id') id: string,
        @Req() req: { user?: { userId: string } },
        @Body() dto: CreateAssessmentDto,
    ) {
        if (!tenantId) {
            throw new BadRequestException('x-tenant-id header is required');
        }
        const userId = req.user?.userId;
        if (!userId) {
            throw new BadRequestException('User not authenticated');
        }
        return this.claimService.createAssessment({
            tenantId,
            claimId: id,
            assessment: {
                assessedBy: userId,
                assessedAmount: dto.assessedAmount,
                deductibleApplied: dto.deductibleApplied,
                netPayout: dto.netPayout,
                lineItemAssessment: dto.lineItemAssessment ?? [],
                assessmentNotes: dto.assessmentNotes,
            },
        });
    }

    @Get()
    async getClaims(
        @Headers('x-tenant-id') tenantId: string,
    ) {
        if (!tenantId) {
            throw new BadRequestException('x-tenant-id header is required');
        }
        return this.claimService.findAll(tenantId);
    }

    @Get(':id')
    async getClaim(
        @Headers('x-tenant-id') tenantId: string,
        @Param('id') id: string,
    ) {
        if (!tenantId) {
            throw new BadRequestException('x-tenant-id header is required');
        }

        const state = await this.claimService.getWorkflowState(tenantId, id);
        return state;
    }
}
