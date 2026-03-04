import {
    PrimaryGeneratedColumn,
    Column,
    CreateDateColumn,
    UpdateDateColumn,
    BaseEntity,
} from 'typeorm';

/**
 * Abstract base entity for all tenant-scoped tables.
 *
 * Every table that extends this gains:
 *  - UUID primary key (gen_random_uuid())
 *  - tenant_id for RLS-based isolation
 *  - created_at / updated_at auto-managed timestamps
 *
 * PostgreSQL Row-Level Security (RLS) policies reference `tenant_id`.
 * The application MUST set:
 *   SET LOCAL app.current_tenant_id = '<uuid>';
 * on every transaction/session before executing queries.
 */
export abstract class BaseTenantEntity extends BaseEntity {
    @PrimaryGeneratedColumn('uuid')
    id!: string;

    /**
     * Tenant isolation column — indexed on every table.
     * Never exposed directly in API responses; enforced at DB level via RLS.
     */
    @Column({ type: 'uuid', name: 'tenant_id', nullable: false })
    tenantId!: string;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt!: Date;

    @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
    updatedAt!: Date;
}
