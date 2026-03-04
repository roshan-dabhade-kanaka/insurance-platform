import { IsString, IsNotEmpty, IsObject, IsArray, ValidateNested, IsNumber, IsOptional, Min } from 'class-validator';
import { Type } from 'class-transformer';

export class QuoteLineItemDto {
    @IsString()
    @IsNotEmpty()
    coverageOptionId!: string;

    @IsString()
    @IsOptional()
    riderId?: string;

    @IsNumber()
    @Min(0)
    sumInsured!: number;

    @IsString()
    @IsOptional()
    deductibleId?: string;
}

export class CreateQuoteDto {
    @IsString()
    @IsNotEmpty()
    productVersionId!: string;

    @IsObject()
    @IsNotEmpty()
    applicantData!: Record<string, unknown>;

    @IsArray()
    @ValidateNested({ each: true })
    @Type(() => QuoteLineItemDto)
    lineItems!: QuoteLineItemDto[];

    @IsNumber()
    @IsOptional()
    riskThreshold?: number;

    @IsNumber()
    @IsOptional()
    @Min(1)
    quoteExpiryDays?: number;

    @IsString()
    @IsNotEmpty()
    createdBy!: string;
}

export class SubmitQuoteDto {
    @IsString()
    @IsNotEmpty()
    submittedBy!: string;
}
