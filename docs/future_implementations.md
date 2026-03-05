# Future Implementations & Deferred Features

This document tracks technical debt, skipped features, or future enhancements identified during development.

## Policy Module
- [ ] **Policy Conditions**: Implement UI for adding specific conditions/exclusions during issuance (backend DTO and service already support this via `conditions` array).
- [ ] **Document Preview**: Add a preview modal for the generated policy document before final issuance.
- [ ] **Temporal Workflow Visualization**: Add a "view progress" link to track the policy issuance workflow in the Temporal UI.

## Quote Module
- [ ] **Multi-Select for Bulk Actions**: Allow selecting multiple quotes for bulk approval or rejection.
- [ ] **Draft Auto-Save**: Implement auto-saving of quote drafts in the `QuoteCreationPage`.

## Underwriting
- [ ] **Collaborative Review**: Allow multiple underwriters to add comments/notes to a quote before approval.
- [ ] **Risk Score Breakdown**: Display the detailed breakdown of the risk score (factor by factor) in the `UnderwritingDecisionPage`.
