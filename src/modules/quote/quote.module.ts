import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Quote, QuoteLineItem, QuoteStatusHistory, PremiumSnapshot } from './entities/quote.entity';
import { InsuranceProduct, ProductVersion, CoverageOption } from '../product/entities/product.entity';
import { QuoteService } from './services/quote.service';
import { QuoteController } from './controllers/quote.controller';
import { RulesModule } from '../rules/rules.module';
import { TemporalModule } from '../../temporal/worker/worker';

@Module({
    imports: [
        TypeOrmModule.forFeature([
            Quote,
            QuoteLineItem,
            QuoteStatusHistory,
            PremiumSnapshot,
            InsuranceProduct,
            ProductVersion,
            CoverageOption,
        ]),
        RulesModule,
        TemporalModule,
    ],
    providers: [QuoteService],
    controllers: [QuoteController],
    exports: [QuoteService],
})
export class QuoteModule { }
