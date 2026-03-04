import { Controller, Get, Post, Body, Headers, BadRequestException, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { JwtAuthGuard } from '../guards/jwt-auth.guard';
import { RolesGuard } from '../guards/roles.guard';
import { Roles } from '../decorators/roles.decorator';
import { UserRole } from '../entities/user.entity';
import { NotificationService } from '../services/notification.service';

@ApiTags('notifications')
@Controller('notifications')
@UseGuards(JwtAuthGuard, RolesGuard)
export class NotificationController {
    constructor(private readonly notificationService: NotificationService) { }

    @Get('config')
    @Roles(UserRole.ADMIN)
    @ApiOperation({ summary: 'Get notification configuration' })
    async getConfig(@Headers('x-tenant-id') tenantId: string) {
        if (!tenantId) throw new BadRequestException('x-tenant-id header is required');
        return this.notificationService.getConfig(tenantId);
    }

    @Post('config')
    @Roles(UserRole.ADMIN)
    @ApiOperation({ summary: 'Update notification configuration' })
    async updateConfig(
        @Headers('x-tenant-id') tenantId: string,
        @Body() body: any,
    ) {
        if (!tenantId) throw new BadRequestException('x-tenant-id header is required');
        return this.notificationService.updateConfig(tenantId, body);
    }
}
