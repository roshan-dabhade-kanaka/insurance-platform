import { IsString, IsNotEmpty, IsEnum, IsNumber, IsOptional } from 'class-validator';
import { FraudReviewDecision } from '../../../temporal/shared/types';

export class SubmitFraudDecisionDto {
    @IsString()
    @IsNotEmpty()
    reviewedBy!: string;

    @IsEnum(FraudReviewDecision)
    decision!: FraudReviewDecision;

    @IsNumber()
    overallScore!: number;

    @IsString()
    @IsOptional()
    reviewerNotes?: string;
}
