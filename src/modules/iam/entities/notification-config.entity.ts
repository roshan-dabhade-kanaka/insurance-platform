import { Entity, Column, Index } from 'typeorm';
import { BaseTenantEntity } from '../../../common/entities/base-tenant.entity';

@Entity('notification_configs')
@Index(['tenantId'], { unique: true })
export class NotificationConfig extends BaseTenantEntity {
    @Column({ name: 'email_enabled', default: true })
    emailEnabled!: boolean;

    @Column({ name: 'sms_enabled', default: false })
    smsEnabled!: boolean;

    @Column({ name: 'push_enabled', default: false })
    pushEnabled!: boolean;

    @Column({ type: 'jsonb', default: {} })
    channels!: Record<string, any>; // Store detailed channel configs if needed
}
