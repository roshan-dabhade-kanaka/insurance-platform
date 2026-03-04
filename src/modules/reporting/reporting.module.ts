import { Module } from '@nestjs/common';
import { ReportController } from './report.controller';
import { IamModule } from '../iam/iam.module';

@Module({
    imports: [IamModule],
    controllers: [ReportController],
})
export class ReportingModule { }
