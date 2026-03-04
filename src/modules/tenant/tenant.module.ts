import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Tenant, TenantPlan } from './entities/tenant.entity';
import { TenantService } from './services/tenant.service';
import { TenantController } from './controllers/tenant.controller';
import { IamModule } from '../iam/iam.module';

@Module({
    imports: [
        TypeOrmModule.forFeature([Tenant, TenantPlan]),
        // TenantController uses Iam guards
    ],
    providers: [TenantService],
    controllers: [TenantController],
    exports: [TenantService],
})
export class TenantModule { }
