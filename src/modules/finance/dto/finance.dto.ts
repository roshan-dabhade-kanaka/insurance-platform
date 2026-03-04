import { IsString, IsNotEmpty, IsEnum, IsNumber, IsOptional, IsArray, ValidateNested, IsDateString } from 'class-validator';
import { Type } from 'class-transformer';
import { FinanceDecision } from '../../../temporal/shared/types';

export class PayoutInstallmentDto {
    @IsNumber()
    installmentNumber!: number;

    @IsNumber()
    amount!: number;

    @IsDateString()
    scheduledDate!: string;
}

export class SubmitFinanceDecisionDto {
    @IsString()
    @IsNotEmpty()
    approverId!: string;

    @IsEnum(FinanceDecision)
    decision!: FinanceDecision;

    @IsNumber()
    @IsOptional()
    approvedAmount?: number;

    @IsArray()
    @IsOptional()
    @ValidateNested({ each: true })
    @Type(() => PayoutInstallmentDto)
    partialInstallments?: PayoutInstallmentDto[];

    @IsString()
    @IsOptional()
    notes?: string;
}

export class DisburseDto {
    @IsNumber()
    @IsNotEmpty()
    amount!: number;

    @IsString()
    @IsNotEmpty()
    payeeDetails!: Record<string, unknown>;

    @IsNumber()
    @IsOptional()
    installmentNumber?: number;
}
