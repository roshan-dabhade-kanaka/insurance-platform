import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import {
    PayoutRequest,
    PayoutApproval,
    PayoutPartialRecord,
    PayoutDisbursement,
} from './entities/finance.entity';
import { FinancePayoutService } from './services/finance-payout.service';
import { FinanceController } from './controllers/finance.controller';
import { TemporalModule } from '../../temporal/worker/worker';

@Module({
    imports: [
        TypeOrmModule.forFeature([
            PayoutRequest,
            PayoutApproval,
            PayoutPartialRecord,
            PayoutDisbursement,
        ]),
        TemporalModule,
    ],
    providers: [FinancePayoutService],
    controllers: [FinanceController],
    exports: [FinancePayoutService],
})
export class FinanceModule { }
