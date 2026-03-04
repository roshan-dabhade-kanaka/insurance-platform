import { Controller, Get, Post, Patch, Body, Query, Param, Headers, BadRequestException } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { ProductService } from './product.service';
import { InsuranceProduct } from './entities/product.entity';
import { CreateProductDto, UpdateProductDto, CreateCoverageOptionDto } from './dto/product.dto';

@ApiTags('products')
@Controller('products')
export class ProductController {
    constructor(private readonly productService: ProductService) { }

    @Get()
    @ApiOperation({ summary: 'Get all insurance products' })
    async findAll(@Query('tenantId') tenantId?: string): Promise<InsuranceProduct[]> {
        return this.productService.findAll(tenantId);
    }

    @Get(':id')
    @ApiOperation({ summary: 'Get product details by ID' })
    async findOne(@Param('id') id: string, @Query('tenantId') tenantId?: string): Promise<InsuranceProduct | null> {
        return this.productService.findOne(id, tenantId);
    }

    @Post()
    @ApiOperation({ summary: 'Create a new insurance product' })
    async create(
        @Headers('x-tenant-id') tenantId: string,
        @Body() dto: CreateProductDto,
    ): Promise<InsuranceProduct> {
        if (!tenantId) {
            throw new BadRequestException('x-tenant-id header is required');
        }
        return this.productService.create(tenantId, dto);
    }

    @Patch(':id')
    @ApiOperation({ summary: 'Update product (e.g. isActive for disable for future)' })
    async update(
        @Param('id') id: string,
        @Headers('x-tenant-id') tenantId: string,
        @Body() dto: UpdateProductDto,
    ): Promise<InsuranceProduct> {
        if (!tenantId) {
            throw new BadRequestException('x-tenant-id header is required');
        }
        return this.productService.update(id, tenantId, dto);
    }

    @Get(':id/versions')
    @ApiOperation({ summary: 'List all versions of a product' })
    async listVersions(
        @Param('id') id: string,
        @Headers('x-tenant-id') tenantId?: string,
        @Query('tenantId') tenantIdQuery?: string,
    ) {
        const tid = tenantId ?? tenantIdQuery ?? '';
        return this.productService.listVersions(id, tid);
    }

    @Post(':id/versions')
    @ApiOperation({ summary: 'Create a new version of a product (auto-increments version number, starts as DRAFT)' })
    async createVersion(
        @Param('id') id: string,
        @Headers('x-tenant-id') tenantId: string,
        @Body() dto: { effectiveFrom: string; effectiveTo?: string; changelog?: string },
    ) {
        if (!tenantId) throw new BadRequestException('x-tenant-id header is required');
        return this.productService.createVersion(id, tenantId, dto);
    }

    @Post(':id/versions/:vId/coverages')
    @ApiOperation({ summary: 'Add a coverage option to a product version' })
    async addCoverageOption(
        @Param('id') id: string,
        @Param('vId') vId: string,
        @Headers('x-tenant-id') tenantId: string,
        @Body() dto: CreateCoverageOptionDto,
    ) {
        if (!tenantId) throw new BadRequestException('x-tenant-id header is required');
        return this.productService.addCoverageOption(id, vId, tenantId, dto);
    }
}
