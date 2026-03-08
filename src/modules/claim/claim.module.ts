import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import {
    Claim,
    ClaimItem,
    ClaimDocument,
    ClaimStatusHistory,
    ClaimValidation,
    ClaimInvestigation,
    InvestigationActivity,
    FraudReview,
    FraudReviewFlag,
    ClaimAssessment,
} from './entities/claim.entity';
import { ClaimService } from './services/claim.service';
import { FraudReviewService } from './services/fraud-review.service';
import { ClaimController } from './controllers/claim.controller';
import { FraudController } from './controllers/fraud.controller';
import { RulesModule } from '../rules/rules.module';
import { TemporalModule } from '../../temporal/worker/worker';
import { FinanceModule } from '../finance/finance.module';

@Module({
    imports: [
        TypeOrmModule.forFeature([
            Claim,
            ClaimItem,
            ClaimDocument,
            ClaimStatusHistory,
            ClaimValidation,
            ClaimInvestigation,
            InvestigationActivity,
            FraudReview,
            FraudReviewFlag,
            ClaimAssessment,
        ]),
        RulesModule,
        TemporalModule,
        FinanceModule,
    ],
    providers: [ClaimService, FraudReviewService],
    controllers: [ClaimController, FraudController],
    exports: [ClaimService, FraudReviewService],
})
export class ClaimModule { }
