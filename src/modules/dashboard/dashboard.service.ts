import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In, Not } from 'typeorm';
import { Policy } from '../policy/entities/policy.entity';
import { Claim } from '../claim/entities/claim.entity';
import { UnderwritingCase } from '../underwriting/entities/underwriting.entity';
import { PolicyStatus, ClaimStatus, UnderwritingStatus } from '../../common/enums';

export interface DashboardStats {
    activePolicies: number;
    totalPremiums: number;
    pendingClaims: number;
    uwQueue: number;
}

export interface PremiumTrendPoint {
    label: string;
    amount: number;
}

const CLOSED_CLAIM_STATUSES = [
    ClaimStatus.PAID,
    ClaimStatus.REJECTED,
    ClaimStatus.CLOSED,
    ClaimStatus.WITHDRAWN,
];

@Injectable()
export class DashboardService {
    constructor(
        @InjectRepository(Policy)
        private readonly policyRepo: Repository<Policy>,
        @InjectRepository(Claim)
        private readonly claimRepo: Repository<Claim>,
        @InjectRepository(UnderwritingCase)
        private readonly uwCaseRepo: Repository<UnderwritingCase>,
    ) { }

    /**
     * Get dashboard stats scoped to a single user (e.g. Customer: my policies, my claims).
     * Policies: policy_holder_ref = userId; Claims: submitted_by = userId. UW queue = 0.
     */
    async getStatsForUser(userId: string, tenantId?: string): Promise<DashboardStats> {
        const basePolicyWhere = tenantId ? { tenantId, status: PolicyStatus.IN_FORCE } : { status: PolicyStatus.IN_FORCE };
        const [activePolicies, totalPremiumsRaw, pendingClaims] = await Promise.all([
            this.policyRepo.count({ where: { ...basePolicyWhere, policyHolderRef: userId } }),
            this.policyRepo
                .createQueryBuilder('p')
                .select('COALESCE(SUM(CAST(p.annual_premium AS DECIMAL)), 0)', 'sum')
                .where('p.status = :status', { status: PolicyStatus.IN_FORCE })
                .andWhere('p.policy_holder_ref = :userId', { userId })
                .andWhere(tenantId ? 'p.tenant_id = :tenantId' : '1=1', tenantId ? { tenantId } : {})
                .getRawOne()
                .then((r) => Number(r?.sum ?? 0)),
            this.claimRepo.count({
                where: {
                    ...(tenantId ? { tenantId } : {}),
                    submittedBy: userId,
                    status: Not(In(CLOSED_CLAIM_STATUSES)),
                },
            }),
        ]);
        return {
            activePolicies,
            totalPremiums: Math.round(totalPremiumsRaw * 100) / 100,
            pendingClaims,
            uwQueue: 0,
        };
    }

    /** Get dashboard stats. Optional tenantId for multi-tenant; if omitted, aggregates all. */
    async getStats(tenantId?: string): Promise<DashboardStats> {
        const baseWhere = tenantId ? { tenantId } : {};

        const [activePolicies, totalPremiumsRaw, pendingClaims, uwQueue] = await Promise.all([
            this.policyRepo.count({ where: { ...baseWhere, status: PolicyStatus.IN_FORCE } }),
            this.policyRepo
                .createQueryBuilder('p')
                .select('COALESCE(SUM(CAST(p.annual_premium AS DECIMAL)), 0)', 'sum')
                .where('p.status = :status', { status: PolicyStatus.IN_FORCE })
                .andWhere(tenantId ? 'p.tenant_id = :tenantId' : '1=1', tenantId ? { tenantId } : {})
                .getRawOne()
                .then((r) => Number(r?.sum ?? 0)),
            this.claimRepo.count({
                where: { ...baseWhere, status: Not(In(CLOSED_CLAIM_STATUSES)) },
            }),
            this.uwCaseRepo.count({
                where: { ...baseWhere, status: In([UnderwritingStatus.PENDING, UnderwritingStatus.IN_REVIEW]) },
            }),
        ]);

        return {
            activePolicies,
            totalPremiums: Math.round(totalPremiumsRaw * 100) / 100,
            pendingClaims,
            uwQueue,
        };
    }

    /** Get monthly premium trends for the last 6 months. */
    async getPremiumTrends(tenantId?: string): Promise<PremiumTrendPoint[]> {
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        const now = new Date();
        const results: PremiumTrendPoint[] = [];

        for (let i = 5; i >= 0; i--) {
            const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
            const label = months[d.getMonth()];

            // Start of month
            const startOfMonth = new Date(d.getFullYear(), d.getMonth(), 1);
            // End of month
            const endOfMonth = new Date(d.getFullYear(), d.getMonth() + 1, 0, 23, 59, 59);

            const sum = await this.policyRepo
                .createQueryBuilder('p')
                .select('COALESCE(SUM(CAST(p.annual_premium AS DECIMAL)), 0)', 'sum')
                .where('p.status = :status', { status: PolicyStatus.IN_FORCE })
                .andWhere(tenantId ? 'p.tenant_id = :tenantId' : '1=1', tenantId ? { tenantId } : {})
                .andWhere('p.inception_date >= :start AND p.inception_date <= :end', {
                    start: startOfMonth.toISOString().split('T')[0],
                    end: endOfMonth.toISOString().split('T')[0]
                })
                .getRawOne()
                .then((r) => Number(r?.sum ?? 0));

            results.push({ label, amount: Math.round(sum * 100) / 100 });
        }

        return results;
    }
}
