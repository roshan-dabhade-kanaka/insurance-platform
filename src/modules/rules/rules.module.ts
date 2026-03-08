// =============================================================================
// Rules Module — Insurance Platform
//
// Registers all rule evaluation services and exposes them for:
//   - Direct injection in NestJS services (QuoteService, ClaimService, etc.)
//   - Temporal worker activity factories (via RuleEngineService)
//
// Exported:
//   RuleEngineService   — composite adapter (Temporal-compatible)
//   RuleLoaderService   — direct cache management from admin API
//   EligibilityRuleService, PricingRuleService, RiskScoreService, FraudRuleService
// =============================================================================

import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ConfigModule } from '@nestjs/config';

// ── Entities ─────────────────────────────────────────────────────────────────
import { EligibilityRule } from './entities/rules.entity';
import { PricingRule } from './entities/rules.entity';
import { FraudRule } from './entities/rules.entity';
import { RateTable } from './entities/rules.entity';
import { RateTableEntry } from './entities/rules.entity';
import { PremiumSnapshot, Quote } from '../quote/entities/quote.entity';
import { ProductVersion } from '../product/entities/product.entity';
import { RiskProfile } from '../risk/entities/risk-profile.entity';

// ── Services ─────────────────────────────────────────────────────────────────
import { RuleLoaderService } from './services/rule-loader.service';
import { RuleEvaluationService } from './services/rule-evaluation.service';
import { EligibilityRuleService } from './services/eligibility-rule.service';
import { PricingRuleService } from './services/pricing-rule.service';
import { RiskScoreService } from './services/risk-score.service';
import { FraudRuleService } from './services/fraud-rule.service';
import { RuleEngineService } from './services/rule-engine.service';
import { RulesCrudService } from './services/rules-crud.service';

// ── Cache Admin Controller (optional — expose for admin endpoints) ─────────────
import { RulesController } from './controllers/rules.controller';
import { RulesCrudController } from './controllers/rules-crud.controller';

const RULE_SERVICES = [
    RuleLoaderService,
    RuleEvaluationService,
    EligibilityRuleService,
    PricingRuleService,
    RiskScoreService,
    FraudRuleService,
    RuleEngineService,
    RulesCrudService,
];

@Module({
    imports: [
        ConfigModule,
        TypeOrmModule.forFeature([
            EligibilityRule,
            PricingRule,
            FraudRule,
            RateTable,
            RateTableEntry,
            PremiumSnapshot,
            Quote,
            ProductVersion,
            RiskProfile,
        ]),
    ],
    providers: [...RULE_SERVICES],
    controllers: [RulesController, RulesCrudController],
    exports: [...RULE_SERVICES],
})
export class RulesModule { }
