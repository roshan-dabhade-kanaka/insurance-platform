import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { EventEmitterModule } from '@nestjs/event-emitter';

// Core modules
import { RulesModule } from './modules/rules/rules.module';
import { AuditModule } from './modules/audit/audit.module';
import { IamModule } from './modules/iam/iam.module';

// Feature modules
import { QuoteModule } from '@/modules/quote/quote.module';
import { UnderwritingModule } from '@/modules/underwriting/underwriting.module';
import { PolicyModule } from '@/modules/policy/policy.module';
import { ClaimModule } from '@/modules/claim/claim.module';
import { FinanceModule } from '@/modules/finance/finance.module';
import { SeedModule } from '@/modules/seed/seed.module';
import { DashboardModule } from '@/modules/dashboard/dashboard.module';
import { ProductModule } from '@/modules/product/product.module';
import { RiskModule } from '@/modules/risk/risk.module';
import { TenantModule } from './modules/tenant/tenant.module';
import { ReportingModule } from './modules/reporting/reporting.module';
import { SlaModule } from './modules/sla/sla.module';

@Module({
    imports: [
        ConfigModule.forRoot({
            envFilePath: '.env',
            isGlobal: true,
        }),
        TypeOrmModule.forRoot({
            type: 'postgres',
            host: process.env.DB_HOST || 'localhost',
            port: parseInt(process.env.DB_PORT || '5432', 10),
            username: process.env.DB_USERNAME || 'postgres',
            password: process.env.DB_PASSWORD || 'postgres',
            database: process.env.DB_NAME || 'insurance_db',
            entities: [__dirname + '/**/*.entity{.ts,.js}'],
            // synchronize: true = TypeORM creates/updates tables on every app start (dev only; use migrations in prod)
            synchronize: process.env.TYPEORM_SYNCHRONIZE !== 'false',
            // logging: true = every SQL query is printed in the terminal (disable with TYPEORM_LOGGING=false)
            logging: process.env.TYPEORM_LOGGING !== 'false' && process.env.NODE_ENV !== 'production',
        }),
        EventEmitterModule.forRoot(),
        RulesModule,
        AuditModule,
        IamModule,
        QuoteModule,
        UnderwritingModule,
        PolicyModule,
        ClaimModule,
        FinanceModule,
        SeedModule,
        DashboardModule,
        ProductModule,
        RiskModule,
        TenantModule,
        ReportingModule,
        SlaModule,
    ],
})
export class AppModule { }
