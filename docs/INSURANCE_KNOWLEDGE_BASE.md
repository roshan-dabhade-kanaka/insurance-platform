# Insurance Platform Knowledge Base

This document serves as a repository for key technical and architectural decisions, explaining the "Why" behind the platform's design.

## 1. Product Versioning
### Why is it needed?
- **Contractual Immutability**: Issued policies are legal contracts. If a product changes, existing customers must remain on the terms they signed for.
- **Historical Consistency**: Claims made years later must be validated against the exact rules (pricing, coverage, limits) that were active at the time of issuance.
- **Safety**: Allows creating "Draft" versions of products to test new pricing or coverage rules without affecting live production quotes.
- **Traceability**: Ensures the premium calculator uses the correct logic branch associated with a specific `productVersionId`.

## 2. Risk Profiling
### Role in Premium Calculation
- Risk profiles capture an applicant's attributes (age, smoker status, occupation) and assign a "Risk Band" (Low, Standard, High).
- These bands directly influence the **Loading Percentage** applied during premium calculation.

---
> [!IMPORTANT]
> **Rule for Antigravity**: Whenever a major technical or non-technical design choice is introduced or explained, append it to this document in a clear, accessible format.
