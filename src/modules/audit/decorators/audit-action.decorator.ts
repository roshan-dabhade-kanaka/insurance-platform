import { SetMetadata } from '@nestjs/common';
import { AuditEntityType } from '../../../common/enums';

export const AUDIT_ACTION_KEY = 'audit_action';

export interface AuditActionMetadata {
    entityType: AuditEntityType;
    action: string;
}

/**
 * Decorator to mark a controller or method for automatic audit logging.
 * The AuditLogInterceptor will pick this up.
 */
export const AuditAction = (entityType: AuditEntityType, action: string) =>
    SetMetadata(AUDIT_ACTION_KEY, { entityType, action });
