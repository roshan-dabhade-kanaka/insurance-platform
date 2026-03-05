NEW POLICY PURCHASE WORKFLOW:

Product Selection
→ Coverage Configuration
→ Risk Profiling
→ Premium Calculation
→ Quote Generation
→ Underwriting Review
→ Approval
→ Policy Issuance

Underwriting Trigger:

* Risk score exceeds threshold
* High coverage selected
* Special rider selected

Approval Rule:
IF risk_score > 80
THEN require Senior Underwriter Approval

CLAIM WORKFLOW:

Claim Submission
→ Validation
→ Investigation
→ Fraud Review (if flagged)
→ Assessment
→ Approval / Rejection
→ Finance Review
→ Payout
→ Closure

Claim Validation Rules:
IF policy_status != ACTIVE THEN reject claim
IF claim_date < waiting_period THEN reject claim

Fraud Detection Rules:
IF claim_amount > 3x average THEN fraud review
IF claims_in_last_12_months > 3 THEN escalate

Workflow Requirements:

* Support retry logic
* Support concurrent edits
* Support claim reopening
* Support partial payout
* Lock premium snapshot after issuance
