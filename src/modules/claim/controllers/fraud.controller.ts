import { Controller, Post, Param, Body, Headers, Get, BadRequestException, UseGuards } from '@nestjs/common';
import { AuditAction } from '../../audit/decorators/audit-action.decorator';
import { AuditEntityType } from '../../../common/enums';
import { FraudReviewService } from '../services/fraud-review.service';
import { SubmitFraudDecisionDto } from '../dto/fraud.dto';
import { JwtAuthGuard } from '../../iam/guards/jwt-auth.guard';
import { RolesGuard } from '../../iam/guards/roles.guard';
import { Roles } from '../../iam/decorators/roles.decorator';
import { UserRole } from '../../iam/entities/user.entity';

@Controller('fraud')
@UseGuards(JwtAuthGuard, RolesGuard)
export class FraudController {
    constructor(private readonly fraudService: FraudReviewService) { }

    @Get()
    @Roles(UserRole.FRAUD_ANALYST, UserRole.ADMIN)
    async getFraudReviews(
        @Headers('x-tenant-id') tenantId: string,
    ) {
        if (!tenantId) {
            throw new BadRequestException('x-tenant-id header is required');
        }
        return this.fraudService.getPendingReviews(tenantId);
    }

    @Post(':claimId/review')
    @Roles(UserRole.FRAUD_ANALYST, UserRole.ADMIN)
    @AuditAction(AuditEntityType.CLAIM, 'FRAUD_REVIEW')
    async submitFraudReview(
        @Headers('x-tenant-id') tenantId: string,
        @Param('claimId') claimId: string,
        @Body() dto: SubmitFraudDecisionDto,
    ) {
        if (!tenantId) {
            throw new BadRequestException('x-tenant-id header is required');
        }

        return this.fraudService.submitDecision({
            ...dto,
            tenantId,
            claimId,
        });
    }
}
