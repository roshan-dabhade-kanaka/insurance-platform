// =============================================================================
// Audit Log Service — Insurance Platform
//
// Append-only audit trail for all lifecycle transitions across every domain.
// Uses the partitioned `audit_logs` table (BIGSERIAL PK, monthly partitions).
//
// Key guarantees:
//   - No UPDATE/DELETE ever called on audit_logs (enforced by PostgreSQL rule)
//   - Every call includes tenantId, entityType, entityId, action, and context
//   - Temporal runId stored when called from within a Temporal activity
//   - IP / userId captured from async local storage (set by NestJS interceptor)
//
// Domain events logged here:
//   Quote:       CREATED, STATE_CHANGED, PREMIUM_CALCULATED, EXPIRED
//   Underwriting: CASE_OPENED, DECISION_RECORDED, LOCK_ACQUIRED, ESCALATED
//   Policy:      ISSUED, ACTIVATED, LAPSED, CANCELLED, REINSTATED, ENDORSED
//   Claim:       SUBMITTED, STATE_CHANGED, ASSESSED, REOPENED, WITHDRAWN
//   Finance:     PAYOUT_APPROVED, DISBURSED, PARTIALLY_DISBURSED
// =============================================================================

import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AuditLog } from '../entities/audit-log.entity';

export interface AuditLogParams {
    tenantId: string;
    entityType: string;      // QUOTE | UW_CASE | POLICY | CLAIM | PAYOUT
    entityId: string;
    action: string;          // CREATED | STATE_CHANGED | DECISION_RECORDED | etc.
    previousState?: string;
    newState?: string;
    performedBy?: string;    // userId
    role?: string;           // user role
    context?: Record<string, unknown>;
    temporalRunId?: string;
    ipAddress?: string;
}

@Injectable()
export class AuditLogService {
    private readonly logger = new Logger(AuditLogService.name);

    constructor(
        @InjectRepository(AuditLog)
        private readonly auditRepo: Repository<AuditLog>,
    ) { }

    /**
     * Append an audit entry. Non-blocking — errors are caught and logged, not thrown.
     * Audit failures must never block domain business logic.
     */
    async log(params: AuditLogParams): Promise<void> {
        try {
            const entry = this.auditRepo.create({
                tenantId: params.tenantId,
                entityType: params.entityType as any,
                entityId: params.entityId,
                action: params.action,
                previousState: params.previousState,
                newState: params.newState,
                performedBy: params.performedBy,
                role: params.role,
                changeContext: params.context ?? {},
                temporalRunId: params.temporalRunId,
                ipAddress: params.ipAddress,
                occurredAt: new Date(),
            });

            await this.auditRepo.save(entry);
        } catch (err) {
            // Log the error but never throw — audit failures must not break business flow
            this.logger.error(
                `Audit log write failed [entity=${params.entityType}:${params.entityId}, action=${params.action}]`,
                err,
            );
        }
    }

    /**
     * Retrieve audit trail for a specific entity (e.g. a quote or claim).
     * Paginated — returns up to `limit` entries ordered by occurredAt DESC.
     */
    async getEntityHistory(
        tenantId: string,
        entityType: string,
        entityId: string,
        limit = 50,
        offset = 0,
    ): Promise<AuditLog[]> {
        return this.auditRepo.find({
            where: { tenantId, entityType: entityType as any, entityId },
            order: { occurredAt: 'DESC' },
            take: limit,
            skip: offset,
        });
    }

    /**
     * Retrieve all audit entries with pagination and filtering.
     */
    async findAll(
        tenantId: string,
        params: {
            entityType?: string;
            performedBy?: string;
            fromDate?: Date;
            toDate?: Date;
            page?: number;
            size?: number;
        }
    ): Promise<{ content: AuditLog[]; total: number }> {
        const { entityType, performedBy, fromDate, toDate, page = 0, size = 20 } = params;

        const query = this.auditRepo.createQueryBuilder('log')
            .where('log.tenantId = :tenantId', { tenantId });

        if (entityType) {
            query.andWhere('log.entityType = :entityType', { entityType });
        }

        if (performedBy) {
            const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
            if (uuidRegex.test(performedBy)) {
                query.andWhere('log.performedBy = :performedBy', { performedBy });
            } else {
                // If invalid UUID but searched, return 0 results instead of 500
                return { content: [], total: 0 };
            }
        }

        if (fromDate) {
            query.andWhere('log.occurredAt >= :fromDate', { fromDate });
        }

        if (toDate) {
            query.andWhere('log.occurredAt <= :toDate', { toDate });
        }

        const [content, total] = await query
            .orderBy('log.occurredAt', 'DESC')
            .skip(page * size)
            .take(size)
            .getManyAndCount();

        return { content, total };
    }
}
