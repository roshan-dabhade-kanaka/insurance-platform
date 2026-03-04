import { Entity, Column, ManyToOne, JoinColumn, Index } from 'typeorm';
import { BaseTenantEntity } from '../../../common/entities/base-tenant.entity';
import { RiskBand } from '../../../common/enums';

// ─────────────────────────────────────────────────────────────────────────────
// RiskProfile — underwriter / actuarial risk assessment per applicant/quote
// ─────────────────────────────────────────────────────────────────────────────
@Entity('risk_profiles')
@Index(['tenantId', 'applicantRef'])
@Index(['tenantId', 'quoteId'])
export class RiskProfile extends BaseTenantEntity {
    /** External applicant identifier (from the quoting system or CRM) */
    @Column({ name: 'applicant_ref', length: 200 })
    applicantRef!: string;

    @Column({ name: 'quote_id', type: 'uuid', nullable: true })
    quoteId!: string | null;

    /**
     * All raw risk input data captured at assessment time.
     * Examples: { bmi: 24.5, smoker: false, occupation: "OFFICE", driving_record: "CLEAN" }
     */
    @Column({ name: 'profile_data', type: 'jsonb' })
    profileData!: Record<string, unknown>;

    /** Aggregate risk score (0–1000) */
    @Column({ name: 'total_score', type: 'numeric', precision: 7, scale: 2, nullable: true })
    totalScore!: string | null;

    @Column({ name: 'risk_band', type: 'enum', enum: RiskBand, nullable: true })
    riskBand!: RiskBand | null;

    /** Loading percentage applied to premium (positive = surcharge, negative = discount) */
    @Column({ name: 'loading_percentage', type: 'numeric', precision: 6, scale: 2, default: 0 })
    loadingPercentage!: string;

    @Column({ name: 'underwriter_notes', type: 'text', nullable: true })
    underwriterNotes!: string | null;

    @Column({ name: 'assessed_at', type: 'timestamptz', nullable: true })
    assessedAt!: Date | null;

    @Column({ name: 'assessed_by', type: 'uuid', nullable: true })
    assessedBy!: string | null;
}

// ─────────────────────────────────────────────────────────────────────────────
// RiskFactor — individual scored risk factor contributing to RiskProfile
// ─────────────────────────────────────────────────────────────────────────────
@Entity('risk_factors')
@Index(['tenantId', 'riskProfileId'])
export class RiskFactor extends BaseTenantEntity {
    @Column({ name: 'risk_profile_id', type: 'uuid' })
    riskProfileId!: string;

    @ManyToOne(() => RiskProfile, { onDelete: 'CASCADE' })
    @JoinColumn({ name: 'risk_profile_id' })
    riskProfile!: RiskProfile;

    /** Factor name, e.g. "BMI", "SMOKING_STATUS", "OCCUPATION_CLASS" */
    @Column({ name: 'factor_name', length: 150 })
    factorName!: string;

    /** Raw value captured */
    @Column({ name: 'factor_value', type: 'text' })
    factorValue!: string;

    /** Score contribution of this factor */
    @Column({ type: 'numeric', precision: 7, scale: 2 })
    score!: string;

    /** Description of why this score was applied */
    @Column({ type: 'text', nullable: true })
    rationale!: string | null;
}
