import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { RiskProfile, RiskFactor } from './entities/risk-profile.entity';
import { RiskService } from './risk.service';
import { RiskController } from './risk.controller';

@Module({
    imports: [
        TypeOrmModule.forFeature([RiskProfile, RiskFactor]),
    ],
    providers: [RiskService],
    controllers: [RiskController],
    exports: [RiskService],
})
export class RiskModule { }
