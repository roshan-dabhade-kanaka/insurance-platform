import { Entity, Column, Index } from 'typeorm';
import { BaseTenantEntity } from '../../../common/entities/base-tenant.entity';
import { WorkflowType } from '../../../common/enums';

// ─────────────────────────────────────────────────────────────────────────────
// WorkflowConfiguration
//
// JSONB-driven workflow definitions consumed by Temporal workflow implementations.
// NestJS services load the active config for a product+workflow_type and pass
// it to the Temporal workflow as input parameters.
//
// Example config structure (Underwriting):
// {
//   "steps": [
//     { "id": "eligibility_check", "activity": "CheckEligibilityActivity", "retries": 3 },
//     { "id": "risk_assessment",   "activity": "AssessRiskActivity",       "retries": 2 },
//     { "id": "uw_review",         "activity": "UnderwriterReviewActivity", "humanTask": true }
//   ],
//   "slaHours": 48,
//   "escalationRoleId": "<uuid>",
//   "notifications": { "onAssign": true, "onSlaBreached": true }
// }
// ─────────────────────────────────────────────────────────────────────────────
@Entity('workflow_configurations')
@Index(['tenantId', 'workflowType', 'isActive'])
@Index(['tenantId', 'productVersionId', 'workflowType'])
@Index('idx_workflow_config_gin', { synchronize: false }) // GIN on config column
export class WorkflowConfiguration extends BaseTenantEntity {
    @Column({ name: 'workflow_type', type: 'enum', enum: WorkflowType })
    workflowType!: WorkflowType;

    @Column({ name: 'product_version_id', type: 'uuid', nullable: true })
    productVersionId!: string | null;

    @Column({ length: 200 })
    name!: string;

    /**
     * json-rules-engine + Temporal compatible workflow definition.
     * Consumed by NestJS WorkflowConfigService to hydrate Temporal workflows.
     */
    @Column({ type: 'jsonb' })
    config!: Record<string, unknown>;

    /** Monotonically increasing; previous versions retained for audit */
    @Column({ name: 'version_number', type: 'int', default: 1 })
    versionNumber!: number;

    @Column({ name: 'is_active', default: true })
    isActive!: boolean;

    @Column({ name: 'activated_at', type: 'timestamptz', nullable: true })
    activatedAt!: Date | null;

    @Column({ name: 'activated_by', type: 'uuid', nullable: true })
    activatedBy!: string | null;
}
