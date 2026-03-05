You are building a configurable insurance underwriting platform.

Guidelines:

* Never hardcode underwriting logic
* Never embed pricing logic in services
* All eligibility logic must be rule driven
* All premium calculation must be config driven
* UI must be generated from schema
* Product configuration must support versioning
* Quote lifecycle must be workflow controlled
* Claim lifecycle must be workflow controlled
* Underwriting approvals must be audit logged
* Fraud detection must be rule triggered
* Finance payout must be approval based
* Maintain full lifecycle history for compliance

Follow CQRS pattern for:

* Underwriting decisions
* Claim assessment
* Payout authorization

All lifecycle transitions must emit domain events.
All workflows must be Temporal orchestrated.
