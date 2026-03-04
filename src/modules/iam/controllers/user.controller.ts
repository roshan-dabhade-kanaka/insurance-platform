import { Controller, Get, Headers, BadRequestException, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { UserService } from '../services/user.service';
import { JwtAuthGuard } from '../guards/jwt-auth.guard';
import { RolesGuard } from '../guards/roles.guard';
import { Roles } from '../decorators/roles.decorator';
import { UserRole } from '../entities/user.entity';

@ApiTags('users')
@Controller('users')
@UseGuards(JwtAuthGuard, RolesGuard)
export class UserController {
    constructor(private readonly userService: UserService) { }

    @Get()
    @Roles(UserRole.ADMIN)
    @ApiOperation({ summary: 'List all users for the tenant' })
    async findAll(@Headers('x-tenant-id') tenantId: string) {
        if (!tenantId) {
            throw new BadRequestException('x-tenant-id header is required');
        }
        return this.userService.findAll(tenantId);
    }
}
