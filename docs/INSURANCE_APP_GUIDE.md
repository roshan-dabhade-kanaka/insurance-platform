# Insurance App — Comprehensive Flow & Tab Guide

This guide explains the **Step-by-Step Flow** of the application. Follow this sequence exactly to ensure data dependencies are met.

---

## 🚀 The Essential Flow: Direct Paths
1.  **Define Product** (Product Configuration)
2.  **Define Version** (Product Configuration -> `+` Button)
3.  **Define Coverage** (Coverage Setup)
4.  **Define Rules** (Rule Configuration)
5.  **Create Quote** (Create Quote)
6.  **Calculate Premium** (Premium Calculation - *Optional Simulator*)
7.  **Underwriting Approval** (Underwriting Decision)
8.  **Policy Generation** (Policy Issuance)

> [!IMPORTANT]
> **Claim Submission** is the **LAST** step in the lifecycle. You cannot submit a claim until a **Policy** is issued. It is NOT needed for creating a quote.

---

## 📂 Tab-by-Tab Explanation

### 1. Product Configuration (Setup)
*The blueprint of what you are selling.*
- **Fields**:
    - `Product Name`: The brand name (e.g., "Term Life").
    - `Product Code`: Backend identifier (e.g., `TL_001`).
- **Critical Action**: You **MUST** click the `+` icon on a product to create a **Version** (e.g., `v1`). All logic (coverages/rules) is tied to the Version ID.

### 2. Coverage Setup (Benefits)
*What specific items are covered within a version?*
- **Fields**:
    - `Coverage Name`: e.g., "Accidental Death Benefit".
    - `Coverage Code`: Unique ID for the rule engine (e.g., `ACC_DEATH`).
    - `Min/Max Sum Insured`: The legal limits for this benefit. (e.g., Min 10,000, Max 1,000,000).

### 3. Rule Configuration (Logic)
*The "Brain" of the product.*
- **Eligibility Rules**: Logic deciding **IF** someone can buy (e.g., `Age > 18`).
- **Pricing Rules**: Logic deciding **HOW MUCH** it costs.
    - **Use Case**: This is where the `Sum Insured` from the quote is used. The rule might say `Premium = SumInsured * 0.05`.

### 4. Create Quote (Entry Point)
*Entering a real customer's data.*
- **Fields**:
    - `Customer Name/Email`: Who is buying?
    - `Sum Insured`: **The most important field.** This is the value requested by the customer. It is passed into the rule engine to calculate the final price.
- **Result**: Generates a **Quote ID**.

### 5. Premium Calculation (Simulator & Verification)
*A tool to "preview" or "test" the price for a quote.*
- **Usecase**: If you just created a quote and want to see the price breakdown *before* proceeding.
- **New Feature: Fact Check**: The interface now displays a "Fact Check" panel which shows exactly which **Sum Insured** and **Applicant Email** are being used for the calculation. This ensures transparency.
- **Next Step**: After values appear here, they are "saved" as a snapshot to the quote. You will see a **"Proceed to Underwriting"** button appear—click it to move directly to the approval stage.

### 6. Underwriting Decision (Approval)
*Reviewing the quote risk.*
- **Action**: Change status from `DRAFT` or `SUBMITTED` to `APPROVED`.
- **Note**: Only `APPROVED` quotes can be turned into policies.

### 7. Policy Issuance (Finalization)
*The contract is signed.*
- **Action**: Select the `APPROVED` quote and click **Issue Policy**.
- **Result**: You now have a **Policy ID**.

---

## ❓ Frequently Asked Questions

**Q: Where did the value go after Premium Calculation?**
A: It is attached to the `Quote`. Once calculated, the quote state is updated. You can see the result in the **Quote Lifecycle** tab or move directly to **Underwriting**.

**Q: Is Sum Insured used in the logic?**
A: **Yes.** It is a core "Fact" in the pricing rule. If your rule says `rate * value`, it uses the Sum Insured as the `value`.

**Q: Do I need Claims first?**
A: **No.** Claims are only for people who already have a **Policy**. Ignore the Claim tabs for now.
