import { Controller, Post, Body, Get, Param, Headers, BadRequestException, UseGuards } from '@nestjs/common';
import { AuditAction } from '../../audit/decorators/audit-action.decorator';
import { AuditEntityType } from '../../../common/enums';
import { QuoteService } from '../services/quote.service';
import { CreateQuoteDto } from '../dto/quote.dto';
import { JwtAuthGuard } from '../../iam/guards/jwt-auth.guard';
import { RolesGuard } from '../../iam/guards/roles.guard';
import { Roles } from '../../iam/decorators/roles.decorator';
import { UserRole } from '../../iam/entities/user.entity';

@Controller('quotes')
@UseGuards(JwtAuthGuard, RolesGuard)
export class QuoteController {
    constructor(private readonly quoteService: QuoteService) { }

    @Get()
    async findAll(@Headers('x-tenant-id') tenantId: string) {
        if (!tenantId) {
            throw new BadRequestException('x-tenant-id header is required');
        }
        return this.quoteService.findAll(tenantId);
    }

    @Post()
    @Roles(UserRole.AGENT, UserRole.ADMIN)
    @AuditAction(AuditEntityType.QUOTE, 'CREATE')
    async createQuote(
        @Headers('x-tenant-id') tenantId: string,
        @Body() dto: CreateQuoteDto,
    ) {
        if (!tenantId) {
            throw new BadRequestException('x-tenant-id header is required');
        }

        return this.quoteService.createQuote({
            ...dto,
            tenantId,
        });
    }

    @Get(':id')
    async getQuote(
        @Headers('x-tenant-id') tenantId: string,
        @Param('id') id: string,
    ) {
        if (!tenantId) {
            throw new BadRequestException('x-tenant-id header is required');
        }

        const quote = await this.quoteService.findById(tenantId, id);

        // Only attempt live Temporal query if the workflow is actually running
        let liveWorkflowState: unknown = null;
        if (quote.temporalWorkflowId) {
            try {
                liveWorkflowState = await this.quoteService.getWorkflowState(tenantId, id);
            } catch {
                // Temporal may be unavailable; return DB state gracefully
                liveWorkflowState = null;
            }
        }

        return { ...quote, liveWorkflowState };
    }

    /** Submit a DRAFT quote for underwriting review */
    @Post(':id/submit')
    @AuditAction(AuditEntityType.QUOTE, 'SUBMIT')
    async submitQuote(
        @Headers('x-tenant-id') tenantId: string,
        @Param('id') id: string,
        @Body('submittedBy') submittedBy: string,
    ) {
        if (!tenantId) {
            throw new BadRequestException('x-tenant-id header is required');
        }
        return this.quoteService.submitQuote(tenantId, id, submittedBy ?? 'admin');
    }

    /** Manual underwriting decision: approve or reject a submitted quote */
    @Post(':id/decision')
    @Roles(UserRole.UNDERWRITER, UserRole.SENIOR_UNDERWRITER, UserRole.ADMIN)
    @AuditAction(AuditEntityType.QUOTE, 'DECISION')
    async recordDecision(
        @Headers('x-tenant-id') tenantId: string,
        @Param('id') id: string,
        @Body('status') status: string,
        @Body('decidedBy') decidedBy: string,
    ) {
        if (!tenantId) {
            throw new BadRequestException('x-tenant-id header is required');
        }
        const allowed = ['APPROVED', 'REJECTED'];
        if (!allowed.includes(status?.toUpperCase())) {
            throw new BadRequestException(`Decision must be APPROVED or REJECTED`);
        }
        return this.quoteService.updateStatus({
            tenantId,
            quoteId: id,
            status: status.toUpperCase(),
            changedBy: decidedBy ?? 'admin',
            reason: `Manual underwriting decision: ${status}`,
        });
    }

    @Post(':id/cancel')
    @AuditAction(AuditEntityType.QUOTE, 'CANCEL')
    async cancelQuote(
        @Headers('x-tenant-id') tenantId: string,
        @Param('id') id: string,
        @Body('cancelledBy') cancelledBy: string,
        @Body('reason') reason: string,
    ) {
        if (!tenantId) {
            throw new BadRequestException('x-tenant-id header is required');
        }

        return this.quoteService.cancelQuote({
            tenantId,
            quoteId: id,
            cancelledBy,
            reason,
        });
    }
}
