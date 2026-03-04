import {
    Injectable,
    NestInterceptor,
    ExecutionContext,
    CallHandler,
    Logger,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Observable } from 'rxjs';
import { tap } from 'rxjs/operators';
import { AuditLogService } from '../services/audit-log.service';
import { AUDIT_ACTION_KEY, AuditActionMetadata } from '../decorators/audit-action.decorator';

@Injectable()
export class AuditLogInterceptor implements NestInterceptor {
    private readonly logger = new Logger(AuditLogInterceptor.name);

    constructor(
        private readonly reflector: Reflector,
        private readonly auditService: AuditLogService,
    ) { }

    intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
        const metadata = this.reflector.getAllAndOverride<AuditActionMetadata>(
            AUDIT_ACTION_KEY,
            [context.getHandler(), context.getClass()],
        );

        if (!metadata) {
            return next.handle();
        }

        const request = context.switchToHttp().getRequest();
        const { user, params, query, body, headers } = request;

        return next.handle().pipe(
            tap({
                next: async (data: any) => {
                    // Extract entityId from common param names
                    const entityId = params.id || params.quoteId || params.claimId || params.payoutRequestId || (data && data.id);
                    const tenantId = headers['x-tenant-id'] || (user && user.tenantId);

                    if (tenantId && entityId) {
                        await this.auditService.log({
                            tenantId,
                            entityType: metadata.entityType,
                            entityId,
                            action: metadata.action,
                            performedBy: user?.userId,
                            role: user?.roles?.[0],
                            context: {
                                params,
                                query,
                                remoteIp: request.ip,
                                userAgent: headers['user-agent'],
                            },
                        });
                    }
                },
                error: async (err: any) => {
                    // We might still want to log failed attempts with a special action
                    this.logger.warn(`Failed action audit: ${metadata.action} on ${metadata.entityType}`, err.message);
                }
            }),
        );
    }
}
