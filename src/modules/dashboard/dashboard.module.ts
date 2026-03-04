import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Policy } from '../policy/entities/policy.entity';
import { Claim } from '../claim/entities/claim.entity';
import { UnderwritingCase } from '../underwriting/entities/underwriting.entity';
import { DashboardService } from './dashboard.service';
import { DashboardController } from './dashboard.controller';

@Module({
    imports: [
        TypeOrmModule.forFeature([Policy, Claim, UnderwritingCase]),
    ],
    controllers: [DashboardController],
    providers: [DashboardService],
    exports: [DashboardService],
})
export class DashboardModule { }
