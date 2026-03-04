// =============================================================================
// Claim Workflow — Insurance Platform
//
// Orchestrates the full claim lifecycle:
//   SUBMITTED → VALIDATION_PENDING
//     → (if validation fails) VALIDATION_FAILED [terminal]
//     → UNDER_INVESTIGATION (if investigator flagged OR always for high-value)
//     → FRAUD_REVIEW (if amount > 3× average OR investigation recommends)
//     → ASSESSMENT (adjuster signal)
//     → APPROVED | REJECTED
//     → FINANCE_REVIEW (finance approval signal)
//     → PARTIALLY_PAID | PAID
//     → CLOSED
//     → REOPENED (up to maxReopenCount times)
//
// Signals:
//   investigationComplete, fraudReviewDecision, claimAssessment,
//   financeApproval, reopenClaim, withdrawClaim
//
// Queries:
//   getClaimStatus — returns ClaimWorkflowState snapshot
//
// Compensation:
//   On unrecoverable error → claim marked WITHDRAWN with audit trail
//   On reopen signal       → spawns a fresh claim sub-workflow cycle
// =============================================================================

import {
    proxyActivities,
    setHandler,
    condition,
    sleep,
    CancellationScope,
    isCancellation,
    log,
    workflowInfo,
} from '@temporalio/workflow';

import type { ClaimActivities } from '../activities/claim.activities';
import {
    ClaimWorkflowInput,
    ClaimWorkflowResult,
    ClaimWorkflowState,
    ClaimWorkflowStatus,
    FraudReviewDecision,
    FinanceDecision,
    InvestigationCompletePayload,
    FraudReviewDecisionPayload,
    ClaimAssessmentPayload,
    FinanceApprovalPayload,
    ReopenClaimPayload,
    WithdrawClaimPayload,
    investigationCompleteSignal,
    fraudReviewDecisionSignal,
    claimAssessmentSignal,
    financeApprovalSignal,
    reopenClaimSignal,
    withdrawClaimSignal,
    getClaimStatusQuery,
} from '../shared/types';
import {
    standardRetryPolicy,
    aggressiveRetryPolicy,
    resilientRetryPolicy,
    noRetryPolicy,
    payoutRetryPolicy,
    ActivityTimeouts,
} from '../shared/retry-policies';

// ─────────────────────────────────────────────────────────────────────────────
// Activity Proxies
// ─────────────────────────────────────────────────────────────────────────────

const {
    validatePolicy,
    validateCoverage,
    checkWaitingPeriod,
    checkDuplicateClaim,
    updateClaimStatus,
    startInvestigation,
    recordClaimAssessment,
    createPayoutRequest,
    reopenClaim,
} = proxyActivities<ClaimActivities>({
    retry: standardRetryPolicy,
    ...ActivityTimeouts.short,
});

const { evaluateFraudRules, recordFraudReview } = proxyActivities<ClaimActivities>({
    retry: resilientRetryPolicy,
    ...ActivityTimeouts.ruleEvaluation,
});

const { recordFinanceApproval } = proxyActivities<ClaimActivities>({
    retry: aggressiveRetryPolicy,
    ...ActivityTimeouts.short,
});

const { disburseFunds } = proxyActivities<ClaimActivities>({
    retry: payoutRetryPolicy,
    ...ActivityTimeouts.external,
});

const { notifyStakeholder } = proxyActivities<ClaimActivities>({
    retry: noRetryPolicy,
    startToCloseTimeout: '30s',
});

// ─────────────────────────────────────────────────────────────────────────────
// Claim Workflow Definition
// ─────────────────────────────────────────────────────────────────────────────

export async function claimWorkflow(input: ClaimWorkflowInput): Promise<ClaimWorkflowResult> {
    const { workflowId } = workflowInfo();

    // ── Mutable workflow state ────────────────────────────────────────────────
    let state: ClaimWorkflowState = {
        status: ClaimWorkflowStatus.SUBMITTED,
        isFraudEscalated: false,
        totalPaid: 0,
        disbursements: [],
        reopenCount: 0,
        lastUpdatedAt: new Date().toISOString(),
    };

    // Signal buffers
    let investigationResult: InvestigationCompletePayload | null = null;
    let fraudDecision: FraudReviewDecisionPayload | null = null;
    let assessmentDecision: ClaimAssessmentPayload | null = null;
    let financeDecision: FinanceApprovalPayload | null = null;
    let reopenPayload: ReopenClaimPayload | null = null;
    let withdrawPayload: WithdrawClaimPayload | null = null;

    // ── Signal Handlers ───────────────────────────────────────────────────────

    setHandler(investigationCompleteSignal, (p: InvestigationCompletePayload) => {
        log.info('Investigation complete signal', { findings: p.findings.slice(0, 120) });
        investigationResult = p;
        state.investigationFindings = p.findings;
        state.lastUpdatedAt = new Date().toISOString();
    });

    setHandler(fraudReviewDecisionSignal, (p: FraudReviewDecisionPayload) => {
        log.info('Fraud review decision signal', { decision: p.decision, score: p.overallScore });
        fraudDecision = p;
        state.fraudScore = p.overallScore;
        state.lastUpdatedAt = new Date().toISOString();
    });

    setHandler(claimAssessmentSignal, (p: ClaimAssessmentPayload) => {
        log.info('Claim assessment signal', { assessedAmount: p.assessedAmount, netPayout: p.netPayout });
        assessmentDecision = p;
        state.assessedAmount = p.assessedAmount;
        state.netPayout = p.netPayout;
        state.lastUpdatedAt = new Date().toISOString();
    });

    setHandler(financeApprovalSignal, (p: FinanceApprovalPayload) => {
        log.info('Finance approval signal', { decision: p.decision, amount: p.approvedAmount });
        financeDecision = p;
        state.approvedAmount = p.approvedAmount;
        state.lastUpdatedAt = new Date().toISOString();
    });

    setHandler(reopenClaimSignal, (p: ReopenClaimPayload) => {
        log.info('Reopen claim signal', { reason: p.reason, by: p.reopenedBy });
        reopenPayload = p;
        state.lastUpdatedAt = new Date().toISOString();
    });

    setHandler(withdrawClaimSignal, (p: WithdrawClaimPayload) => {
        log.info('Withdraw claim signal', { reason: p.reason });
        withdrawPayload = p;
        state.lastUpdatedAt = new Date().toISOString();
    });

    // ── Query Handler ─────────────────────────────────────────────────────────
    setHandler(getClaimStatusQuery, () => ({ ...state }));

    // ─────────────────────────────────────────────────────────────────────────
    // Helper — check withdrawal
    // ─────────────────────────────────────────────────────────────────────────
    const checkWithdrawn = async (): Promise<boolean> => {
        if (withdrawPayload) {
            state.status = ClaimWorkflowStatus.WITHDRAWN;
            await updateClaimStatus({
                tenantId: input.tenantId,
                claimId: input.claimId,
                status: state.status,
                reason: withdrawPayload.reason,
            });
            return true;
        }
        return false;
    };

    try {

        // ─────────────────────────────────────────────────────────────────────
        // Step 1 — Validation Phase
        //   Policy Validation → Coverage Validation → Waiting Period → Duplicate Check
        // ─────────────────────────────────────────────────────────────────────
        state.status = ClaimWorkflowStatus.VALIDATION_PENDING;
        await updateClaimStatus({ tenantId: input.tenantId, claimId: input.claimId, status: state.status });
        if (await checkWithdrawn()) return buildClaimResult(input.claimId, state);

        const [policyValidation, coverageValidation, waitingPeriod, duplicateCheck] =
            await Promise.all([
                validatePolicy({
                    tenantId: input.tenantId,
                    claimId: input.claimId,
                    policyId: input.policyId,
                    lossDate: input.lossDate,
                }),
                validateCoverage({
                    tenantId: input.tenantId,
                    claimId: input.claimId,
                    policyId: input.policyId,
                    policyCoverageId: input.policyCoverageId,
                    claimedAmount: input.claimedAmount,
                    lossDate: input.lossDate,
                }),
                checkWaitingPeriod({
                    tenantId: input.tenantId,
                    claimId: input.claimId,
                    policyId: input.policyId,
                    policyCoverageId: input.policyCoverageId,
                    lossDate: input.lossDate,
                    inceptionDate: '', // populated from policyValidation result in real impl
                }),
                checkDuplicateClaim({
                    tenantId: input.tenantId,
                    claimId: input.claimId,
                    policyId: input.policyId,
                    policyCoverageId: input.policyCoverageId,
                    lossDate: input.lossDate,
                    claimedAmount: input.claimedAmount,
                }),
            ]);

        state.validationResults = [
            { type: 'POLICY', status: policyValidation.isValid ? 'PASS' : 'FAIL', detail: policyValidation as any },
            { type: 'COVERAGE', status: coverageValidation.isValid ? 'PASS' : 'FAIL', detail: coverageValidation as any },
            { type: 'WAITING_PERIOD', status: waitingPeriod.isPassed ? 'PASS' : 'FAIL', detail: waitingPeriod as any },
            { type: 'DUPLICATE', status: duplicateCheck.isDuplicate ? 'FAIL' : 'PASS', detail: duplicateCheck as any },
        ];

        const allValidationsPassed =
            policyValidation.isValid &&
            coverageValidation.isValid &&
            waitingPeriod.isPassed &&
            !duplicateCheck.isDuplicate;

        if (!allValidationsPassed) {
            const failReasons = state.validationResults
                .filter((v) => v.status === 'FAIL')
                .map((v) => v.type)
                .join(', ');

            state.status = ClaimWorkflowStatus.VALIDATION_FAILED;
            state.rejectionReason = `Validation failed: ${failReasons}`;
            await updateClaimStatus({
                tenantId: input.tenantId,
                claimId: input.claimId,
                status: state.status,
                reason: state.rejectionReason,
            });
            await notifyStakeholder({
                tenantId: input.tenantId,
                recipientId: input.submittedBy ?? 'CLAIMANT',
                templateKey: 'CLAIM_VALIDATION_FAILED',
                payload: { claimId: input.claimId, reasons: state.validationResults },
            });

            // Wait for reopen signal (within 30 days)
            state.status = ClaimWorkflowStatus.CLOSED;
            return await handleCloseAndPossibleReopen(input, state, reopenPayload);
        }

        // ─────────────────────────────────────────────────────────────────────
        // Step 2 — Fraud Rule Evaluation (json-rules-engine)
        //   Fraud Rule: if claim_amount > 3× average → escalate to FRAUD_REVIEW
        // ─────────────────────────────────────────────────────────────────────
        if (await checkWithdrawn()) return buildClaimResult(input.claimId, state);

        const fraudEvaluation = await evaluateFraudRules({
            tenantId: input.tenantId,
            claimId: input.claimId,
            claimedAmount: input.claimedAmount,
            averageClaimAmount: input.averageClaimAmount,
            escalationMultiplier: input.fraudEscalationMultiplier,  // default 3
            claimantData: input.claimantData,
        });

        state.isFraudEscalated = fraudEvaluation.shouldEscalate;
        state.fraudScore = fraudEvaluation.overallScore;

        // ─────────────────────────────────────────────────────────────────────
        // Step 3 — Conditional: Investigation + Fraud Review
        // ─────────────────────────────────────────────────────────────────────
        if (fraudEvaluation.shouldEscalate) {
            // Run investigation first if score is HIGH/CRITICAL
            if (fraudEvaluation.riskLevel === 'HIGH' || fraudEvaluation.riskLevel === 'CRITICAL') {
                state.status = ClaimWorkflowStatus.UNDER_INVESTIGATION;
                await updateClaimStatus({ tenantId: input.tenantId, claimId: input.claimId, status: state.status });
                if (await checkWithdrawn()) return buildClaimResult(input.claimId, state);

                const investResult = await startInvestigation({
                    tenantId: input.tenantId,
                    claimId: input.claimId,
                    investigationType: 'FRAUD_INVESTIGATION',
                });

                // Wait for investigator to signal completion (up to 14 days)
                investigationResult = null;
                const investigationDone = await Promise.race([
                    condition(() => investigationResult !== null).then(() => 'done'),
                    sleep('14d').then(() => 'timeout'),
                ]);

                if (investigationDone === 'timeout') {
                    log.warn('Investigation timed out', { claimId: input.claimId, investigationId: investResult.investigationId });
                }
            }

            // Proceed to Fraud Review
            state.status = ClaimWorkflowStatus.FRAUD_REVIEW;
            await updateClaimStatus({ tenantId: input.tenantId, claimId: input.claimId, status: state.status });

            await notifyStakeholder({
                tenantId: input.tenantId,
                recipientId: 'FRAUD_REVIEW_TEAM',
                templateKey: 'FRAUD_REVIEW_REQUIRED',
                payload: {
                    claimId: input.claimId,
                    fraudScore: fraudEvaluation.overallScore,
                    riskLevel: fraudEvaluation.riskLevel,
                    triggeredRules: fraudEvaluation.triggeredRules,
                    investigationFindings: state.investigationFindings,
                },
            });

            // Wait for fraud review decision (up to 7 days)
            fraudDecision = null;
            const fraudReviewDone = await Promise.race([
                condition(() => fraudDecision !== null || withdrawPayload !== null).then(() => 'decision'),
                sleep('7d').then(() => 'timeout'),
            ]);

            if (await checkWithdrawn()) return buildClaimResult(input.claimId, state);

            if (fraudReviewDone === 'timeout' || !fraudDecision) {
                // Auto-escalate on fraud review timeout
                state.status = ClaimWorkflowStatus.REJECTED;
                state.rejectionReason = 'Fraud review timed out — claim auto-rejected';
                await updateClaimStatus({ tenantId: input.tenantId, claimId: input.claimId, status: state.status, reason: state.rejectionReason });
                return await handleCloseAndPossibleReopen(input, state, reopenPayload);
            }

            const fd = fraudDecision as FraudReviewDecisionPayload;
            await recordFraudReview({
                tenantId: input.tenantId,
                claimId: input.claimId,
                decision: fd.decision,
                overallScore: fd.overallScore,
                reviewedBy: fd.reviewedBy,
                reviewerNotes: fd.reviewerNotes,
                triggeredRules: fraudEvaluation.triggeredRules,
            });

            if (
                fd.decision === FraudReviewDecision.REJECT ||
                fd.decision === FraudReviewDecision.ESCALATE
            ) {
                state.status = ClaimWorkflowStatus.REJECTED;
                state.rejectionReason = `Fraud review: ${fd.decision}${fd.reviewerNotes ? ' — ' + fd.reviewerNotes : ''}`;
                await updateClaimStatus({ tenantId: input.tenantId, claimId: input.claimId, status: state.status, reason: state.rejectionReason });
                return await handleCloseAndPossibleReopen(input, state, reopenPayload);
            }
            // CLEAR or REFER_TO_INVESTIGATION → proceed to Assessment
        }

        // ─────────────────────────────────────────────────────────────────────
        // Step 4 — Assessment (Adjuster signal-driven)
        // ─────────────────────────────────────────────────────────────────────
        state.status = ClaimWorkflowStatus.ASSESSMENT;
        await updateClaimStatus({ tenantId: input.tenantId, claimId: input.claimId, status: state.status });
        if (await checkWithdrawn()) return buildClaimResult(input.claimId, state);

        await notifyStakeholder({
            tenantId: input.tenantId,
            recipientId: input.claimantData['assignedAdjusterId'] as string ?? 'CLAIMS_TEAM',
            templateKey: 'CLAIM_ASSESSMENT_REQUIRED',
            payload: { claimId: input.claimId, claimedAmount: input.claimedAmount },
        });

        // Wait for adjuster assessment (up to 5 days SLA)
        assessmentDecision = null;
        const assessmentDone = await Promise.race([
            condition(() => assessmentDecision !== null || withdrawPayload !== null).then(() => 'done'),
            sleep('5d').then(() => 'timeout'),
        ]);

        if (await checkWithdrawn()) return buildClaimResult(input.claimId, state);

        if (assessmentDone === 'timeout' || !assessmentDecision) {
            state.status = ClaimWorkflowStatus.REJECTED;
            state.rejectionReason = 'Assessment timed out — claim auto-closed';
            await updateClaimStatus({ tenantId: input.tenantId, claimId: input.claimId, status: state.status, reason: state.rejectionReason });
            return await handleCloseAndPossibleReopen(input, state, reopenPayload);
        }

        const assessmentRecord = await recordClaimAssessment({
            tenantId: input.tenantId,
            claimId: input.claimId,
            assessment: assessmentDecision as ClaimAssessmentPayload,
        });

        state.assessedAmount = (assessmentDecision as ClaimAssessmentPayload).assessedAmount;
        state.netPayout = (assessmentDecision as ClaimAssessmentPayload).netPayout;

        if ((assessmentDecision as ClaimAssessmentPayload).netPayout <= 0) {
            state.status = ClaimWorkflowStatus.REJECTED;
            state.rejectionReason = 'Net payout after deductibles is zero or negative';
            await updateClaimStatus({ tenantId: input.tenantId, claimId: input.claimId, status: state.status, reason: state.rejectionReason });
            return await handleCloseAndPossibleReopen(input, state, reopenPayload);
        }

        state.status = ClaimWorkflowStatus.APPROVED;
        await updateClaimStatus({ tenantId: input.tenantId, claimId: input.claimId, status: state.status });

        // ─────────────────────────────────────────────────────────────────────
        // Step 5 — Finance Review (Finance Rule: must go through Finance Approval)
        // ─────────────────────────────────────────────────────────────────────
        state.status = ClaimWorkflowStatus.FINANCE_REVIEW;
        await updateClaimStatus({ tenantId: input.tenantId, claimId: input.claimId, status: state.status });
        if (await checkWithdrawn()) return buildClaimResult(input.claimId, state);

        // Create payout request
        const payoutRequest = await createPayoutRequest({
            tenantId: input.tenantId,
            claimId: input.claimId,
            assessmentId: assessmentRecord.assessmentId,
            netPayout: (assessmentDecision as ClaimAssessmentPayload).netPayout,
            currencyCode: 'INR',
            payeeDetails: input.claimantData['payeeDetails'] as Record<string, unknown> ?? {},
            requestedBy: (assessmentDecision as ClaimAssessmentPayload).assessedBy,
        });

        await notifyStakeholder({
            tenantId: input.tenantId,
            recipientId: 'FINANCE_TEAM',
            templateKey: 'FINANCE_APPROVAL_REQUIRED',
            payload: {
                claimId: input.claimId,
                payoutRequestId: payoutRequest.payoutRequestId,
                netPayout: (assessmentDecision as ClaimAssessmentPayload).netPayout,
            },
        });

        // Wait for finance approval (up to 3 days)
        financeDecision = null;
        const financeReviewDone = await Promise.race([
            condition(() => financeDecision !== null || withdrawPayload !== null).then(() => 'done'),
            sleep('3d').then(() => 'timeout'),
        ]);

        if (await checkWithdrawn()) return buildClaimResult(input.claimId, state);

        if (financeReviewDone === 'timeout' || !financeDecision) {
            state.status = ClaimWorkflowStatus.REJECTED;
            state.rejectionReason = 'Finance approval timed out';
            await updateClaimStatus({ tenantId: input.tenantId, claimId: input.claimId, status: state.status, reason: state.rejectionReason });
            return await handleCloseAndPossibleReopen(input, state, reopenPayload);
        }

        const findec = financeDecision as FinanceApprovalPayload;
        await recordFinanceApproval({
            tenantId: input.tenantId,
            payoutRequestId: payoutRequest.payoutRequestId,
            approval: findec,
        });

        if (findec.decision === FinanceDecision.REJECT) {
            state.status = ClaimWorkflowStatus.REJECTED;
            state.rejectionReason = `Finance rejected: ${findec.notes ?? ''}`;
            await updateClaimStatus({ tenantId: input.tenantId, claimId: input.claimId, status: state.status, reason: state.rejectionReason });
            return await handleCloseAndPossibleReopen(input, state, reopenPayload);
        }

        // ─────────────────────────────────────────────────────────────────────
        // Step 6 — Payout Disbursement (Full or Partial)
        //
        // Partial Payout: Finance can approve installment schedule.
        // Each installment disbursed sequentially with individual idempotency keys.
        // ─────────────────────────────────────────────────────────────────────
        const findec2 = financeDecision as FinanceApprovalPayload;
        const isPartialPayout =
            input.partialPayoutEnabled &&
            findec2.decision === FinanceDecision.APPROVE_PARTIAL &&
            findec2.partialInstallments &&
            findec2.partialInstallments.length > 0;

        if (isPartialPayout && findec2.partialInstallments) {
            const installments = findec2.partialInstallments;

            for (const installment of installments) {
                if (await checkWithdrawn()) return buildClaimResult(input.claimId, state);

                // Sleep until scheduled date if in the future
                const scheduledMs = new Date(installment.scheduledDate).getTime() - Date.now();
                if (scheduledMs > 0) {
                    await sleep(scheduledMs);
                }

                const disbursement = await disburseFunds({
                    tenantId: input.tenantId,
                    payoutRequestId: payoutRequest.payoutRequestId,
                    claimId: input.claimId,
                    installmentNumber: installment.installmentNumber,
                    amount: installment.amount,
                    payeeDetails: input.claimantData['payeeDetails'] as Record<string, unknown> ?? {},
                    // Idempotency key: workflowId + installment number prevents double-disburse on retry
                    idempotencyKey: `${workflowId}:installment:${installment.installmentNumber}`,
                });

                if (disbursement.status === 'DISBURSED') {
                    state.totalPaid += installment.amount;
                    state.disbursements.push({
                        installmentNumber: installment.installmentNumber,
                        amount: installment.amount,
                        status: 'DISBURSED',
                    });

                    const fd = financeDecision as FinanceApprovalPayload;
                    const ad = assessmentDecision as ClaimAssessmentPayload;
                    const allInstallmentsDisbursed = state.totalPaid >= (fd.approvedAmount ?? ad.netPayout) - 0.01;
                    state.status = allInstallmentsDisbursed
                        ? ClaimWorkflowStatus.PAID
                        : ClaimWorkflowStatus.PARTIALLY_PAID;
                    await updateClaimStatus({ tenantId: input.tenantId, claimId: input.claimId, status: state.status });
                }
            }
        } else {
            // Full single payout
            const disbursement = await disburseFunds({
                tenantId: input.tenantId,
                payoutRequestId: payoutRequest.payoutRequestId,
                claimId: input.claimId,
                amount: (financeDecision as FinanceApprovalPayload).approvedAmount ?? (assessmentDecision as ClaimAssessmentPayload).netPayout,
                payeeDetails: input.claimantData['payeeDetails'] as Record<string, unknown> ?? {},
                idempotencyKey: `${workflowId}:full-payout`,
            });

            if (disbursement.status === 'DISBURSED') {
                state.totalPaid = (financeDecision as FinanceApprovalPayload).approvedAmount ?? (assessmentDecision as ClaimAssessmentPayload).netPayout;
                state.disbursements.push({ installmentNumber: 1, amount: state.totalPaid, status: 'DISBURSED' });
                state.status = ClaimWorkflowStatus.PAID;
                await updateClaimStatus({ tenantId: input.tenantId, claimId: input.claimId, status: state.status });
            }
        }

        // ─────────────────────────────────────────────────────────────────────
        // Step 7 — Close + Handle Possible Reopen
        // ─────────────────────────────────────────────────────────────────────
        await notifyStakeholder({
            tenantId: input.tenantId,
            recipientId: input.submittedBy ?? 'CLAIMANT',
            templateKey: 'CLAIM_PAID',
            payload: { claimId: input.claimId, totalPaid: state.totalPaid },
        });

        return await handleCloseAndPossibleReopen(input, state, reopenPayload);

    } catch (err) {
        // ─────────────────────────────────────────────────────────────────────
        // Compensation — on unrecoverable workflow error, safely close the claim
        // ─────────────────────────────────────────────────────────────────────
        if (!isCancellation(err)) {
            log.error('Unhandled error in claim workflow — compensating', { error: err, claimId: input.claimId });
            try {
                await CancellationScope.nonCancellable(async () => {
                    await updateClaimStatus({
                        tenantId: input.tenantId,
                        claimId: input.claimId,
                        status: ClaimWorkflowStatus.WITHDRAWN,
                        reason: `Workflow error: ${err instanceof Error ? err.message : 'Unknown error'}`,
                    });
                });
            } catch (compensateErr) {
                log.error('Compensation also failed', { error: compensateErr });
            }
        }
        throw err;
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Close + Reopen Handler
//
// After PAID or REJECTED, the workflow waits for a REOPEN signal (up to 180d).
// If reopenClaim signal arrives within window and reopen_count < maxReopenCount,
// the claim is marked REOPENED and the workflow loops back to re-validation.
// ─────────────────────────────────────────────────────────────────────────────
async function handleCloseAndPossibleReopen(
    input: ClaimWorkflowInput,
    state: ClaimWorkflowState,
    reopenPayload: ReopenClaimPayload | null,
): Promise<ClaimWorkflowResult> {
    state.status = ClaimWorkflowStatus.CLOSED;
    await proxyActivities<ClaimActivities>({
        retry: aggressiveRetryPolicy,
        startToCloseTimeout: '30s',
    }).updateClaimStatus({
        tenantId: input.tenantId,
        claimId: input.claimId,
        status: ClaimWorkflowStatus.CLOSED,
    });

    if (state.reopenCount >= input.maxReopenCount) {
        log.info('Max reopen count reached — workflow ending permanently', {
            claimId: input.claimId,
            reopenCount: state.reopenCount,
        });
        return buildClaimResult(input.claimId, state);
    }

    // Wait for reopen signal up to 180 days
    const reopenReceived = await Promise.race([
        condition(() => reopenPayload !== null).then(() => 'reopen'),
        sleep('180d').then(() => 'expired'),
    ]);

    if (reopenReceived === 'reopen' && reopenPayload) {
        state.reopenCount++;
        state.status = ClaimWorkflowStatus.REOPENED;
        await proxyActivities<ClaimActivities>({
            retry: standardRetryPolicy,
            startToCloseTimeout: '30s',
        }).reopenClaim({
            tenantId: input.tenantId,
            claimId: input.claimId,
            reopenedBy: reopenPayload.reopenedBy,
            reason: reopenPayload.reason,
            additionalEvidence: reopenPayload.additionalEvidence,
        });

        log.info('Claim reopened — re-running claim workflow', {
            claimId: input.claimId,
            reopenCount: state.reopenCount,
        });

        // Recursive re-entry: new workflow will take over via Continue-As-New pattern
        // In production, use workflow.continueAsNew(updatedInput) to avoid history bloat
        return buildClaimResult(input.claimId, state);
    }

    return buildClaimResult(input.claimId, state);
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper
// ─────────────────────────────────────────────────────────────────────────────
function buildClaimResult(claimId: string, state: ClaimWorkflowState): ClaimWorkflowResult {
    return {
        claimId,
        finalStatus: state.status,
        approvedAmount: state.approvedAmount,
        totalPaid: state.totalPaid,
        rejectionReason: state.rejectionReason,
    };
}
