import {
    Entity,
    Column,
    PrimaryGeneratedColumn,
    CreateDateColumn,
    UpdateDateColumn,
    OneToMany,
    ManyToOne,
    JoinColumn,
    Index,
} from 'typeorm';

// ─────────────────────────────────────────────────────────────────────────────
// Tenant
// ─────────────────────────────────────────────────────────────────────────────
@Entity('tenants')
@Index(['slug'], { unique: true })
export class Tenant {
    @PrimaryGeneratedColumn('uuid')
    id!: string;

    @Column({ length: 200 })
    name!: string;

    /** URL-safe unique identifier, e.g. "acme-insurance" */
    @Column({ length: 100, unique: true })
    slug!: string;

    /** Feature flags, branding config, contact info */
    @Column({ type: 'jsonb', default: {} })
    config!: Record<string, unknown>;

    @Column({ default: true })
    isActive!: boolean;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt!: Date;

    @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
    updatedAt!: Date;

    @OneToMany(() => TenantPlan, (p) => p.tenant)
    plans!: TenantPlan[];
}

// ─────────────────────────────────────────────────────────────────────────────
// TenantPlan — subscription / licensing tier per tenant
// ─────────────────────────────────────────────────────────────────────────────
export enum TenantPlanTier {
    STARTER = 'STARTER',
    PROFESSIONAL = 'PROFESSIONAL',
    ENTERPRISE = 'ENTERPRISE',
}

@Entity('tenant_plans')
@Index(['tenant', 'isActive'])
export class TenantPlan {
    @PrimaryGeneratedColumn('uuid')
    id!: string;

    @ManyToOne(() => Tenant, (t) => t.plans, { onDelete: 'CASCADE' })
    @JoinColumn({ name: 'tenant_id' })
    tenant!: Tenant;

    /** Convenience accessor for the FK (relation owns the column) */
    get tenantId(): string {
        return typeof this.tenant === 'object' && this.tenant?.id ? this.tenant.id : (this as any)._tenantId ?? '';
    }
    set tenantId(value: string) {
        (this as any)._tenantId = value;
    }

    @Column({ type: 'enum', enum: TenantPlanTier, default: TenantPlanTier.STARTER })
    tier!: TenantPlanTier;

    @Column({ name: 'max_users', type: 'int', default: 10 })
    maxUsers!: number;

    @Column({ name: 'max_products', type: 'int', default: 5 })
    maxProducts!: number;

    /** Enabled feature gates */
    @Column({ type: 'jsonb', default: {} })
    features!: Record<string, boolean>;

    @Column({ name: 'effective_from', type: 'date' })
    effectiveFrom!: string;

    @Column({ name: 'effective_to', type: 'date', nullable: true })
    effectiveTo!: string | null;

    @Column({ name: 'is_active', default: true })
    isActive!: boolean;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt!: Date;

    @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
    updatedAt!: Date;
}

