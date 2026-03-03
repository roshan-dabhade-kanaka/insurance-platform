# InsureAdmin — Tabs, Flow & Role Access

## How the flow works

1. **Login** → User signs in with email/password. Backend returns a JWT; the app decodes it and gets the user’s **roles**.
2. **Router** → `GoRouter` checks:
   - Not logged in → redirect to **Login** (except when already on `/login`).
   - Logged in and on `/login` → redirect to **Dashboard** (`/`).
   - Logged in and on any other path → **role check**: if the user’s role is not allowed for that path, redirect to **Dashboard**.
3. **Sidebar** → Only **tabs the user is allowed to see** (by role) are shown. Clicking a tab navigates to that route; the router enforces the same role rules.
4. **Content** → Each route renders one main page (e.g. Dashboard, Quote Lifecycle, Underwriting Decision). That page is “the tab” for that URL.

So: **one tab = one route = one page**. The sidebar lists allowed routes; the router decides if the current path is allowed for the current user.

---

## What each tab is responsible for

| Tab | Route | Responsibility / Use case |
|-----|--------|----------------------------|
| **Dashboard** | `/` | Executive summary: KPIs (active policies, premiums, pending claims, UW queue), premium trends. Entry point after login. |
| **Product Configuration** | `/product-configuration` | Manage product catalog / product config list. |
| **Coverage Setup** | `/coverage-setup` | Define and manage coverage options for products. |
| **Rule Configuration** | `/rule-configuration` | Configure business rules (eligibility, pricing, etc.). |
| **Risk Profiling** | `/risk-profiling` | Capture and view risk factors for quotes/underwriting. |
| **Premium Calculation** | `/premium-calculation` | View/run premium calculation and breakdown. |
| **Create Quote** | `/quote-creation` | Create new quotes (start of quote → policy flow). |
| **Quote Lifecycle** | `/quote-lifecycle` | Track and manage quote status through its lifecycle. |
| **Underwriting Decision** | `/underwriting-decision` | Review cases and make approve/refer/decline decisions. |
| **Policy Issuance** | `/policy-issuance` | Issue policies from approved quotes. |
| **Claim Submission** | `/claim-submission` | Submit new claims (customer/agent). |
| **Claim Investigation** | `/claim-investigation` | Investigate and work claims. |
| **Fraud Review** | `/fraud-review` | Review claims for fraud. |
| **Assessment** | `/assessment` | Claim assessment (e.g. liability, payout). |
| **Finance Payout Approval** | `/finance-payout-approval` | Approve or reject payout requests. |
| **Compliance Audit Logs** | `/compliance-audit-logs` | View audit trail (who did what, when). |
| **User Management** | `/user-management` | Manage users and roles (admin). |
| **Tenant Management** | `/tenant-management` | Manage tenants (multi-tenant admin). |
| **Report Generation** | `/report-generation` | Generate and download reports. |
| **Product Builder** | `/product-builder` | Build/configure insurance products (enterprise product builder). |
| **Pricing Rule Engine** | `/pricing-rule-engine` | Configure pricing rules. |
| **Workflow Configurator** | `/workflow-configurator` | Define approval workflows. |
| **Lifecycle State Editor** | `/lifecycle-state-editor` | Edit quote/policy/claim lifecycle states. |
| **SLA Monitoring** | `/sla-monitoring` | Monitor SLAs and deadlines. |
| **Document Template Manager** | `/document-template-manager` | Manage document templates. |
| **Notification Configuration** | `/notification-configuration` | Configure notifications. |

---

## Which user role gets which tab access

Defined in `lib/auth/role_access.dart`. **Empty list = all authenticated users** (e.g. Dashboard).

| Role | Tabs they can access (in addition to Dashboard) |
|------|--------------------------------------------------|
| **Admin** | All tabs (Product Config, Coverage, Rules, Risk, Premium, Create Quote, Quote Lifecycle, Underwriting, Policy Issuance, Claim Submission, Claim Investigation, Fraud Review, Assessment, Finance Payout, Compliance Audit, User Management, Tenant Management, Reports, Product Builder, Pricing Rule Engine, Workflow Configurator, Lifecycle Editor, SLA, Document Templates, Notifications). |
| **Agent** | Create Quote, Quote Lifecycle, Policy Issuance, Claim Submission. |
| **Underwriter** | Risk Profiling, Premium Calculation, Quote Lifecycle, Underwriting Decision. |
| **Senior Underwriter** | Same as Underwriter. |
| **Claims Officer** | Claim Investigation, Assessment. |
| **Fraud Analyst** | Claim Investigation, Fraud Review. |
| **Finance Officer** | Finance Payout Approval. |
| **Compliance Officer** | Compliance Audit Logs. |
| **Customer** | Claim Submission only. |

Summary by tab:

- **Dashboard** — All roles.
- **Product Configuration, Coverage Setup, Rule Configuration** — Admin only.
- **Risk Profiling, Premium Calculation** — Underwriter, Senior Underwriter, Admin.
- **Create Quote** — Agent, Admin.
- **Quote Lifecycle** — Agent, Underwriter, Senior Underwriter, Admin.
- **Underwriting Decision** — Underwriter, Senior Underwriter, Admin.
- **Policy Issuance** — Agent, Admin.
- **Claim Submission** — Customer, Agent, Admin.
- **Claim Investigation** — Claims Officer, Fraud Analyst, Admin.
- **Fraud Review** — Fraud Analyst, Admin.
- **Assessment** — Claims Officer, Admin.
- **Finance Payout Approval** — Finance Officer, Admin.
- **Compliance Audit Logs** — Compliance Officer, Admin.
- **User Management, Tenant Management, Report Generation, Product Builder, Pricing Rule Engine, Workflow Configurator, Lifecycle State Editor, SLA Monitoring, Document Template Manager, Notification Configuration** — Admin only.

---

## End-to-end flow (conceptual)

- **Quote flow:** Create Quote (Agent) → Quote Lifecycle (Agent/UW) → Underwriting Decision (UW) → Policy Issuance (Agent).
- **Claim flow:** Claim Submission (Customer/Agent) → Claim Investigation (Claims/Fraud) → Fraud Review (if needed) → Assessment → Finance Payout Approval.
- **Governance:** Compliance Audit Logs (Compliance/Admin); User/Tenant and product/workflow/config (Admin).

If you want, we can next map these tabs to specific backend APIs or add a one-line “backend endpoint” column to the table.
