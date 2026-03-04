import { IsString, IsNotEmpty, IsNumber, IsDateString, IsObject, IsOptional, IsBoolean, IsArray, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';

class LineItemAssessmentDto {
    @IsString() claimItemId!: string;
    @IsNumber() claimedAmount!: number;
    @IsNumber() approvedAmount!: number;
    @IsString() @IsOptional() rejectionReason?: string;
}

export class CreateAssessmentDto {
    @IsNumber() assessedAmount!: number;
    @IsNumber() deductibleApplied!: number;
    @IsNumber() netPayout!: number;
    @IsArray() @IsOptional() @ValidateNested({ each: true }) @Type(() => LineItemAssessmentDto) lineItemAssessment?: LineItemAssessmentDto[];
    @IsString() @IsOptional() assessmentNotes?: string;
}

export class SubmitClaimDto {
    @IsString()
    @IsNotEmpty()
    policyId!: string;

    @IsString()
    @IsNotEmpty()
    policyCoverageId!: string;

    @IsNumber()
    @IsNotEmpty()
    claimedAmount!: number;

    @IsDateString()
    @IsNotEmpty()
    lossDate!: string;

    @IsString()
    @IsNotEmpty()
    lossDescription!: string;

    @IsObject()
    @IsNotEmpty()
    claimantData!: Record<string, unknown>;

    @IsString()
    @IsOptional()
    submittedBy?: string;
}

export class CreateInvestigationDto {
    @IsString()
    @IsOptional()
    investigationType?: string;

    @IsString()
    @IsOptional()
    assignedInvestigatorId?: string;
}
