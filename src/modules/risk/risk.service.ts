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
        let score = 750; // Base score out of 1000
        let loading = 0; // Base premium adjustment

        // 1. Age Factor
        const age = Number(data.age) || 30;
        if (age < 25) { score -= 50; loading += 15; }
        else if (age > 60) { score -= 80; loading += 25; }

        // 2. Health Factor
        if (data.smoker === true || data.smoker === 'true') { score -= 150; loading += 20; }
        if (data.existingConditions === true || data.existingConditions === 'true') { score -= 100; loading += 15; }

        // 3. Vehicle Details
        if (data.vehicleHistory === 'Major Accidents') { score -= 200; loading += 40; }
        else if (data.vehicleHistory === 'Minor Accidents') { score -= 50; loading += 10; }

        // 4. Previous Claims
        const claims = Number(data.previousClaims) || 0;
        if (claims === 0) { score += 50; loading -= 5; } // No claim discount
        else if (claims > 3) { score -= 150; loading += 30; }
        else { score -= (claims * 30); loading += (claims * 10); }

        // 5. Determine Risk Category (Band)
        let band = RiskBand.STANDARD;
        if (score >= 800) { band = RiskBand.PREFERRED; loading -= 10; }
        else if (score < 400) { band = RiskBand.SUBSTANDARD; loading += 50; }
        else if (score < 200) { band = RiskBand.DECLINED; loading = 0; }

        // Ensure minimum loading isn't totally absurd (floor at -20% max discount)
        if (loading < -20) loading = -20;

        const profile = this.riskProfileRepo.create({
            tenantId,
            applicantRef: data.fullName || 'Anonymous Profile',
            profileData: data,
            totalScore: String(score),
            riskBand: band,
            loadingPercentage: loading.toFixed(2),
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
