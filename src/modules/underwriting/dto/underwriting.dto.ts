import { IsString, IsNotEmpty, IsEnum, IsNumber, IsOptional, IsArray, ValidateNested, IsUUID } from 'class-validator';
import { Type } from 'class-transformer';
import { UwDecision } from '../../../temporal/shared/types';

export class UnderwritingConditionDto {
    @IsString()
    @IsNotEmpty()
    code!: string;

    @IsString()
    @IsNotEmpty()
    description!: string;

    @IsNotEmpty()
    mandatory!: boolean;
}

export class RecordDecisionDto {
    @IsString()
    @IsNotEmpty()
    decidedBy!: string;

    @IsEnum(UwDecision)
    decision!: UwDecision;

    @IsNumber()
    approvalLevel!: number;

    @IsUUID()
    lockToken!: string;

    @IsString()
    @IsOptional()
    notes?: string;

    @IsArray()
    @IsOptional()
    @ValidateNested({ each: true })
    @Type(() => UnderwritingConditionDto)
    conditions?: UnderwritingConditionDto[];
}

export class EscalateDto {
    @IsString()
    @IsNotEmpty()
    escalatedFrom!: string;

    @IsString()
    @IsNotEmpty()
    reason!: string;
}

export class AcquireLockDto {
    @IsString()
    @IsNotEmpty()
    underwriterId!: string;

    @IsNumber()
    @IsOptional()
    lockDurationMinutes?: number = 30;
}
