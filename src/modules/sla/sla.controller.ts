import { Controller, Get, Headers, BadRequestException, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../iam/guards/jwt-auth.guard';
import { RolesGuard } from '../iam/guards/roles.guard';
import { Roles } from '../iam/decorators/roles.decorator';
import { UserRole } from '../iam/entities/user.entity';
import { SlaService } from './services/sla.service';

@Controller('sla')
@UseGuards(JwtAuthGuard, RolesGuard)
export class SlaController {
    constructor(private readonly slaService: SlaService) { }

    @Get('stats')
    @Roles(UserRole.UNDERWRITER, UserRole.ADMIN)
    async getSlaStats(@Headers('x-tenant-id') tenantId: string) {
        if (!tenantId) {
            throw new BadRequestException('x-tenant-id header is required');
        }

        return this.slaService.getStats(tenantId);
    }
}
