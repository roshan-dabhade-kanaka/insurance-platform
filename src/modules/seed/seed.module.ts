import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { User, Role, Permission } from '../iam/entities/user.entity';
import { Tenant } from '../tenant/entities/tenant.entity';
import { SeedService } from './seed.service';
import { SeedController } from './seed.controller';

@Module({
    imports: [
        TypeOrmModule.forFeature([User, Role, Permission, Tenant]),
    ],
    providers: [SeedService],
    controllers: [SeedController],
    exports: [SeedService],
})
export class SeedModule { }
