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
}
