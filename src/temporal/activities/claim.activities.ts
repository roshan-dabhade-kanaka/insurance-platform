// =============================================================================
// Claim Activities — Insurance Platform
//
// All activity implementations for the Claim workflow.
// Registered in the NestJS Worker process via activity factory.
// =============================================================================

import { Context } from '@temporalio/activity';
import {
    ClaimAssessmentPayload,
    FinanceApprovalPayload,
} from '../shared/types';

// ─────────────────────────────────────────────────────────────────────────────
// Activity Input / Output Types
// ─────────────────────────────────────────────────────────────────────────────

export interface ValidatePolicyInput {
    tenantId: string;
    claimId: string;
    policyId: string;
    lossDate: string;
}

export interface PolicyValidationOutput {
    isValid: boolean;
    policyStatus: string;
    inceptionDate: string;
    expiryDate: string;
    failureReason?: string;
}

export interface ValidateCoverageInput {
    tenantId: string;
    claimId: string;
    policyId: string;
    policyCoverageId: string;
    claimedAmount: number;
    lossDate: string;
}

export interface CoverageValidationOutput {
    isValid: boolean;
    sumInsured: number;
    deductible: number;
    maxPayable: number;
    failureReason?: string;
}

export interface CheckWaitingPeriodInput {
    tenantId: string;
    claimId: string;
    policyId: string;
    policyCoverageId: string;
    lossDate: string;
    inceptionDate: string;
}

export interface WaitingPeriodOutput {
    isPassed: boolean;
    waitingPeriodDays: number;
    daysSinceInception: number;
    failureReason?: string;
}

export interface CheckDuplicateClaimInput {
    tenantId: string;
    claimId: string;
    policyId: string;
    policyCoverageId: string;
    lossDate: string;
    claimedAmount: number;
}

export interface DuplicateCheckOutput {
    isDuplicate: boolean;
    duplicateClaimId?: string;
    failureReason?: string;
}

export interface UpdateClaimStatusInput {
    tenantId: string;
    claimId: string;
    status: string;
    reason?: string;
    context?: Record<string, unknown>;
}

export interface RecordValidationResultInput {
    tenantId: string;
    claimId: string;
    validationType: string;
    status: 'PASS' | 'FAIL' | 'WARNING';
    detail: Record<string, unknown>;
}

export interface StartInvestigationInput {
    tenantId: string;
    claimId: string;
    investigationType?: string;
    assignedInvestigatorId?: string;
}

export interface StartInvestigationOutput {
    investigationId: string;
}

export interface EvaluateFraudRulesInput {
    tenantId: string;
    claimId: string;
    claimedAmount: number;
    averageClaimAmount: number;
    escalationMultiplier: number;   // 3x threshold
    claimantData: Record<string, unknown>;
}

export interface FraudEvaluationOutput {
    shouldEscalate: boolean;
    overallScore: number;
    triggeredRules: Array<{ ruleName: string; score: number; severity: string }>;
    riskLevel: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL';
}

export interface RecordFraudReviewInput {
    tenantId: string;
    claimId: string;
    decision: string;
    overallScore: number;
    reviewedBy: string;
    reviewerNotes?: string;
    triggeredRules: Array<{ ruleName: string; score: number; severity: string }>;
}

export interface RecordAssessmentInput {
    tenantId: string;
    claimId: string;
    assessment: ClaimAssessmentPayload;
}

export interface RecordAssessmentOutput {
    assessmentId: string;
}

export interface CreatePayoutRequestInput {
    tenantId: string;
    claimId: string;
    assessmentId: string;
    netPayout: number;
    currencyCode: string;
    payeeDetails: Record<string, unknown>;
    requestedBy: string;
    partialInstallments?: Array<{
        installmentNumber: number;
        amount: number;
        scheduledDate: string;
    }>;
}

export interface CreatePayoutRequestOutput {
    payoutRequestId: string;
}

export interface RecordFinanceApprovalInput {
    tenantId: string;
    payoutRequestId: string;
    approval: FinanceApprovalPayload;
}

export interface DisburseFundsInput {
    tenantId: string;
    payoutRequestId: string;
    claimId: string;
    installmentNumber?: number;
    amount: number;
    payeeDetails: Record<string, unknown>;
    idempotencyKey: string;         // workflowId + installmentNumber for deduplication
}

export interface DisburseFundsOutput {
    disbursementId: string;
    transactionRef: string;
    status: 'DISBURSED' | 'FAILED';
}

export interface ReopenClaimInput {
    tenantId: string;
    claimId: string;
    reopenedBy: string;
    reason: string;
    additionalEvidence?: Record<string, unknown>;
}

// ─────────────────────────────────────────────────────────────────────────────
// Activity Factory
// ─────────────────────────────────────────────────────────────────────────────

export function createClaimActivities(services: {
    claimService: IClaimService;
    policyService: IClaimPolicyService;
    ruleEngine: IClaimRuleEngine;
    fraudService: IFraudService;
    financeService: IFinanceService;
    notificationService: IClaimNotificationService;
    auditService: IClaimAuditService;
}) {
    const {
        claimService,
        policyService,
        ruleEngine,
        fraudService,
        financeService,
        notificationService,
        auditService,
    } = services;

    return {
        // ── 1. Policy Validation ────────────────────────────────────────────────
        async validatePolicy(input: ValidatePolicyInput): Promise<PolicyValidationOutput> {
            Context.current().heartbeat('Validating policy');
            const result = await policyService.validateForClaim(input);
            await claimService.recordValidation(input.tenantId, input.claimId, {
                validationType: 'POLICY_STATUS_CHECK',
                status: result.isValid ? 'PASS' : 'FAIL',
                detail: result as any,
            });
            return result;
        },

        // ── 2. Coverage Validation ──────────────────────────────────────────────
        async validateCoverage(input: ValidateCoverageInput): Promise<CoverageValidationOutput> {
            Context.current().heartbeat('Validating coverage');
            const result = await policyService.validateCoverage(input);
            await claimService.recordValidation(input.tenantId, input.claimId, {
                validationType: 'COVERAGE_CHECK',
                status: result.isValid ? 'PASS' : 'FAIL',
                detail: result as any,
            });
            return result;
        },

        // ── 3. Waiting Period Check ─────────────────────────────────────────────
        async checkWaitingPeriod(input: CheckWaitingPeriodInput): Promise<WaitingPeriodOutput> {
            const result = await policyService.checkWaitingPeriod(input);
            await claimService.recordValidation(input.tenantId, input.claimId, {
                validationType: 'DATE_RANGE_CHECK',
                status: result.isPassed ? 'PASS' : 'FAIL',
                detail: result as any,
            });
            return result;
        },

        // ── 4. Duplicate Claim Check ────────────────────────────────────────────
        async checkDuplicateClaim(input: CheckDuplicateClaimInput): Promise<DuplicateCheckOutput> {
            const result = await claimService.checkDuplicate(input);
            await claimService.recordValidation(input.tenantId, input.claimId, {
                validationType: 'DUPLICATE_CHECK',
                status: result.isDuplicate ? 'FAIL' : 'PASS',
                detail: result as any,
            });
            return result;
        },

        // ── 5. Update Claim Status (idempotent) ─────────────────────────────────
        async updateClaimStatus(input: UpdateClaimStatusInput): Promise<void> {
            await claimService.updateStatus(
                input.tenantId,
                input.claimId,
                input.status,
                input.reason,
                input.context,
            );
            await auditService.log({
                tenantId: input.tenantId,
                entityType: 'CLAIM',
                entityId: input.claimId,
                action: 'STATE_CHANGED',
                newState: input.status,
                context: { reason: input.reason },
            });
        },

        // ── 6. Start Investigation ──────────────────────────────────────────────
        async startInvestigation(input: StartInvestigationInput): Promise<StartInvestigationOutput> {
            const result = await claimService.createInvestigation(input);
            await notificationService.send({
                tenantId: input.tenantId,
                recipientId: input.assignedInvestigatorId ?? 'INVESTIGATION_TEAM',
                templateKey: 'INVESTIGATION_ASSIGNED',
                payload: { claimId: input.claimId, investigationId: result.investigationId },
            });
            return result;
        },

        // ── 7. Evaluate Fraud Rules (json-rules-engine) ─────────────────────────
        async evaluateFraudRules(input: EvaluateFraudRulesInput): Promise<FraudEvaluationOutput> {
            Context.current().heartbeat('Evaluating fraud rules');

            const rules = await ruleEngine.getFraudRules(input.tenantId);
            const baseEval = await ruleEngine.evaluateFraud(rules, {
                claimedAmount: input.claimedAmount,
                ...input.claimantData,
            });

            // Fraud Rule: if claim_amount > N × average — force escalation regardless of score
            const amountEscalation = input.claimedAmount > input.escalationMultiplier * input.averageClaimAmount;

            return {
                ...baseEval,
                shouldEscalate: amountEscalation || baseEval.shouldEscalate,
                triggeredRules: [
                    ...baseEval.triggeredRules,
                    ...(amountEscalation
                        ? [{
                            ruleName: 'AMOUNT_EXCEEDS_MULTIPLIER_THRESHOLD',
                            score: 50,
                            severity: 'HIGH',
                        }]
                        : []),
                ],
            };
        },

        // ── 8. Record Fraud Review Result ───────────────────────────────────────
        async recordFraudReview(input: RecordFraudReviewInput): Promise<void> {
            await fraudService.recordReview(input);
            await auditService.log({
                tenantId: input.tenantId,
                entityType: 'CLAIM',
                entityId: input.claimId,
                action: 'FRAUD_REVIEWED',
                newState: input.decision,
                context: { score: input.overallScore, reviewedBy: input.reviewedBy },
            });
        },

        // ── 9. Record Claim Assessment ──────────────────────────────────────────
        async recordClaimAssessment(input: RecordAssessmentInput): Promise<RecordAssessmentOutput> {
            const result = await claimService.createAssessment(input);
            await auditService.log({
                tenantId: input.tenantId,
                entityType: 'CLAIM',
                entityId: input.claimId,
                action: 'ASSESSED',
                context: {
                    assessedAmount: input.assessment.assessedAmount,
                    netPayout: input.assessment.netPayout,
                },
            });
            return result;
        },

        // ── 10. Create Payout Request ────────────────────────────────────────────
        async createPayoutRequest(
            input: CreatePayoutRequestInput,
        ): Promise<CreatePayoutRequestOutput> {
            return financeService.createPayoutRequest(input);
        },

        // ── 11. Record Finance Approval ─────────────────────────────────────────
        async recordFinanceApproval(input: RecordFinanceApprovalInput): Promise<void> {
            await financeService.recordApproval(input);
            await auditService.log({
                tenantId: input.tenantId,
                entityType: 'PAYOUT',
                entityId: input.payoutRequestId,
                action: 'FINANCE_APPROVED',
                newState: input.approval.decision,
                context: { approvedAmount: input.approval.approvedAmount },
            });
        },

        // ── 12. Disburse Funds (idempotent via idempotencyKey) ─────────────────
        async disburseFunds(input: DisburseFundsInput): Promise<DisburseFundsOutput> {
            Context.current().heartbeat(`Disbursing installment ${input.installmentNumber ?? 1}`);
            const result = await financeService.disburse(input);
            await auditService.log({
                tenantId: input.tenantId,
                entityType: 'PAYOUT',
                entityId: input.payoutRequestId,
                action: result.status === 'DISBURSED' ? 'DISBURSED' : 'DISBURSEMENT_FAILED',
                context: {
                    transactionRef: result.transactionRef,
                    installmentNumber: input.installmentNumber,
                    amount: input.amount,
                },
            });
            return result;
        },

        // ── 13. Reopen Claim (compensation / undo-close) ─────────────────────
        async reopenClaim(input: ReopenClaimInput): Promise<void> {
            await claimService.reopen(input);
            await auditService.log({
                tenantId: input.tenantId,
                entityType: 'CLAIM',
                entityId: input.claimId,
                action: 'REOPENED',
                newState: 'REOPENED',
                context: { reopenedBy: input.reopenedBy, reason: input.reason },
            });
            await notificationService.send({
                tenantId: input.tenantId,
                recipientId: input.reopenedBy,
                templateKey: 'CLAIM_REOPENED',
                payload: { claimId: input.claimId, reason: input.reason },
            });
        },

        // ── 14. Notify Stakeholder ──────────────────────────────────────────────
        async notifyStakeholder(input: {
            tenantId: string;
            recipientId: string;
            templateKey: string;
            payload: Record<string, unknown>;
        }): Promise<void> {
            await notificationService.send(input);
        },
    };
}

export type ClaimActivities = ReturnType<typeof createClaimActivities>;

// ─────────────────────────────────────────────────────────────────────────────
// Service Interfaces
// ─────────────────────────────────────────────────────────────────────────────

export interface IClaimService {
    updateStatus(tenantId: string, claimId: string, status: string, reason?: string, context?: Record<string, unknown>): Promise<void>;
    recordValidation(tenantId: string, claimId: string, data: { validationType: string; status: string; detail: Record<string, unknown> }): Promise<void>;
    checkDuplicate(input: CheckDuplicateClaimInput): Promise<DuplicateCheckOutput>;
    createInvestigation(input: StartInvestigationInput): Promise<StartInvestigationOutput>;
    createAssessment(input: RecordAssessmentInput): Promise<RecordAssessmentOutput>;
    reopen(input: ReopenClaimInput): Promise<void>;
}

export interface IClaimPolicyService {
    validateForClaim(input: ValidatePolicyInput): Promise<PolicyValidationOutput>;
    validateCoverage(input: ValidateCoverageInput): Promise<CoverageValidationOutput>;
    checkWaitingPeriod(input: CheckWaitingPeriodInput): Promise<WaitingPeriodOutput>;
}

export interface IClaimRuleEngine {
    getFraudRules(tenantId: string): Promise<unknown[]>;
    evaluateFraud(rules: unknown[], facts: Record<string, unknown>): Promise<FraudEvaluationOutput>;
}

export interface IFraudService {
    recordReview(input: RecordFraudReviewInput): Promise<void>;
}

export interface IFinanceService {
    createPayoutRequest(input: CreatePayoutRequestInput): Promise<CreatePayoutRequestOutput>;
    recordApproval(input: RecordFinanceApprovalInput): Promise<void>;
    disburse(input: DisburseFundsInput): Promise<DisburseFundsOutput>;
}

export interface IClaimNotificationService {
    send(input: { tenantId: string; recipientId: string; templateKey: string; payload: Record<string, unknown> }): Promise<void>;
}

export interface IClaimAuditService {
    log(params: { tenantId: string; entityType: string; entityId: string; action: string; oldState?: string; newState?: string; context?: Record<string, unknown> }): Promise<void>;
}
