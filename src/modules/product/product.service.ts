import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { InsuranceProduct, ProductVersion, CoverageOption } from './entities/product.entity';
import { ProductVersionStatus } from '../../common/enums';

@Injectable()
export class ProductService {
    constructor(
        @InjectRepository(InsuranceProduct)
        private readonly productRepo: Repository<InsuranceProduct>,
        @InjectRepository(ProductVersion)
        private readonly versionRepo: Repository<ProductVersion>,
        @InjectRepository(CoverageOption)
        private readonly coverageRepo: Repository<CoverageOption>,
    ) { }

    async findAll(tenantId?: string): Promise<InsuranceProduct[]> {
        return this.productRepo.find({
            where: tenantId ? { tenantId } : {},
            relations: ['versions', 'versions.coverageOptions'],
        });
    }

    async findOne(id: string, tenantId?: string): Promise<InsuranceProduct | null> {
        return this.productRepo.findOne({
            where: tenantId ? { id, tenantId } : { id },
            relations: ['versions', 'versions.coverageOptions', 'versions.riders'],
        });
    }

    async create(tenantId: string, data: Partial<InsuranceProduct>): Promise<InsuranceProduct> {
        const product = this.productRepo.create({
            ...data,
            tenantId,
        });
        return this.productRepo.save(product);
    }

    async update(id: string, tenantId: string, data: Partial<Pick<InsuranceProduct, 'name' | 'description' | 'isActive'>>): Promise<InsuranceProduct> {
        const product = await this.productRepo.findOne({ where: { id, tenantId } });
        if (!product) {
            throw new NotFoundException(`Product not found: ${id}`);
        }
        if (data.name !== undefined) product.name = data.name;
        if (data.description !== undefined) product.description = data.description;
        if (data.isActive !== undefined) product.isActive = data.isActive;
        return this.productRepo.save(product);
    }

    async listVersions(productId: string, tenantId: string): Promise<ProductVersion[]> {
        return this.versionRepo.find({
            where: { productId, tenantId },
            relations: ['coverageOptions'],
            order: { versionNumber: 'ASC' },
        });
    }

    async createVersion(
        productId: string,
        tenantId: string,
        data: { effectiveFrom: string; effectiveTo?: string; changelog?: string },
    ): Promise<ProductVersion> {
        const product = await this.productRepo.findOne({ where: { id: productId, tenantId } });
        if (!product) throw new NotFoundException(`Product not found: ${productId}`);

        // Auto-increment: find the highest existing version number
        const existing = await this.versionRepo.find({
            where: { productId, tenantId },
            order: { versionNumber: 'DESC' },
            take: 1,
        });
        const nextVersionNumber = existing.length > 0 ? existing[0].versionNumber + 1 : 1;

        const version = this.versionRepo.create({
            productId,
            tenantId,
            versionNumber: nextVersionNumber,
            status: ProductVersionStatus.DRAFT,
            effectiveFrom: data.effectiveFrom,
            effectiveTo: data.effectiveTo ?? null,
            changelog: data.changelog ?? `Version ${nextVersionNumber}`,
            productSnapshot: { productName: product.name, productCode: product.code },
            quoteFields: [
                { fieldName: 'sumInsured', label: 'Sum Insured', type: 'number', required: true },
                { fieldName: 'policyTerm', label: 'Policy Term', type: 'dropdown', options: [10, 20, 30], required: true },
                { fieldName: 'dateOfBirth', label: 'Date of Birth', type: 'date', required: true }
            ]
        });
        return this.versionRepo.save(version);
    }

    async addCoverageOption(
        productId: string,
        versionId: string,
        tenantId: string,
        data: any,
    ): Promise<CoverageOption> {
        const version = await this.versionRepo.findOne({
            where: { id: versionId, productId, tenantId },
        });
        if (!version) {
            throw new NotFoundException(`Product version not found: ${versionId} for product ${productId}`);
        }

        const coverage = this.coverageRepo.create({
            name: data.name,
            code: data.code,
            isMandatory: data.is_mandatory ?? data.isMandatory ?? false,
            minSumInsured: data.min_sum_insured ?? data.minSumInsured,
            maxSumInsured: data.max_sum_insured ?? data.maxSumInsured,
            productVersionId: versionId,
            tenantId,
            parameters: data.parameters ?? {},
        });
        return this.coverageRepo.save(coverage);
    }

    async getCoverages(productId: string, tenantId?: string): Promise<any[]> {
        const version = await this.getActiveVersion(productId, tenantId);
        if (!version) return [];

        return this.coverageRepo.find({
            where: { productVersionId: version.id },
            select: ['id', 'name', 'code'],
        }).then(items => items.map(i => ({
            coverageId: i.id,
            coverageName: i.name,
            coverageCode: i.code
        })));
    }

    async getQuoteFields(productId: string, tenantId?: string): Promise<any[]> {
        const version = await this.getActiveVersion(productId, tenantId);
        return version?.quoteFields ?? [];
    }

    private async getActiveVersion(productId: string, tenantId?: string): Promise<ProductVersion | null> {
        // Try to find status=PUBLISHED (active), fallback to latest draft
        let version = await this.versionRepo.findOne({
            where: tenantId
                ? { productId, tenantId, status: ProductVersionStatus.ACTIVE }
                : { productId, status: ProductVersionStatus.ACTIVE },
            order: { versionNumber: 'DESC' }
        });

        if (!version) {
            version = await this.versionRepo.findOne({
                where: tenantId ? { productId, tenantId } : { productId },
                order: { versionNumber: 'DESC' }
            });
        }
        return version;
    }
}
