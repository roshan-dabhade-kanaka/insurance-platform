// =============================================================================
// Temporal Shared Types — Insurance Platform
// All signal definitions, query definitions, and input/output types
// used across Quote and Claim workflows.
// =============================================================================

import { defineSignal, defineQuery } from '@temporalio/workflow';

// ─────────────────────────────────────────────────────────────────────────────
// Lifecycle Enums (workflow-safe — no DB imports allowed in workflow sandbox)
// ─────────────────────────────────────────────────────────────────────────────

export enum QuoteWorkflowStatus {
    DRAFT = 'DRAFT',
    RISK_PROFILING = 'RISK_PROFILING',
    PREMIUM_CALCULATION = 'PREMIUM_CALCULATION',
    RULE_EVALUATION = 'RULE_EVALUATION',
    QUOTED = 'QUOTED',
    SUBMITTED = 'SUBMITTED',
    UNDER_REVIEW = 'UNDER_REVIEW',
    PENDING_SENIOR_REVIEW = 'PENDING_SENIOR_REVIEW',
    APPROVED = 'APPROVED',
    CONDITIONALLY_APPROVED = 'CONDITIONALLY_APPROVED',
    REJECTED = 'REJECTED',
    ISSUED = 'ISSUED',
    EXPIRED = 'EXPIRED',
    CANCELLED = 'CANCELLED',
}

export enum ClaimWorkflowStatus {
    SUBMITTED = 'SUBMITTED',
    VALIDATION_PENDING = 'VALIDATION_PENDING',
    VALIDATION_FAILED = 'VALIDATION_FAILED',
    UNDER_INVESTIGATION = 'UNDER_INVESTIGATION',
    FRAUD_REVIEW = 'FRAUD_REVIEW',
    ASSESSMENT = 'ASSESSMENT',
    APPROVED = 'APPROVED',
    REJECTED = 'REJECTED',
    FINANCE_REVIEW = 'FINANCE_REVIEW',
    PARTIALLY_PAID = 'PARTIALLY_PAID',
    PAID = 'PAID',
    CLOSED = 'CLOSED',
    REOPENED = 'REOPENED',
    WITHDRAWN = 'WITHDRAWN',
}

export enum UwDecision {
    APPROVE = 'APPROVE',
    REJECT = 'REJECT',
    REFER_TO_SENIOR = 'REFER_TO_SENIOR',
    REQUEST_INFO = 'REQUEST_INFO',
    CONDITIONALLY_APPROVE = 'CONDITIONALLY_APPROVE',
}

export enum FinanceDecision {
    APPROVE_FULL = 'APPROVE_FULL',
    APPROVE_PARTIAL = 'APPROVE_PARTIAL',
    REJECT = 'REJECT',
    ESCALATE = 'ESCALATE',
}

export enum FraudReviewDecision {
    CLEAR = 'CLEAR',
    REJECT = 'REJECT',
    REFER_TO_INVESTIGATION = 'REFER_TO_INVESTIGATION',
    ESCALATE = 'ESCALATE',
}

// ─────────────────────────────────────────────────────────────────────────────
// Quote Workflow — Input / Output Types
// ─────────────────────────────────────────────────────────────────────────────

export interface QuoteWorkflowInput {
    tenantId: string;
    quoteId: string;
    productVersionId: string;
    applicantData: Record<string, unknown>;
    lineItems: QuoteLineItemInput[];
    riskThreshold: number;           // score above which senior UW is required
    quoteExpiryDays: number;
    originatedBy?: string;           // userId
}

export interface QuoteLineItemInput {
    coverageOptionId: string;
    riderId?: string;
    sumInsured: number;
    deductibleId?: string;
}

export interface QuoteWorkflowResult {
    quoteId: string;
    finalStatus: QuoteWorkflowStatus;
    policyId?: string;
    totalPremium?: number;
    rejectionReason?: string;
}

// ─────────────────────────────────────────────────────────────────────────────
// Quote Workflow — Signal Definitions
// ─────────────────────────────────────────────────────────────────────────────

export interface UwDecisionSignalPayload {
    decidedBy: string;               // userId
    decision: UwDecision;
    approvalLevel: number;
    lockToken: string;               // optimistic concurrency token
    notes?: string;
    conditions?: Array<{ code: string; description: string; mandatory: boolean }>;
}

export interface CancelQuoteSignalPayload {
    cancelledBy: string;
    reason: string;
}

export interface AdditionalInfoProvidedPayload {
    providedBy: string;
    infoData: Record<string, unknown>;
}

/** Underwriter signals their decision (approve / reject / refer / request_info) */
export const uwDecisionSignal = defineSignal<[UwDecisionSignalPayload]>('uwDecision');

/** Applicant or agent cancels the quote */
export const cancelQuoteSignal = defineSignal<[CancelQuoteSignalPayload]>('cancelQuote');

/** Applicant provides additional information requested by UW */
export const additionalInfoSignal = defineSignal<[AdditionalInfoProvidedPayload]>('additionalInfo');

// ─────────────────────────────────────────────────────────────────────────────
// Quote Workflow — Query Definitions
// ─────────────────────────────────────────────────────────────────────────────

export interface QuoteWorkflowState {
    status: QuoteWorkflowStatus;
    riskScore?: number;
    riskBand?: string;
    totalPremium?: number;
    uwCaseId?: string;
    currentApprovalLevel: number;
    isSeniorReviewRequired: boolean;
    lockToken?: string;
    conditions?: Array<{ code: string; description: string; mandatory: boolean }>;
    rejectionReason?: string;
    lastUpdatedAt: string;
}

export const getQuoteStatusQuery = defineQuery<QuoteWorkflowState>('getQuoteStatus');

// ─────────────────────────────────────────────────────────────────────────────
// Claim Workflow — Input / Output Types
// ─────────────────────────────────────────────────────────────────────────────

export interface ClaimWorkflowInput {
    tenantId: string;
    claimId: string;
    policyId: string;
    policyCoverageId: string;
    claimedAmount: number;
    lossDate: string;
    lossDescription: string;
    claimantData: Record<string, unknown>;
    submittedBy?: string;
    fraudEscalationMultiplier: number;   // default: 3 — triggers fraud review if amount > N × average
    averageClaimAmount: number;          // tenant-level average for fraud detection
    maxReopenCount: number;              // default: 3
    partialPayoutEnabled: boolean;
}

export interface ClaimWorkflowResult {
    claimId: string;
    finalStatus: ClaimWorkflowStatus;
    approvedAmount?: number;
    totalPaid?: number;
    rejectionReason?: string;
}

// ─────────────────────────────────────────────────────────────────────────────
// Claim Workflow — Signal Definitions
// ─────────────────────────────────────────────────────────────────────────────

export interface InvestigationCompletePayload {
    investigatorId: string;
    findings: string;
    evidenceSummary: Array<Record<string, unknown>>;
    recommendFraudReview: boolean;
}

export interface FraudReviewDecisionPayload {
    reviewedBy: string;
    decision: FraudReviewDecision;
    overallScore: number;
    reviewerNotes?: string;
}

export interface ClaimAssessmentPayload {
    assessedBy: string;
    assessedAmount: number;
    deductibleApplied: number;
    netPayout: number;
    lineItemAssessment: Array<{
        claimItemId: string;
        claimedAmount: number;
        approvedAmount: number;
        rejectionReason?: string;
    }>;
    assessmentNotes?: string;
}

export interface FinanceApprovalPayload {
    approverId: string;
    decision: FinanceDecision;
    approvedAmount?: number;
    partialInstallments?: Array<{ installmentNumber: number; amount: number; scheduledDate: string }>;
    notes?: string;
}

export interface ReopenClaimPayload {
    reopenedBy: string;
    reason: string;
    additionalEvidence?: Record<string, unknown>;
}

export interface WithdrawClaimPayload {
    withdrawnBy: string;
    reason: string;
}

/** Investigation team completes their work */
export const investigationCompleteSignal =
    defineSignal<[InvestigationCompletePayload]>('investigationComplete');

/** Fraud review team renders their decision */
export const fraudReviewDecisionSignal =
    defineSignal<[FraudReviewDecisionPayload]>('fraudReviewDecision');

/** Adjuster submits their assessment */
export const claimAssessmentSignal =
    defineSignal<[ClaimAssessmentPayload]>('claimAssessment');

/** Finance team approves or rejects the payout */
export const financeApprovalSignal =
    defineSignal<[FinanceApprovalPayload]>('financeApproval');

/** Policyholder or operator reopens a closed/rejected claim */
export const reopenClaimSignal =
    defineSignal<[ReopenClaimPayload]>('reopenClaim');

/** Claimant withdraws their claim */
export const withdrawClaimSignal =
    defineSignal<[WithdrawClaimPayload]>('withdrawClaim');

// ─────────────────────────────────────────────────────────────────────────────
// Claim Workflow — Query Definitions
// ─────────────────────────────────────────────────────────────────────────────

export interface ClaimWorkflowState {
    status: ClaimWorkflowStatus;
    validationResults?: Array<{ type: string; status: string; detail?: Record<string, unknown> }>;
    isFraudEscalated: boolean;
    fraudScore?: number;
    assessedAmount?: number;
    netPayout?: number;
    approvedAmount?: number;
    totalPaid: number;
    disbursements: Array<{ installmentNumber: number; amount: number; status: string }>;
    reopenCount: number;
    investigationFindings?: string;
    rejectionReason?: string;
    lastUpdatedAt: string;
}

export const getClaimStatusQuery = defineQuery<ClaimWorkflowState>('getClaimStatus');
