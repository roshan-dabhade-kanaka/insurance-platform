import {
    Entity,
    Column,
    ManyToMany,
    JoinTable,
    ManyToOne,
    JoinColumn,
    Index,
    OneToMany,
} from 'typeorm';
import { BaseTenantEntity } from '../../../common/entities/base-tenant.entity';

// ─────────────────────────────────────────────────────────────────────────────
// Permission — fine-grained action gate (e.g. "policy:issue", "claim:approve")
// ─────────────────────────────────────────────────────────────────────────────
@Entity('permissions')
@Index(['tenantId', 'resource', 'action'], { unique: true })
export class Permission extends BaseTenantEntity {
    /** Domain resource, e.g. "POLICY", "CLAIM", "QUOTE" */
    @Column({ type: 'varchar', length: 100 })
    resource!: string;

    /** Action, e.g. "CREATE", "APPROVE", "REJECT", "VIEW" */
    @Column({ type: 'varchar', length: 100 })
    action!: string;

    @Column({ type: 'varchar', length: 300, nullable: true })
    description!: string;

    @ManyToMany(() => Role, (r) => r.permissions)
    roles!: Role[];
}

// ─────────────────────────────────────────────────────────────────────────────
// Role — named set of permissions, scoped per tenant
// ─────────────────────────────────────────────────────────────────────────────
@Entity('roles')
@Index(['tenantId', 'name'], { unique: true })
export class Role extends BaseTenantEntity {
    @Column({ type: 'varchar', length: 100 })
    name!: string;

    @Column({ type: 'varchar', length: 300, nullable: true })
    description!: string;

    /** System roles cannot be deleted by tenant admins */
    @Column({ name: 'is_system_role', default: false })
    isSystemRole!: boolean;

    @ManyToMany(() => Permission, (p) => p.roles, { eager: false })
    @JoinTable({
        name: 'role_permissions',
        joinColumn: { name: 'role_id', referencedColumnName: 'id' },
        inverseJoinColumn: { name: 'permission_id', referencedColumnName: 'id' },
    })
    permissions!: Permission[];

    @ManyToMany(() => User, (u) => u.roles)
    users!: User[];
}

// ─────────────────────────────────────────────────────────────────────────────
// User — platform user scoped to a tenant
// ─────────────────────────────────────────────────────────────────────────────
export enum UserStatus {
    ACTIVE = 'ACTIVE',
    INACTIVE = 'INACTIVE',
    SUSPENDED = 'SUSPENDED',
    PENDING_VERIFICATION = 'PENDING_VERIFICATION',
}

export enum UserRole {
    CUSTOMER = 'Customer',
    AGENT = 'Agent',
    UNDERWRITER = 'Underwriter',
    SENIOR_UNDERWRITER = 'SeniorUnderwriter',
    CLAIMS_OFFICER = 'ClaimsOfficer',
    FRAUD_ANALYST = 'FraudAnalyst',
    FINANCE_OFFICER = 'FinanceOfficer',
    COMPLIANCE_OFFICER = 'ComplianceOfficer',
    ADMIN = 'Admin',
}

@Entity('users')
@Index(['tenantId', 'email'], { unique: true })
@Index(['tenantId', 'status'])
export class User extends BaseTenantEntity {
    @Column({ type: 'varchar', length: 150 })
    email!: string;

    @Column({ name: 'first_name', type: 'varchar', length: 100 })
    firstName!: string;

    @Column({ name: 'last_name', type: 'varchar', length: 100 })
    lastName!: string;

    /** Hashed password — nullable for SSO-only users */
    @Column({ name: 'password_hash', type: 'varchar', length: 255, nullable: true, select: false })
    passwordHash!: string | null;

    @Column({ type: 'enum', enum: UserStatus, default: UserStatus.PENDING_VERIFICATION })
    status!: UserStatus;

    /** Temporal Worker identity for workflow task routing */
    @Column({ name: 'temporal_worker_id', type: 'varchar', length: 255, nullable: true })
    temporalWorkerId!: string | null;

    /** User preferences, notification settings */
    @Column({ type: 'jsonb', default: {} })
    metadata!: Record<string, unknown>;

    @Column({ name: 'last_login_at', type: 'timestamptz', nullable: true })
    lastLoginAt!: Date | null;

    @ManyToMany(() => Role, (r) => r.users, { eager: false })
    @JoinTable({
        name: 'user_roles',
        joinColumn: { name: 'user_id', referencedColumnName: 'id' },
        inverseJoinColumn: { name: 'role_id', referencedColumnName: 'id' },
    })
    roles!: Role[];
}
