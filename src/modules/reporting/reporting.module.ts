import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ReportController } from './report.controller';
import { ReportingService } from './reporting.service';
import { IamModule } from '../iam/iam.module';
import { Quote } from '../quote/entities/quote.entity';
import { Claim } from '../claim/entities/claim.entity';
import { PayoutRequest } from '../finance/entities/finance.entity';
import { AuditLog } from '../audit/entities/audit-log.entity';
import { Policy } from '../policy/entities/policy.entity';
import { InsuranceProduct, ProductVersion } from '../product/entities/product.entity';
import { User } from '../iam/entities/user.entity';

@Module({
    imports: [
        TypeOrmModule.forFeature([
            Quote,
            Claim,
            PayoutRequest,
            AuditLog,
            Policy,
            InsuranceProduct,
            ProductVersion,
            User,
        ]),
        IamModule
    ],
    controllers: [ReportController],
    providers: [ReportingService],
})
export class ReportingModule { }
