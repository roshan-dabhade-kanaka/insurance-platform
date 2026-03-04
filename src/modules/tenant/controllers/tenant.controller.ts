import { Controller, Get, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { TenantService } from '../services/tenant.service';
import { JwtAuthGuard } from '../../iam/guards/jwt-auth.guard';
import { RolesGuard } from '../../iam/guards/roles.guard';
import { Roles } from '../../iam/decorators/roles.decorator';
import { UserRole } from '../../iam/entities/user.entity';

@ApiTags('tenants')
@Controller('tenants')
@UseGuards(JwtAuthGuard, RolesGuard)
export class TenantController {
    constructor(private readonly tenantService: TenantService) { }

    @Get()
    @Roles(UserRole.ADMIN)
    @ApiOperation({ summary: 'List all tenants (System Admin level)' })
    async findAll() {
        return this.tenantService.findAll();
    }
}
