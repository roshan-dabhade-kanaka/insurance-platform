# InsureFlow Enterprise Platform

A comprehensive insurance management system for handling the entire lifecycle of products, policies, and claims.

> All development prompts used to build this project are documented in [`prompts.log`](./Prompts/prompts.log). It includes the initial architecture planning prompts, UI generation prompts, backend service prompts, and all daily task and debugging prompts from the session history.

## 🚀 How to Start the Project

### 1. Backend (NestJS)
1. **Navigate to the root directory.**
2. **Install Dependencies**:
   ```bash
   npm install
   ```
3. **Setup Database**: Ensure PostgreSQL is running and you have a `.env` file with correct credentials.
4. **Run in Development Mode**:
   ```bash
   npm run start:dev
   ```
   *The API will be live at `http://localhost:3000`.*

### 2. Frontend (Flutter Admin Web)
1. **Navigate to the `admin_app` directory.**
2. **Install Flutter Dependencies**:
   ```bash
   flutter pub get
   ```
3. **Run for Web**:
   ```bash
   flutter run -d chrome
   ```

---

## ⚙️ Temporal Workflow Engine
Currently, **Temporal is disabled** (or not attached) for local development to simplify the environment setup. 
*   **Fallback Handling**: The application includes a robust fallback mechanism. Lifecycle transitions and background tasks are handled synchronously/directly via standard service calls rather than being queued in Temporal.
*   To enable it, set `TEMPORAL_ENABLED=true` in the `.env` file and ensure the Temporal server is running.

---

## 🔐 Role-Based Access Control (RBAC)

The platform uses strict role-based access. Below is the mapping of which roles can access specific functional tabs:

| Role | Access Permissions |
| :--- | :--- |
| **Admin** | **Full Access**: Can see and manage everything in the system. |
| **Agent** | Quote Creation, Quote Lifecycle, Policy Issuance, and Claim Submission. |
| **Underwriter** | Risk Profiling, Premium Calculation, Underwriting Decisions, and Quote Lifecycle. |
| **Claims Officer** | Claim Investigation and Assessment. |
| **Fraud Analyst** | Claim Investigation and Fraud Review. |
| **Finance Officer** | Finance Payout Approvals. |
| **Compliance Officer**| Compliance Audit Logs. |
| **Customer** | Claim Submission (Portal access only). |

---

## 🛠️ Workflow Groups (The "Flow" Tabs)

The application is structured into four logical groupings to help users follow the insurance lifecycle:

### 1. Product Setup
*   **What it does**: This is the "Factory" of the app.
*   **Flow**: Admins define what an insurance product is (e.g., Term Life), what it covers (Death, Critical Illness), and the rules for who can buy it.

### 2. New Policy Purchase Workflow
*   **What it does**: Handles the journey from a prospect to a policyholder.
*   **Flow**:
    1.  **Risk Profiling**: Assess the applicant's risk.
    2.  **Premium Calculation**: Determine the cost using the rule engine.
    3.  **Quote Creation**: Formalize the offer.
    4.  **Underwriting**: A human expert reviews and makes a final decision.
    5.  **Policy Issuance**: The legal contract is generated and issued.

### 3. Insurance Claim Workflow
*   **What it does**: Manages what happens when something goes wrong.
*   **Flow**:
    1.  **Claim Submission**: The user uploads documents and details.
    2.  **Investigation**: Staff verify the facts of the incident.
    3.  **Fraud Review**: Automated and manual checks for suspicious patterns.(not implemented till now)
    4.  **Assessment**: Determine the final approved payout amount.
    5.  **Finance Payout**: Final accounting approval before money is transferred.

### 4. Administration & Reporting
*   **What it does**: System oversight and data analysis.
*   **Flow**:
    1.  **Compliance Audit**: Track every single button click and state change in the system for legal transparency.
    2.  **User/Tenant Management**: Manage who has access to the platform.
    3.  **Report Generation**: Export performance data and claim summaries to PDF or Excel.
