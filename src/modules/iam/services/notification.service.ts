import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { NotificationConfig } from '../entities/notification-config.entity';

@Injectable()
export class NotificationService {
    constructor(
        @InjectRepository(NotificationConfig)
        private readonly configRepo: Repository<NotificationConfig>,
    ) { }

    async getConfig(tenantId: string): Promise<NotificationConfig> {
        let config = await this.configRepo.findOne({ where: { tenantId } });
        if (!config) {
            config = this.configRepo.create({ tenantId });
            await this.configRepo.save(config);
        }
        return config;
    }

    async updateConfig(tenantId: string, data: Partial<NotificationConfig>): Promise<NotificationConfig> {
        const config = await this.getConfig(tenantId);
        Object.assign(config, data);
        return this.configRepo.save(config);
    }
}
