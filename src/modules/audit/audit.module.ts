import { Module, Global } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuditLog } from './entities/audit-log.entity';
import { AuditLogService } from './services/audit-log.service';
import { AuditController } from './controllers/audit.controller';
import { APP_INTERCEPTOR } from '@nestjs/core';
import { AuditLogInterceptor } from './interceptors/audit-log.interceptor';

@Global()
@Module({
    imports: [TypeOrmModule.forFeature([AuditLog])],
    providers: [
        AuditLogService,
        {
            provide: APP_INTERCEPTOR,
            useClass: AuditLogInterceptor,
        },
    ],
    controllers: [AuditController],
    exports: [AuditLogService],
})
export class AuditModule { }
