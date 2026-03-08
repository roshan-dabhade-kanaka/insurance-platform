// ─────────────────────────────────────────────────────────────────────────────
// Platform-wide Lifecycle State Enums
// Used by TypeORM entities (enum columns) and NestJS services / DTOs
// ─────────────────────────────────────────────────────────────────────────────

// ── Quote ────────────────────────────────────────────────────────────────────
export enum QuoteStatus {
  DRAFT = 'DRAFT',
  SUBMITTED = 'SUBMITTED',
  UNDER_REVIEW = 'UNDER_REVIEW',
  APPROVED = 'APPROVED',
  REJECTED = 'REJECTED',
  CANCELLED = 'CANCELLED',
  ISSUED = 'ISSUED',
  BOUND = 'BOUND',
  EXPIRED = 'EXPIRED',
  // Legacy / Temporal workflow states kept for backward compat
  PENDING_ELIGIBILITY = 'PENDING_ELIGIBILITY',
  ELIGIBLE = 'ELIGIBLE',
  INELIGIBLE = 'INELIGIBLE',
  RATED = 'RATED',
  PRESENTED = 'PRESENTED',
  ACCEPTED = 'ACCEPTED',
  DECLINED = 'DECLINED',
}

// ── Policy ───────────────────────────────────────────────────────────────────
export enum PolicyStatus {
  PENDING_ISSUANCE = 'PENDING_ISSUANCE',
  IN_FORCE = 'IN_FORCE',
  LAPSED = 'LAPSED',
  SUSPENDED = 'SUSPENDED',
  CANCELLED = 'CANCELLED',
  EXPIRED = 'EXPIRED',
  REINSTATED = 'REINSTATED',
  MATURED = 'MATURED',
}

// ── Claim ────────────────────────────────────────────────────────────────────
export enum ClaimStatus {
  SUBMITTED = 'SUBMITTED',
  VALIDATED = 'VALIDATED',
  VALIDATION_FAILED = 'VALIDATION_FAILED',
  UNDER_INVESTIGATION = 'UNDER_INVESTIGATION',
  FRAUD_REVIEW = 'FRAUD_REVIEW',
  ASSESSED = 'ASSESSED',
  APPROVED = 'APPROVED',
  PARTIALLY_PAID = 'PARTIALLY_PAID',
  PAID = 'PAID',
  REJECTED = 'REJECTED',
  CLOSED = 'CLOSED',
  REOPENED = 'REOPENED',
  WITHDRAWN = 'WITHDRAWN',
}

// ── Underwriting ─────────────────────────────────────────────────────────────
export enum UnderwritingStatus {
  PENDING = 'PENDING',
  IN_REVIEW = 'IN_REVIEW',
  REFERRED = 'REFERRED',
  APPROVED = 'APPROVED',
  DECLINED = 'DECLINED',
  CONDITIONALLY_APPROVED = 'CONDITIONALLY_APPROVED',
  CANCELLED = 'CANCELLED',
}

// ── Underwriting Decision ────────────────────────────────────────────────────
export enum UnderwritingDecisionOutcome {
  APPROVE = 'APPROVE',
  DECLINE = 'DECLINE',
  REFER = 'REFER',
  REQUEST_INFO = 'REQUEST_INFO',
  CONDITIONALLY_APPROVE = 'CONDITIONALLY_APPROVE',
}

// ── Payout ───────────────────────────────────────────────────────────────────
export enum PayoutStatus {
  PENDING_APPROVAL = 'PENDING_APPROVAL',
  PARTIALLY_APPROVED = 'PARTIALLY_APPROVED',
  APPROVED = 'APPROVED',
  REJECTED = 'REJECTED',
  DISBURSED = 'DISBURSED',
  PARTIALLY_DISBURSED = 'PARTIALLY_DISBURSED',
  FAILED = 'FAILED',
  CANCELLED = 'CANCELLED',
}

export enum DisbursementStatus {
  SCHEDULED = 'SCHEDULED',
  PROCESSING = 'PROCESSING',
  DISBURSED = 'DISBURSED',
  FAILED = 'FAILED',
  CANCELLED = 'CANCELLED',
}

// ── Risk ─────────────────────────────────────────────────────────────────────
export enum RiskBand {
  PREFERRED = 'PREFERRED',
  LOW = 'LOW',
  STANDARD = 'STANDARD',
  SUBSTANDARD = 'SUBSTANDARD',
  HIGH = 'HIGH',
  DECLINED = 'DECLINED',
}

// ── Fraud ────────────────────────────────────────────────────────────────────
export enum FraudRiskSeverity {
  LOW = 'LOW',
  MEDIUM = 'MEDIUM',
  HIGH = 'HIGH',
  CRITICAL = 'CRITICAL',
}

export enum FraudReviewOutcome {
  CLEAR = 'CLEAR',
  FLAGGED = 'FLAGGED',
  REFERRED = 'REFERRED',
  ESCALATED = 'ESCALATED',
}

// ── Claim Validation ─────────────────────────────────────────────────────────
export enum ClaimValidationStatus {
  PASS = 'PASS',
  FAIL = 'FAIL',
  WARNING = 'WARNING',
}

export enum ClaimValidationType {
  COVERAGE_CHECK = 'COVERAGE_CHECK',
  DEDUCTIBLE_CHECK = 'DEDUCTIBLE_CHECK',
  POLICY_STATUS_CHECK = 'POLICY_STATUS_CHECK',
  DUPLICATE_CHECK = 'DUPLICATE_CHECK',
  DATE_RANGE_CHECK = 'DATE_RANGE_CHECK',
  LIMIT_CHECK = 'LIMIT_CHECK',
  ELIGIBILITY_CHECK = 'ELIGIBILITY_CHECK',
}

// ── Investigation ────────────────────────────────────────────────────────────
export enum InvestigationStatus {
  OPEN = 'OPEN',
  IN_PROGRESS = 'IN_PROGRESS',
  PENDING_RESPONSE = 'PENDING_RESPONSE',
  COMPLETED = 'COMPLETED',
  CLOSED = 'CLOSED',
}

// ── Approval ─────────────────────────────────────────────────────────────────
export enum ApprovalDecision {
  PENDING = 'PENDING',
  APPROVED = 'APPROVED',
  REJECTED = 'REJECTED',
  ESCALATED = 'ESCALATED',
}

// ── Product Version ───────────────────────────────────────────────────────────
export enum ProductVersionStatus {
  DRAFT = 'DRAFT',
  ACTIVE = 'ACTIVE',
  DEPRECATED = 'DEPRECATED',
  ARCHIVED = 'ARCHIVED',
}

// ── Audit ─────────────────────────────────────────────────────────────────────
export enum AuditEntityType {
  TENANT = 'TENANT',
  USER = 'USER',
  PRODUCT = 'PRODUCT',
  PRODUCT_VERSION = 'PRODUCT_VERSION',
  QUOTE = 'QUOTE',
  POLICY = 'POLICY',
  CLAIM = 'CLAIM',
  UW_CASE = 'UW_CASE',
  PAYOUT = 'PAYOUT',
  RULE = 'RULE',
  WORKFLOW = 'WORKFLOW',
}

// ── Workflow Type ─────────────────────────────────────────────────────────────
export enum WorkflowType {
  UNDERWRITING = 'UNDERWRITING',
  CLAIM = 'CLAIM',
  PAYOUT = 'PAYOUT',
  POLICY_ISSUANCE = 'POLICY_ISSUANCE',
  RENEWAL = 'RENEWAL',
}
