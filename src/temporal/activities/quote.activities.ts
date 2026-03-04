// =============================================================================
// Quote Activities — Insurance Platform
//
// All activity implementations for the Quote workflow.
// Activities run in the NestJS Worker process (not the workflow sandbox).
// Each activity is an async function decorated with @temporalio/activity.
//
// Dependency injection pattern: activities are created via an activity factory
// function that closes over NestJS services injected at worker startup.
// =============================================================================

import { Context } from '@temporalio/activity';
import { QuoteLineItemInput } from '../shared/types';

// ─────────────────────────────────────────────────────────────────────────────
// Activity Input / Output Types
// ─────────────────────────────────────────────────────────────────────────────

export interface PerformRiskProfilingInput {
    tenantId: string;
    quoteId: string;
    applicantData: Record<string, unknown>;
    productVersionId: string;
}

export interface PerformRiskProfilingOutput {
    riskProfileId: string;
    totalScore: number;
    riskBand: 'LOW' | 'STANDARD' | 'HIGH' | 'DECLINED';
    loadingPercentage: number;
    isSeniorReviewRequired: boolean;  // totalScore > threshold
}

export interface EvaluateEligibilityRulesInput {
    tenantId: string;
    quoteId: string;
    productVersionId: string;
    applicantData: Record<string, unknown>;
    riskProfileId: string;
}

export interface EvaluateEligibilityRulesOutput {
    isEligible: boolean;
    failedRules: Array<{ ruleName: string; reason: string }>;
}

export interface CalculatePremiumInput {
    tenantId: string;
    quoteId: string;
    productVersionId: string;
    lineItems: QuoteLineItemInput[];
    riskProfileId: string;
    loadingPercentage: number;
    applicantData: Record<string, unknown>;
}

export interface CalculatePremiumOutput {
    snapshotId: string;
    basePremium: number;
    riderSurcharge: number;
    riskLoading: number;
    discountAmount: number;
    taxAmount: number;
    totalPremium: number;
}

export interface CreateUnderwritingCaseInput {
    tenantId: string;
    quoteId: string;
    riskProfileId: string;
    totalPremium: number;
    requiresSeniorReview: boolean;
}

export interface CreateUnderwritingCaseOutput {
    uwCaseId: string;
    assignedUnderwriterId: string | null;
    currentApprovalLevel: number;
}

export interface AcquireUnderwritingLockInput {
    tenantId: string;
    uwCaseId: string;
    underwriterId: string;
    lockDurationMinutes: number;
}

export interface AcquireUnderwritingLockOutput {
    lockId: string;
    lockToken: string;
    lockExpiresAt: string;
}

export interface ReleaseUnderwritingLockInput {
    lockId: string;
    lockToken: string;
}

export interface RecordUnderwritingDecisionInput {
    tenantId: string;
    uwCaseId: string;
    decidedBy: string;
    decision: 'APPROVE' | 'REJECT' | 'REFER_TO_SENIOR' | 'REQUEST_INFO' | 'CONDITIONALLY_APPROVE';
    approvalLevel: number;
    lockToken: string;
    notes?: string;
    conditions?: Array<{ code: string; description: string; mandatory: boolean }>;
}

export interface LockPremiumSnapshotInput {
    tenantId: string;
    quoteId: string;
    snapshotId: string;
}

export interface IssueQuoteInput {
    tenantId: string;
    quoteId: string;
}

export interface UpdateQuoteStatusInput {
    tenantId: string;
    quoteId: string;
    status: string;
    reason?: string;
    context?: Record<string, unknown>;
}

export interface IssuePolicyInput {
    tenantId: string;
    quoteId: string;
    snapshotId: string;
    conditions?: Array<{ code: string; description: string; mandatory: boolean }>;
}

export interface IssuePolicyOutput {
    policyId: string;
    policyNumber: string;
}

export interface NotifyStakeholderInput {
    tenantId: string;
    recipientId: string;
    templateKey: string;
    payload: Record<string, unknown>;
}

export interface EscalateToSeniorUwInput {
    tenantId: string;
    uwCaseId: string;
    escalatedFrom: string;
    reason: string;
}

export interface EscalateToSeniorUwOutput {
    newApprovalLevel: number;
    assignedSeniorUwId: string | null;
}

// ─────────────────────────────────────────────────────────────────────────────
// Activity Factory
//
// Accepts NestJS services and returns activity implementations.
// Registered on the worker via `taskQueue` at startup.
//
// Usage in worker.ts:
//   const activities = createQuoteActivities(quoteService, riskService, ...);
//   const worker = await Worker.create({ activities, ... });
// ─────────────────────────────────────────────────────────────────────────────

export function createQuoteActivities(services: {
    quoteService: IQuoteService;
    riskService: IRiskService;
    ruleEngine: IRuleEngineService;
    premiumService: IPremiumService;
    uwService: IUnderwritingService;
    policyService: IPolicyService;
    notificationService: INotificationService;
    auditService: IAuditService;
}) {
    const {
        quoteService,
        riskService,
        ruleEngine,
        premiumService,
        uwService,
        policyService,
        notificationService,
        auditService,
    } = services;

    return {
        // ── 1. Risk Profiling ───────────────────────────────────────────────────
        async performRiskProfiling(
            input: PerformRiskProfilingInput,
        ): Promise<PerformRiskProfilingOutput> {
            Context.current().heartbeat('Starting risk profiling');
            const result = await riskService.assessRisk(input);
            await auditService.log({
                tenantId: input.tenantId,
                entityType: 'QUOTE',
                entityId: input.quoteId,
                action: 'RISK_PROFILED',
                newState: result.riskBand,
                context: { riskScore: result.totalScore },
            });
            return result;
        },

        // ── 2. Eligibility Rule Evaluation (json-rules-engine) ──────────────────
        async evaluateEligibilityRules(
            input: EvaluateEligibilityRulesInput,
        ): Promise<EvaluateEligibilityRulesOutput> {
            Context.current().heartbeat('Evaluating eligibility rules');
            const rules = await ruleEngine.getEligibilityRules(input.tenantId, input.productVersionId);
            const result = await ruleEngine.evaluateEligibility(rules, {
                ...input.applicantData,
                riskProfileId: input.riskProfileId,
            });
            return result;
        },

        // ── 3. Premium Calculation ──────────────────────────────────────────────
        async calculatePremium(
            input: CalculatePremiumInput,
        ): Promise<CalculatePremiumOutput> {
            Context.current().heartbeat('Calculating premium');
            const snapshot = await premiumService.calculate(input);
            return snapshot;
        },

        // ── 4. Update Quote Status (idempotent) ─────────────────────────────────
        async updateQuoteStatus(input: UpdateQuoteStatusInput): Promise<void> {
            await quoteService.updateStatus(
                input.tenantId,
                input.quoteId,
                input.status,
                input.reason,
                input.context,
            );
            await auditService.log({
                tenantId: input.tenantId,
                entityType: 'QUOTE',
                entityId: input.quoteId,
                action: 'STATE_CHANGED',
                newState: input.status,
                context: { reason: input.reason },
            });
        },

        // ── 5. Create Underwriting Case ─────────────────────────────────────────
        async createUnderwritingCase(
            input: CreateUnderwritingCaseInput,
        ): Promise<CreateUnderwritingCaseOutput> {
            return uwService.createCase(input);
        },

        // ── 6. Acquire Underwriting Lock (optimistic concurrency) ───────────────
        async acquireUnderwritingLock(
            input: AcquireUnderwritingLockInput,
        ): Promise<AcquireUnderwritingLockOutput> {
            // Throws if lock already held by another underwriter
            return uwService.acquireLock(
                input.tenantId,
                input.uwCaseId,
                input.underwriterId,
                input.lockDurationMinutes,
            );
        },

        // ── 7. Release Underwriting Lock ────────────────────────────────────────
        async releaseUnderwritingLock(input: ReleaseUnderwritingLockInput): Promise<void> {
            await uwService.releaseLock(input.lockId, input.lockToken);
        },

        // ── 8. Record Underwriting Decision ─────────────────────────────────────
        async recordUnderwritingDecision(input: RecordUnderwritingDecisionInput): Promise<void> {
            await uwService.recordDecision(input);
            await auditService.log({
                tenantId: input.tenantId,
                entityType: 'UW_CASE',
                entityId: input.uwCaseId,
                action: 'DECISION_RECORDED',
                newState: input.decision,
                context: { level: input.approvalLevel, decidedBy: input.decidedBy },
            });
        },

        // ── 9. Escalate to Senior Underwriter ───────────────────────────────────
        async escalateToSeniorUnderwriter(
            input: EscalateToSeniorUwInput,
        ): Promise<EscalateToSeniorUwOutput> {
            const result = await uwService.escalate(input);
            await notificationService.send({
                tenantId: input.tenantId,
                recipientId: result.assignedSeniorUwId ?? 'UW_SUPERVISOR',
                templateKey: 'UW_ESCALATION',
                payload: { uwCaseId: input.uwCaseId, reason: input.reason },
            });
            return result;
        },

        // ── 10. Lock Premium Snapshot (prevents recalculation post-approval) ─────
        async lockPremiumSnapshot(input: LockPremiumSnapshotInput): Promise<void> {
            await premiumService.lockSnapshot(input.tenantId, input.snapshotId);
        },

        // ── 11. Issue Policy ────────────────────────────────────────────────────
        async issuePolicy(input: IssuePolicyInput): Promise<IssuePolicyOutput> {
            Context.current().heartbeat('Issuing policy');
            const result = await policyService.issue(input);
            await auditService.log({
                tenantId: input.tenantId,
                entityType: 'POLICY',
                entityId: result.policyId,
                action: 'CREATED',
                newState: 'IN_FORCE',
                context: { quoteId: input.quoteId },
            });
            return result;
        },

        // ── 12. Notify Stakeholder ──────────────────────────────────────────────
        async notifyStakeholder(input: NotifyStakeholderInput): Promise<void> {
            await notificationService.send(input);
        },
    };
}

export type QuoteActivities = ReturnType<typeof createQuoteActivities>;

// ─────────────────────────────────────────────────────────────────────────────
// Service Interfaces (implemented in NestJS service layer)
// ─────────────────────────────────────────────────────────────────────────────

export interface IQuoteService {
    updateStatus(
        tenantId: string,
        quoteId: string,
        status: string,
        reason?: string,
        context?: Record<string, unknown>,
    ): Promise<void>;
}

export interface IRiskService {
    assessRisk(input: PerformRiskProfilingInput): Promise<PerformRiskProfilingOutput>;
}

export interface IRuleEngineService {
    getEligibilityRules(tenantId: string, productVersionId: string): Promise<unknown[]>;
    evaluateEligibility(
        rules: unknown[],
        facts: Record<string, unknown>,
    ): Promise<EvaluateEligibilityRulesOutput>;
}

export interface IPremiumService {
    calculate(input: CalculatePremiumInput): Promise<CalculatePremiumOutput>;
    lockSnapshot(tenantId: string, snapshotId: string): Promise<void>;
}

export interface IUnderwritingService {
    createCase(input: CreateUnderwritingCaseInput): Promise<CreateUnderwritingCaseOutput>;
    acquireLock(
        tenantId: string,
        uwCaseId: string,
        underwriterId: string,
        lockDurationMinutes: number,
    ): Promise<AcquireUnderwritingLockOutput>;
    releaseLock(lockId: string, lockToken: string): Promise<void>;
    recordDecision(input: RecordUnderwritingDecisionInput): Promise<void>;
    escalate(input: EscalateToSeniorUwInput): Promise<EscalateToSeniorUwOutput>;
}

export interface IPolicyService {
    issue(input: IssuePolicyInput): Promise<IssuePolicyOutput>;
}

export interface INotificationService {
    send(input: NotifyStakeholderInput): Promise<void>;
}

export interface IAuditService {
    log(params: {
        tenantId: string;
        entityType: string;
        entityId: string;
        action: string;
        oldState?: string;
        newState?: string;
        context?: Record<string, unknown>;
    }): Promise<void>;
}
