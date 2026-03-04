import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { RiskProfile, RiskFactor } from './entities/risk-profile.entity';
import { RiskBand } from '../../common/enums';

@Injectable()
export class RiskService {
    constructor(
        @InjectRepository(RiskProfile)
        private readonly riskProfileRepo: Repository<RiskProfile>,
        @InjectRepository(RiskFactor)
        private readonly riskFactorRepo: Repository<RiskFactor>,
    ) { }

    async assess(tenantId: string, data: any): Promise<RiskProfile> {
        // Basic mock assessment logic for the admin UI to have something to call
        const profile = this.riskProfileRepo.create({
            tenantId,
            applicantRef: data.fullName || 'anonymous',
            profileData: data,
            totalScore: '450',
            riskBand: RiskBand.STANDARD,
            loadingPercentage: '10.00',
            assessedAt: new Date(),
        });

        return this.riskProfileRepo.save(profile);
    }

    async findAll(tenantId?: string): Promise<RiskProfile[]> {
        return this.riskProfileRepo.find({
            where: tenantId ? { tenantId } : {},
            order: { createdAt: 'DESC' },
        });
    }
}
