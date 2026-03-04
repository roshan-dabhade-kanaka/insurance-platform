import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import {
    Policy,
    PolicyCoverage,
    PolicyRider,
    PolicyStatusHistory,
    PolicyEndorsement,
} from './entities/policy.entity';
import { Quote, PremiumSnapshot } from '../quote/entities/quote.entity';
import { PolicyService } from './services/policy.service';
import { PolicyController } from './controllers/policy.controller';

@Module({
    imports: [
        TypeOrmModule.forFeature([
            Policy,
            PolicyCoverage,
            PolicyRider,
            PolicyStatusHistory,
            PolicyEndorsement,
            Quote,
            PremiumSnapshot,
        ]),
    ],
    providers: [PolicyService],
    controllers: [PolicyController],
    exports: [PolicyService],
})
export class PolicyModule { }
