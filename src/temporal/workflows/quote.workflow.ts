// =============================================================================
// Quote Workflow — Insurance Platform
//
// Orchestrates the full quote lifecycle:
//   DRAFT → RISK_PROFILING → RULE_EVALUATION → PREMIUM_CALCULATION
//        → QUOTED → SUBMITTED → UNDER_REVIEW | PENDING_SENIOR_REVIEW
//        → APPROVED | CONDITIONALLY_APPROVED | REJECTED
//        → ISSUED | CANCELLED | EXPIRED
//
// Integration:
//   - Temporal signals: uwDecision, cancelQuote, additionalInfo
//   - Temporal queries: getQuoteStatus
//   - Activities: risk profiling, eligibility rules, premium calc, UW lock, policy issuance
//
// Concurrency safety:
//   - Underwriting lock acquired before human-task wait
//   - Optimistic lock_token validated on decision submission
//   - Premium snapshot locked immediately after approval
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

import type { QuoteActivities } from '../activities/quote.activities';
import {
    QuoteWorkflowInput,
    QuoteWorkflowResult,
    QuoteWorkflowState,
    QuoteWorkflowStatus,
    UwDecision,
    UwDecisionSignalPayload,
    CancelQuoteSignalPayload,
    AdditionalInfoProvidedPayload,
    uwDecisionSignal,
    cancelQuoteSignal,
    additionalInfoSignal,
    getQuoteStatusQuery,
} from '../shared/types';
import {
    standardRetryPolicy,
    aggressiveRetryPolicy,
    resilientRetryPolicy,
    noRetryPolicy,
    ActivityTimeouts,
} from '../shared/retry-policies';

// ─────────────────────────────────────────────────────────────────────────────
// Activity Proxies — each group has its own retry configuration
// ─────────────────────────────────────────────────────────────────────────────

const {
    performRiskProfiling,
    evaluateEligibilityRules,
    calculatePremium,
    updateQuoteStatus,
    createUnderwritingCase,
    lockPremiumSnapshot,
    issuePolicy,
    notifyStakeholder,
} = proxyActivities<QuoteActivities>({
    retry: standardRetryPolicy,
    ...ActivityTimeouts.short,
});

const {
    acquireUnderwritingLock,
    releaseUnderwritingLock,
    recordUnderwritingDecision,
} = proxyActivities<QuoteActivities>({
    retry: aggressiveRetryPolicy,
    ...ActivityTimeouts.short,
});

const { escalateToSeniorUnderwriter } = proxyActivities<QuoteActivities>({
    retry: resilientRetryPolicy,
    ...ActivityTimeouts.short,
});

// Notification is fire-and-forget; no retry to prevent duplicate sends
const { notifyStakeholder: notifyOnce } = proxyActivities<QuoteActivities>({
    retry: noRetryPolicy,
    startToCloseTimeout: '30s',
});

// ─────────────────────────────────────────────────────────────────────────────
// Quote Workflow Definition
// ─────────────────────────────────────────────────────────────────────────────

export async function quoteWorkflow(input: QuoteWorkflowInput): Promise<QuoteWorkflowResult> {
    const { workflowId } = workflowInfo();

    // ── Mutable state — signals mutate these; queries read them ───────────────
    let state: QuoteWorkflowState = {
        status: QuoteWorkflowStatus.DRAFT,
        currentApprovalLevel: 1,
        isSeniorReviewRequired: false,
        lastUpdatedAt: new Date().toISOString(),
    };

    // Signals received from external actors
    let uwDecisionReceived: UwDecisionSignalPayload | null = null;
    let isCancelled = false;
    let cancelReason = '';
    let additionalInfoReceived: AdditionalInfoProvidedPayload | null = null;

    // ── Signal Handlers ───────────────────────────────────────────────────────

    setHandler(uwDecisionSignal, (payload: UwDecisionSignalPayload) => {
        log.info('UW decision signal received', { decision: payload.decision, level: payload.approvalLevel });
        uwDecisionReceived = payload;
        state.lockToken = payload.lockToken;
        state.lastUpdatedAt = new Date().toISOString();
    });

    setHandler(cancelQuoteSignal, (payload: CancelQuoteSignalPayload) => {
        log.info('Cancel quote signal received', { reason: payload.reason });
        isCancelled = true;
        cancelReason = payload.reason;
        state.lastUpdatedAt = new Date().toISOString();
    });

    setHandler(additionalInfoSignal, (payload: AdditionalInfoProvidedPayload) => {
        log.info('Additional info provided', { by: payload.providedBy });
        additionalInfoReceived = payload;
        state.lastUpdatedAt = new Date().toISOString();
    });

    // ── Query Handler — returns current snapshot to callers ──────────────────
    setHandler(getQuoteStatusQuery, () => ({ ...state }));

    // ─────────────────────────────────────────────────────────────────────────
    // Step 0 — Cancel check helper
    // ─────────────────────────────────────────────────────────────────────────
    const checkCancelled = async (): Promise<boolean> => {
        if (isCancelled) {
            state.status = QuoteWorkflowStatus.CANCELLED;
            state.rejectionReason = cancelReason;
            await updateQuoteStatus({
                tenantId: input.tenantId,
                quoteId: input.quoteId,
                status: QuoteWorkflowStatus.CANCELLED,
                reason: cancelReason,
            });
            return true;
        }
        return false;
    };

    try {
        // ─────────────────────────────────────────────────────────────────────
        // Step 1 — Risk Profiling
        // ─────────────────────────────────────────────────────────────────────
        state.status = QuoteWorkflowStatus.RISK_PROFILING;
        await updateQuoteStatus({ tenantId: input.tenantId, quoteId: input.quoteId, status: state.status });
        if (await checkCancelled()) return buildResult(input.quoteId, state);

        const riskResult = await performRiskProfiling({
            tenantId: input.tenantId,
            quoteId: input.quoteId,
            applicantData: input.applicantData,
            productVersionId: input.productVersionId,
        });

        state.riskScore = riskResult.totalScore;
        state.riskBand = riskResult.riskBand;
        state.isSeniorReviewRequired = riskResult.isSeniorReviewRequired;
        state.lastUpdatedAt = new Date().toISOString();

        log.info('Risk profiling complete', {
            score: riskResult.totalScore,
            band: riskResult.riskBand,
            requiresSenior: riskResult.isSeniorReviewRequired,
        });

        // DECLINED at risk level — terminate early
        if (riskResult.riskBand === 'DECLINED') {
            state.status = QuoteWorkflowStatus.REJECTED;
            state.rejectionReason = 'Applicant risk profile declined';
            await updateQuoteStatus({
                tenantId: input.tenantId,
                quoteId: input.quoteId,
                status: state.status,
                reason: state.rejectionReason,
            });
            return buildResult(input.quoteId, state);
        }

        // ─────────────────────────────────────────────────────────────────────
        // Step 2 — Eligibility Rule Evaluation (json-rules-engine)
        // ─────────────────────────────────────────────────────────────────────
        state.status = QuoteWorkflowStatus.RULE_EVALUATION;
        await updateQuoteStatus({ tenantId: input.tenantId, quoteId: input.quoteId, status: state.status });
        if (await checkCancelled()) return buildResult(input.quoteId, state);

        const eligibilityResult = await evaluateEligibilityRules({
            tenantId: input.tenantId,
            quoteId: input.quoteId,
            productVersionId: input.productVersionId,
            applicantData: input.applicantData,
            riskProfileId: riskResult.riskProfileId,
        });

        if (!eligibilityResult.isEligible) {
            state.status = QuoteWorkflowStatus.REJECTED;
            state.rejectionReason = `Ineligible: ${eligibilityResult.failedRules.map((r) => r.reason).join('; ')}`;
            await updateQuoteStatus({
                tenantId: input.tenantId,
                quoteId: input.quoteId,
                status: state.status,
                reason: state.rejectionReason,
            });
            return buildResult(input.quoteId, state);
        }

        // ─────────────────────────────────────────────────────────────────────
        // Step 3 — Premium Calculation
        // ─────────────────────────────────────────────────────────────────────
        state.status = QuoteWorkflowStatus.PREMIUM_CALCULATION;
        await updateQuoteStatus({ tenantId: input.tenantId, quoteId: input.quoteId, status: state.status });
        if (await checkCancelled()) return buildResult(input.quoteId, state);

        const premiumResult = await calculatePremium({
            tenantId: input.tenantId,
            quoteId: input.quoteId,
            productVersionId: input.productVersionId,
            lineItems: input.lineItems,
            riskProfileId: riskResult.riskProfileId,
            loadingPercentage: riskResult.loadingPercentage,
            applicantData: input.applicantData,
        });

        state.totalPremium = premiumResult.totalPremium;
        state.status = QuoteWorkflowStatus.QUOTED;
        await updateQuoteStatus({ tenantId: input.tenantId, quoteId: input.quoteId, status: state.status });

        // ─────────────────────────────────────────────────────────────────────
        // Step 4 — Create Underwriting Case & Acquire Lock
        // ─────────────────────────────────────────────────────────────────────
        state.status = QuoteWorkflowStatus.SUBMITTED;
        await updateQuoteStatus({ tenantId: input.tenantId, quoteId: input.quoteId, status: state.status });
        if (await checkCancelled()) return buildResult(input.quoteId, state);

        const uwCase = await createUnderwritingCase({
            tenantId: input.tenantId,
            quoteId: input.quoteId,
            riskProfileId: riskResult.riskProfileId,
            totalPremium: premiumResult.totalPremium,
            requiresSeniorReview: riskResult.isSeniorReviewRequired,
        });

        state.uwCaseId = uwCase.uwCaseId;
        state.currentApprovalLevel = uwCase.currentApprovalLevel;

        // ─────────────────────────────────────────────────────────────────────
        // Step 5 — Underwriting Review Loop (with Approval Hierarchy support)
        //
        // Supports multi-level approval:
        //   Level 1 → Standard UW → may REFER_TO_SENIOR
        //   Level 2 → Senior UW   → APPROVE | REJECT | CONDITIONALLY_APPROVE
        //
        // Concurrent lock:
        //   - Lock acquired before waiting for signal
        //   - lock_token validated when decision is recorded
        //   - Lock auto-expires; stale locks release via background Temporal activity
        // ─────────────────────────────────────────────────────────────────────
        let isUwComplete = false;
        const UW_DECISION_TIMEOUT_HOURS = 48;
        const SLA_TIMER = `${UW_DECISION_TIMEOUT_HOURS}h`;

        while (!isUwComplete) {
            if (await checkCancelled()) return buildResult(input.quoteId, state);

            const isCurrentSeniorLevel = riskResult.isSeniorReviewRequired && state.currentApprovalLevel === 2;
            state.status = isCurrentSeniorLevel
                ? QuoteWorkflowStatus.PENDING_SENIOR_REVIEW
                : QuoteWorkflowStatus.UNDER_REVIEW;

            await updateQuoteStatus({
                tenantId: input.tenantId,
                quoteId: input.quoteId,
                status: state.status,
                context: { approvalLevel: state.currentApprovalLevel },
            });

            // Acquire concurrent lock before exposing to underwriter
            const lockAssigneeId = uwCase.assignedUnderwriterId ?? 'UNASSIGNED';
            let lock: { lockId: string; lockToken: string } | null = null;
            try {
                lock = await acquireUnderwritingLock({
                    tenantId: input.tenantId,
                    uwCaseId: uwCase.uwCaseId,
                    underwriterId: lockAssigneeId,
                    lockDurationMinutes: UW_DECISION_TIMEOUT_HOURS * 60,
                });
                state.lockToken = lock.lockToken;
            } catch (lockError) {
                log.warn('Failed to acquire UW lock — case may already be locked', { error: lockError });
            }

            // Notify the underwriter
            await notifyOnce({
                tenantId: input.tenantId,
                recipientId: lockAssigneeId,
                templateKey: isCurrentSeniorLevel ? 'UW_SENIOR_REVIEW_REQUIRED' : 'UW_REVIEW_REQUIRED',
                payload: {
                    quoteId: input.quoteId,
                    uwCaseId: uwCase.uwCaseId,
                    lockToken: lock?.lockToken,
                    totalPremium: premiumResult.totalPremium,
                    riskScore: riskResult.totalScore,
                    riskBand: riskResult.riskBand,
                },
            });

            // Reset signal and wait for decision OR timeout/cancellation
            uwDecisionReceived = null;
            const decisionReceived = await Promise.race([
                condition(() => uwDecisionReceived !== null || isCancelled).then(() => 'decision'),
                sleep(SLA_TIMER).then(() => 'timeout'),
            ]);

            // Release lock regardless of outcome
            if (lock) {
                await releaseUnderwritingLock({ lockId: lock.lockId, lockToken: lock.lockToken });
                state.lockToken = undefined;
            }

            if (decisionReceived === 'timeout') {
                log.warn('UW SLA breached — auto-escalating', { uwCaseId: uwCase.uwCaseId });
                if (!state.isSeniorReviewRequired) {
                    // First level SLA breach → escalate to senior
                    const escalation = await escalateToSeniorUnderwriter({
                        tenantId: input.tenantId,
                        uwCaseId: uwCase.uwCaseId,
                        escalatedFrom: lockAssigneeId,
                        reason: `SLA of ${UW_DECISION_TIMEOUT_HOURS}h breached at Level ${state.currentApprovalLevel}`,
                    });
                    state.currentApprovalLevel = escalation.newApprovalLevel;
                    state.isSeniorReviewRequired = true;
                    continue; // loop again at senior level
                } else {
                    // Senior SLA also breached → auto-reject
                    state.status = QuoteWorkflowStatus.REJECTED;
                    state.rejectionReason = 'Underwriting SLA breached — auto-rejected';
                    await updateQuoteStatus({
                        tenantId: input.tenantId,
                        quoteId: input.quoteId,
                        status: state.status,
                        reason: state.rejectionReason,
                    });
                    return buildResult(input.quoteId, state);
                }
            }

            if (isCancelled) return buildResult(input.quoteId, state);

            const decision = uwDecisionReceived!;

            // Record the decision with optimistic lock token validation
            await recordUnderwritingDecision({
                tenantId: input.tenantId,
                uwCaseId: uwCase.uwCaseId,
                decidedBy: decision.decidedBy,
                decision: decision.decision,
                approvalLevel: decision.approvalLevel,
                lockToken: decision.lockToken,
                notes: decision.notes,
                conditions: decision.conditions,
            });

            // ── Decision Routing ────────────────────────────────────────────────
            switch (decision.decision) {
                case UwDecision.APPROVE:
                case UwDecision.CONDITIONALLY_APPROVE: {
                    state.status =
                        decision.decision === UwDecision.CONDITIONALLY_APPROVE
                            ? QuoteWorkflowStatus.CONDITIONALLY_APPROVED
                            : QuoteWorkflowStatus.APPROVED;
                    state.conditions = decision.conditions;
                    isUwComplete = true;
                    break;
                }

                case UwDecision.REJECT: {
                    state.status = QuoteWorkflowStatus.REJECTED;
                    state.rejectionReason = decision.notes ?? 'Rejected by underwriter';
                    isUwComplete = true;
                    break;
                }

                case UwDecision.REFER_TO_SENIOR: {
                    // Rule: risk_score > threshold → require Senior UW
                    if (!riskResult.isSeniorReviewRequired) {
                        state.isSeniorReviewRequired = true;
                    }
                    const escalation = await escalateToSeniorUnderwriter({
                        tenantId: input.tenantId,
                        uwCaseId: uwCase.uwCaseId,
                        escalatedFrom: decision.decidedBy,
                        reason: decision.notes ?? 'Referred to senior underwriter',
                    });
                    state.currentApprovalLevel = escalation.newApprovalLevel;
                    // Continue loop at senior level
                    break;
                }

                case UwDecision.REQUEST_INFO: {
                    // Wait for applicant to provide additional information (with 24h window)
                    additionalInfoReceived = null;
                    const infoReceived = await Promise.race([
                        condition(() => additionalInfoReceived !== null).then(() => 'info'),
                        sleep('24h').then(() => 'timeout'),
                    ]);
                    if (infoReceived === 'timeout') {
                        state.status = QuoteWorkflowStatus.REJECTED;
                        state.rejectionReason = 'Applicant did not provide requested information within 24h';
                        isUwComplete = true;
                    }
                    // If info provided, loop back through UW review with fresh signal
                    break;
                }
            }
        }

        // ─────────────────────────────────────────────────────────────────────
        // Step 6 — Post-Approval: Lock Snapshot + Issue Policy
        // ─────────────────────────────────────────────────────────────────────
        if (
            state.status === QuoteWorkflowStatus.APPROVED ||
            state.status === QuoteWorkflowStatus.CONDITIONALLY_APPROVED
        ) {
            await updateQuoteStatus({
                tenantId: input.tenantId,
                quoteId: input.quoteId,
                status: state.status,
                context: { conditions: state.conditions },
            });

            // Lock premium snapshot — prevents any recalculation after approval
            await lockPremiumSnapshot({
                tenantId: input.tenantId,
                quoteId: input.quoteId,
                snapshotId: premiumResult.snapshotId,
            });

            // Issue the policy
            const policy = await issuePolicy({
                tenantId: input.tenantId,
                quoteId: input.quoteId,
                snapshotId: premiumResult.snapshotId,
                conditions: state.conditions,
            });

            state.status = QuoteWorkflowStatus.ISSUED;
            await updateQuoteStatus({
                tenantId: input.tenantId,
                quoteId: input.quoteId,
                status: QuoteWorkflowStatus.ISSUED,
                context: { policyId: policy.policyId, policyNumber: policy.policyNumber },
            });

            // Notify policyholder
            await notifyOnce({
                tenantId: input.tenantId,
                recipientId: input.originatedBy ?? 'APPLICANT',
                templateKey: 'POLICY_ISSUED',
                payload: {
                    policyId: policy.policyId,
                    policyNumber: policy.policyNumber,
                    totalPremium: premiumResult.totalPremium,
                },
            });

            return {
                quoteId: input.quoteId,
                finalStatus: QuoteWorkflowStatus.ISSUED,
                policyId: policy.policyId,
                totalPremium: premiumResult.totalPremium,
            };
        }

        // Rejection path
        if (state.status === QuoteWorkflowStatus.REJECTED) {
            await updateQuoteStatus({
                tenantId: input.tenantId,
                quoteId: input.quoteId,
                status: QuoteWorkflowStatus.REJECTED,
                reason: state.rejectionReason,
            });
            await notifyOnce({
                tenantId: input.tenantId,
                recipientId: input.originatedBy ?? 'APPLICANT',
                templateKey: 'QUOTE_REJECTED',
                payload: { quoteId: input.quoteId, reason: state.rejectionReason },
            });
        }

        return buildResult(input.quoteId, state);
    } catch (err) {
        // ─────────────────────────────────────────────────────────────────────
        // Compensation Logic — on unrecoverable error, mark quote as cancelled
        // ─────────────────────────────────────────────────────────────────────
        if (!isCancellation(err)) {
            log.error('Unhandled error in quote workflow — compensating', { error: err, quoteId: input.quoteId });
            try {
                await CancellationScope.nonCancellable(async () => {
                    await updateQuoteStatus({
                        tenantId: input.tenantId,
                        quoteId: input.quoteId,
                        status: QuoteWorkflowStatus.CANCELLED,
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
// Helper
// ─────────────────────────────────────────────────────────────────────────────
function buildResult(quoteId: string, state: QuoteWorkflowState): QuoteWorkflowResult {
    return {
        quoteId,
        finalStatus: state.status,
        totalPremium: state.totalPremium,
        rejectionReason: state.rejectionReason,
    };
}
