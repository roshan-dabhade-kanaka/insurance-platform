// =============================================================================
// Temporal Retry Policies — Insurance Platform
// Reusable retry configurations for activities across Quote and Claim workflows.
// =============================================================================

import { RetryPolicy } from '@temporalio/common';

// ─────────────────────────────────────────────────────────────────────────────
// Standard — 3 attempts, exponential backoff, 1s → 30s.
// Use for: non-critical activities with recoverable errors.
// ─────────────────────────────────────────────────────────────────────────────
export const standardRetryPolicy: RetryPolicy = {
    initialInterval: '1s',
    maximumInterval: '30s',
    backoffCoefficient: 2,
    maximumAttempts: 3,
    nonRetryableErrorTypes: [
        'ValidationError',
        'IneligibleApplicantError',
        'DuplicateClaimError',
        'PolicyNotFoundError',
        'PolicyCancelledError',
    ],
};

// ─────────────────────────────────────────────────────────────────────────────
// Aggressive — 5 attempts, short intervals.
// Use for: DB writes, idempotent state updates.
// ─────────────────────────────────────────────────────────────────────────────
export const aggressiveRetryPolicy: RetryPolicy = {
    initialInterval: '500ms',
    maximumInterval: '10s',
    backoffCoefficient: 2,
    maximumAttempts: 5,
    nonRetryableErrorTypes: ['ValidationError', 'PolicyNotFoundError'],
};

// ─────────────────────────────────────────────────────────────────────────────
// Resilient — 10 attempts, longer cap.
// Use for: external integrations (payment gateways, rule engines, fraud APIs).
// ─────────────────────────────────────────────────────────────────────────────
export const resilientRetryPolicy: RetryPolicy = {
    initialInterval: '2s',
    maximumInterval: '2m',
    backoffCoefficient: 2,
    maximumAttempts: 10,
    nonRetryableErrorTypes: [
        'ValidationError',
        'FraudRuleConfigError',
        'PolicyNotFoundError',
        'ClaimAlreadyPaidError',
    ],
};

// ─────────────────────────────────────────────────────────────────────────────
// No Retry — exactly once.
// Use for: lock acquisition (optimistic), audit log writes, notification sends.
// Re-running would cause duplicates or double-notifications.
// ─────────────────────────────────────────────────────────────────────────────
export const noRetryPolicy: RetryPolicy = {
    maximumAttempts: 1,
};

// ─────────────────────────────────────────────────────────────────────────────
// Finance Payout — payment disbursement must be idempotent.
// Use for: payout disbursement activities with idempotency key.
// ─────────────────────────────────────────────────────────────────────────────
export const payoutRetryPolicy: RetryPolicy = {
    initialInterval: '5s',
    maximumInterval: '5m',
    backoffCoefficient: 2,
    maximumAttempts: 7,
    nonRetryableErrorTypes: [
        'InvalidAccountError',
        'AccountFrozenError',
        'ClaimAlreadyPaidError',
    ],
};

// ─────────────────────────────────────────────────────────────────────────────
// Activity Start-to-Close Timeouts
// ─────────────────────────────────────────────────────────────────────────────
export const ActivityTimeouts = {
    /** Short DB-backed activities */
    short: { startToCloseTimeout: '30s' },

    /** Rule engine evaluations — may need time for complex JSONB traversal */
    ruleEvaluation: { startToCloseTimeout: '60s' },

    /** External integrations — fraud API, payment gateway */
    external: { startToCloseTimeout: '2m' },

    /** Human-task signal waits — underwriter / finance team decisions */
    humanTask: {
        scheduleToCloseTimeout: '72h',   // 3-day SLA window
        startToCloseTimeout: '72h',
    },

    /** Investigation — investigator completes findings */
    investigation: {
        scheduleToCloseTimeout: '14d',   // 14-day investigation SLA
        startToCloseTimeout: '14d',
    },
} as const;
