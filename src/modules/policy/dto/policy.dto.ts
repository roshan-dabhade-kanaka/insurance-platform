import { IsString, IsNotEmpty, IsOptional, IsArray, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';

export class PolicyConditionDto {
    @IsString()
    @IsNotEmpty()
    code!: string;

    @IsString()
    @IsNotEmpty()
    description!: string;

    @IsNotEmpty()
    mandatory!: boolean;
}

export class IssuePolicyDto {
    @IsString()
    @IsOptional()
    snapshotId?: string;

    @IsArray()
    @IsOptional()
    @ValidateNested({ each: true })
    @Type(() => PolicyConditionDto)
    conditions?: PolicyConditionDto[];
}
