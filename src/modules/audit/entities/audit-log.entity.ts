import { Entity, Column, Index } from 'typeorm';
import { BaseTenantEntity } from '../../../common/entities/base-tenant.entity';
import { AuditEntityType } from '../../../common/enums';

// ─────────────────────────────────────────────────────────────────────────────
// AuditLog — append-only, immutable record of ALL lifecycle transitions.
//
// Design decisions:
//  - Uses BIGINT PK (not UUID) for high-throughput sequential inserts
//  - Partitioned by occurred_at in PostgreSQL (monthly range partitions)
//    via pg_partman or migration-managed CREATE TABLE ... PARTITION OF
//  - Application-level enforcement: no UPDATE or DELETE is permitted.
//    Enforced via PostgreSQL RULE or application guard in the service layer.
//  - TypeORM synchronize:false — table is managed purely via migrations.
//
// RLS policy (applied in migration):
//   CREATE POLICY tenant_isolation ON audit_logs
//     USING (tenant_id = current_setting('app.current_tenant_id')::uuid);
// ─────────────────────────────────────────────────────────────────────────────
@Entity('audit_logs')
@Index(['tenantId', 'entityType', 'entityId'])
@Index(['tenantId', 'occurredAt'])
@Index(['tenantId', 'performedBy', 'occurredAt'])
export class AuditLog {
    /** BIGSERIAL for high-volume sequential inserts — no UUID overhead */
    @Column({ primary: true, type: 'bigint', generated: 'increment' })
    id!: string;

    @Column({ name: 'tenant_id', type: 'uuid' })
    tenantId!: string;

    @Column({ name: 'entity_type', type: 'enum', enum: AuditEntityType })
    entityType!: AuditEntityType;

    /** UUID of the business entity being audited */
    @Column({ name: 'entity_id', type: 'uuid' })
    entityId!: string;

    /** Verb: CREATED | STATE_CHANGED | UPDATED | DELETED | LOCKED | UNLOCKED */
    @Column({ type: 'varchar', length: 100 })
    action!: string;

    @Column({ name: 'previous_state', type: 'varchar', length: 100, nullable: true })
    previousState!: string | null;

    @Column({ name: 'new_state', type: 'varchar', length: 100, nullable: true })
    newState!: string | null;

    /** User or service account who triggered the change */
    @Column({ name: 'performed_by', type: 'uuid', nullable: true })
    performedBy!: string | null;

    /** Role of the user at the time of the action */
    @Column({ name: 'role', type: 'varchar', length: 100, nullable: true })
    role!: string | null;

    /** Temporal workflow/activity that triggered the change (if applicable) */
    @Column({ name: 'temporal_run_id', type: 'varchar', length: 255, nullable: true })
    temporalRunId!: string | null;

    /** Additional structured context — diff snapshots, request metadata etc. */
    @Column({ name: 'change_context', type: 'jsonb', default: {} })
    changeContext!: Record<string, unknown>;

    @Column({ name: 'ip_address', type: 'inet', nullable: true })
    ipAddress!: string | null;

    @Column({ name: 'user_agent', type: 'text', nullable: true })
    userAgent!: string | null;

    /**
     * Partition key — PostgreSQL range partitions by month.
     * Example partition: audit_logs_2024_01 FOR VALUES FROM ('2024-01-01') TO ('2024-02-01')
     */
    @Column({ name: 'occurred_at', type: 'timestamptz', default: () => 'NOW()' })
    occurredAt!: Date;
}
