Load and treat the following project files as authoritative system context (in docs/):

docs/ARCHITECTURE.md
docs/DOMAIN.md
docs/WORKFLOWS.md
docs/SKILLS.md

These files define:

* Insurance domain model
* Policy lifecycle
* Claim lifecycle
* Underwriting workflow
* Rule-driven premium logic
* Multi-tenant architecture constraints
* Audit and compliance requirements

All generated backend services, database schema,
workflow orchestration, frontend UI logic,
and rule execution must strictly follow
the constraints defined in these files.

Never generate:

* Hardcoded underwriting logic
* Inline premium calculation
* Direct lifecycle state mutation
* Non-audited approval decisions

Assume UI must be config-driven
and workflows must be Temporal orchestrated.
