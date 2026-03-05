import {
    Entity,
    Column,
    ManyToOne,
    OneToMany,
    ManyToMany,
    JoinTable,
    JoinColumn,
    Index,
} from 'typeorm';
import { BaseTenantEntity } from '../../../common/entities/base-tenant.entity';
import { ProductVersionStatus } from '../../../common/enums';

// ─────────────────────────────────────────────────────────────────────────────
// Insurance Product — master product catalog entry (Term Life, Health, Auto…)
// ─────────────────────────────────────────────────────────────────────────────
export enum InsuranceProductType {
    LIFE = 'LIFE',
    HEALTH = 'HEALTH',
    AUTO = 'AUTO',
    HOME = 'HOME',
    TRAVEL = 'TRAVEL',
    LIABILITY = 'LIABILITY',
    COMMERCIAL = 'COMMERCIAL',
}

@Entity('insurance_products')
@Index(['tenantId', 'code'], { unique: true })
@Index(['tenantId', 'isActive'])
export class InsuranceProduct extends BaseTenantEntity {
    @Column({ length: 200 })
    name!: string;

    /** Short unique code per tenant e.g. "TERM-LIFE-10Y" */
    @Column({ length: 80 })
    code!: string;

    @Column({ type: 'enum', enum: InsuranceProductType })
    type!: InsuranceProductType;

    @Column({ type: 'text', nullable: true })
    description!: string;

    @Column({ name: 'is_active', default: true })
    isActive!: boolean;

    @OneToMany(() => ProductVersion, (v) => v.product)
    versions!: ProductVersion[];
}

// ─────────────────────────────────────────────────────────────────────────────
// ProductVersion — immutable versioned snapshot of a product configuration.
// Once a Policy is issued against a version it is frozen (status→DEPRECATED).
// ─────────────────────────────────────────────────────────────────────────────
@Entity('product_versions')
@Index(['tenantId', 'productId', 'versionNumber'], { unique: true })
@Index(['tenantId', 'status'])
export class ProductVersion extends BaseTenantEntity {
    @Column({ name: 'product_id', type: 'uuid' })
    productId!: string;

    @ManyToOne(() => InsuranceProduct, (p) => p.versions, { onDelete: 'RESTRICT' })
    @JoinColumn({ name: 'product_id' })
    product!: InsuranceProduct;

    @Column({ name: 'version_number', type: 'int', default: 1 })
    versionNumber!: number;

    @Column({ type: 'enum', enum: ProductVersionStatus, default: ProductVersionStatus.DRAFT })
    status!: ProductVersionStatus;

    @Column({ name: 'effective_from', type: 'date' })
    effectiveFrom!: string;

    @Column({ name: 'effective_to', type: 'date', nullable: true })
    effectiveTo!: string | null;

    /** Changelog or release notes for this version */
    @Column({ type: 'text', nullable: true })
    changelog!: string;

    /** Copy-on-write: full product config snapshot stored for historical accuracy */
    @Column({ name: 'product_snapshot', type: 'jsonb', default: {} })
    productSnapshot!: Record<string, unknown>;

    /** Dynamic fields required to generate a quote for this product version */
    @Column({ name: 'quote_fields', type: 'jsonb', default: [] })
    quoteFields!: Array<Record<string, any>>;

    @OneToMany(() => CoverageOption, (c) => c.productVersion)
    coverageOptions!: CoverageOption[];

    @ManyToMany(() => Rider, (r) => r.productVersions, { eager: false })
    @JoinTable({
        name: 'product_version_riders',
        joinColumn: { name: 'product_version_id', referencedColumnName: 'id' },
        inverseJoinColumn: { name: 'rider_id', referencedColumnName: 'id' },
    })
    riders!: Rider[];
}

// ─────────────────────────────────────────────────────────────────────────────
// CoverageOption — a named coverage within a product version
// e.g. "Accidental Death", "Critical Illness", "Hospitalization"
// ─────────────────────────────────────────────────────────────────────────────
@Entity('coverage_options')
@Index(['tenantId', 'productVersionId'])
export class CoverageOption extends BaseTenantEntity {
    @Column({ name: 'product_version_id', type: 'uuid' })
    productVersionId!: string;

    @ManyToOne(() => ProductVersion, (v) => v.coverageOptions, { onDelete: 'RESTRICT' })
    @JoinColumn({ name: 'product_version_id' })
    productVersion!: ProductVersion;

    @Column({ length: 200 })
    name!: string;

    @Column({ length: 100 })
    code!: string;

    @Column({ name: 'is_mandatory', default: false })
    isMandatory!: boolean;

    @Column({ name: 'min_sum_insured', type: 'numeric', precision: 14, scale: 2, nullable: true })
    minSumInsured!: string;

    @Column({ name: 'max_sum_insured', type: 'numeric', precision: 14, scale: 2, nullable: true })
    maxSumInsured!: string;

    /** Additional coverage parameters (waiting period, sublimits, etc.) */
    @Column({ type: 'jsonb', default: {} })
    parameters!: Record<string, unknown>;

    @OneToMany(() => Deductible, (d) => d.coverageOption)
    deductibles!: Deductible[];
}

// ─────────────────────────────────────────────────────────────────────────────
// Rider — optional add-on attached to one or more product versions
// ─────────────────────────────────────────────────────────────────────────────
@Entity('riders')
@Index(['tenantId', 'code'], { unique: true })
export class Rider extends BaseTenantEntity {
    @Column({ length: 200 })
    name!: string;

    @Column({ length: 100 })
    code!: string;

    @Column({ type: 'text', nullable: true })
    description!: string;

    /** Pricing surcharge details, benefit schedule */
    @Column({ type: 'jsonb', default: {} })
    parameters!: Record<string, unknown>;

    @Column({ name: 'is_active', default: true })
    isActive!: boolean;

    @ManyToMany(() => ProductVersion, (v) => v.riders)
    productVersions!: ProductVersion[];
}

// ─────────────────────────────────────────────────────────────────────────────
// Deductible — deductible tiers for a coverage option
// ─────────────────────────────────────────────────────────────────────────────
@Entity('deductibles')
@Index(['tenantId', 'coverageOptionId'])
export class Deductible extends BaseTenantEntity {
    @Column({ name: 'coverage_option_id', type: 'uuid' })
    coverageOptionId!: string;

    @ManyToOne(() => CoverageOption, (c) => c.deductibles, { onDelete: 'CASCADE' })
    @JoinColumn({ name: 'coverage_option_id' })
    coverageOption!: CoverageOption;

    @Column({ length: 150 })
    label!: string;

    /** Flat amount deductible */
    @Column({ name: 'flat_amount', type: 'numeric', precision: 14, scale: 2, nullable: true })
    flatAmount!: string | null;

    /** Percentage-based deductible (0-100) */
    @Column({ type: 'numeric', precision: 5, scale: 2, nullable: true })
    percentage!: string | null;

    @Column({ name: 'is_default', default: false })
    isDefault!: boolean;
}
