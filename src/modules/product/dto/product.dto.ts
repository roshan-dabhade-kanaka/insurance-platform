import { ApiProperty } from '@nestjs/swagger';
import { IsString, IsNotEmpty, IsEnum, IsOptional, IsBoolean } from 'class-validator';
import { InsuranceProductType } from '../entities/product.entity';

export class CreateProductDto {
    @ApiProperty()
    @IsString()
    @IsNotEmpty()
    name!: string;

    @ApiProperty()
    @IsString()
    @IsNotEmpty()
    code!: string;

    @ApiProperty({ enum: InsuranceProductType })
    @IsEnum(InsuranceProductType)
    type!: InsuranceProductType;

    @ApiProperty({ required: false })
    @IsString()
    @IsOptional()
    description?: string;

    @ApiProperty({ required: false, default: true })
    @IsBoolean()
    @IsOptional()
    isActive?: boolean;
}

export class UpdateProductDto {
    @ApiProperty({ required: false })
    @IsString()
    @IsOptional()
    name?: string;

    @ApiProperty({ required: false })
    @IsString()
    @IsOptional()
    description?: string;

    @ApiProperty({ required: false })
    @IsBoolean()
    @IsOptional()
    isActive?: boolean;
}

export class CreateCoverageOptionDto {
    @ApiProperty()
    @IsString()
    @IsNotEmpty()
    name!: string;

    @ApiProperty()
    @IsString()
    @IsNotEmpty()
    code!: string;

    @ApiProperty({ required: false })
    @IsBoolean()
    @IsOptional()
    isMandatory?: boolean;

    @ApiProperty({ required: false })
    @IsString()
    @IsOptional()
    minSumInsured?: string;

    @ApiProperty({ required: false })
    @IsString()
    @IsOptional()
    maxSumInsured?: string;
}
