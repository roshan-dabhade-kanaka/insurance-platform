import { Controller, Post, Body, Param, Headers, Get, BadRequestException, UseGuards } from '@nestjs/common';
import { AuditAction } from '../../audit/decorators/audit-action.decorator';
import { AuditEntityType } from '../../../common/enums';
import { FinancePayoutService } from '../services/finance-payout.service';
import { SubmitFinanceDecisionDto, DisburseDto } from '../dto/finance.dto';
import { v4 as uuidv4 } from 'uuid';
import { JwtAuthGuard } from '../../iam/guards/jwt-auth.guard';
import { RolesGuard } from '../../iam/guards/roles.guard';
import { Roles } from '../../iam/decorators/roles.decorator';
import { UserRole } from '../../iam/entities/user.entity';

@Controller('payouts')
@UseGuards(JwtAuthGuard, RolesGuard)
export class FinanceController {
    constructor(private readonly financeService: FinancePayoutService) { }

    @Get()
    @Roles(UserRole.FINANCE_OFFICER, UserRole.ADMIN)
    async getPayoutRequests(
        @Headers('x-tenant-id') tenantId: string,
    ) {
        if (!tenantId) {
            throw new BadRequestException('x-tenant-id header is required');
        }
        return this.financeService.getPendingPayouts(tenantId);
    }

    @Get('processed-today')
    @Roles(UserRole.FINANCE_OFFICER, UserRole.ADMIN)
    async getProcessedToday(
        @Headers('x-tenant-id') tenantId: string,
    ) {
        if (!tenantId) {
            throw new BadRequestException('x-tenant-id header is required');
        }
        return this.financeService.getProcessedToday(tenantId);
    }

    @Post(':claimId/approve')
    @Roles(UserRole.FINANCE_OFFICER, UserRole.ADMIN)
    @AuditAction(AuditEntityType.PAYOUT, 'APPROVE')
    async approvePayout(
        @Headers('x-tenant-id') tenantId: string,
        @Param('claimId') claimId: string,
        @Body() dto: SubmitFinanceDecisionDto,
    ) {
        if (!tenantId) {
            throw new BadRequestException('x-tenant-id header is required');
        }

        return this.financeService.submitApproval({
            ...dto,
            tenantId,
            claimId,
        });
    }

    @Post(':payoutRequestId/pay')
    @Roles(UserRole.FINANCE_OFFICER, UserRole.ADMIN)
    @AuditAction(AuditEntityType.PAYOUT, 'DISBURSE')
    async processPayment(
        @Headers('x-tenant-id') tenantId: string,
        @Param('payoutRequestId') payoutRequestId: string,
        @Body('claimId') claimId: string,
        @Body() dto: DisburseDto,
    ) {
        if (!tenantId) {
            throw new BadRequestException('x-tenant-id header is required');
        }

        // In a real API, the workflow would trigger this, but we expose an endpoint for manual/adhoc payments
        // or for re-triggering a failed disbursement.
        return this.financeService.disburse({
            ...dto,
            tenantId,
            payoutRequestId,
            claimId,
            idempotencyKey: `payout:${payoutRequestId}:${dto.installmentNumber || 1}:${uuidv4()}`,
        });
    }
}
