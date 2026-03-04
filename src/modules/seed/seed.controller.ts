import { Controller, Post, HttpCode, HttpStatus, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth } from '@nestjs/swagger';
import { SeedService } from './seed.service';
import { Public } from '../iam/decorators/public.decorator';

@ApiTags('internal')
@Controller('internal/seed')
export class SeedController {
    constructor(private readonly seedService: SeedService) { }

    @Public()
    @Post()
    @HttpCode(HttpStatus.OK)
    @ApiOperation({ summary: 'Manually trigger database seeding (Roles and Users)' })
    @ApiResponse({ status: 200, description: 'Seeding completed successfully' })
    async seed() {
        await (this.seedService as any).seedRoles();
        await (this.seedService as any).seedUsers();
        return { message: 'Seeding completed' };
    }
}
