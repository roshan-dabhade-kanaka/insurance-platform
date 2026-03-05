# Quote flow: complete setup so it works

The **Create Quote** screen needs at least one **product** so the "Select Product" dropdown has options. If you open Create Quote with no products in the system, the dropdown has nothing to show and will not work. Follow this order.

---

## 1. Backend and login

- **Backend** (NestJS API) and **PostgreSQL** must be running.  
  See **docs/LOCAL_SETUP.md** for how to start them.
- **Admin UI**: run from `admin_app` with `flutter run -d chrome`.
- **Login** with a user that has **Admin** (or a role that can access **Product Configuration** and **Create Quote**).  
  Example: **admin@insurance.com** (and the password you set in seed).  
  If using **demo login**, pick **Admin**.

---

## 2. Create a product first (Admin)

1. After login, open **Product Configuration** from the sidebar (or go to **Create Quote** and use the **"Go to Product Configuration"** button if you see "No products yet").
2. Click the **+** (Add) button to open **Add New Product**.
3. Fill in:
   - **Product Name** (e.g. "Life Safeguard", "Auto Basic").
   - **Category**: Health, Auto, Life, or Home.
4. Click **Create**.  
   The app calls `POST /products`; the new product appears in the list. You can create more if you want.

---

## 3. Create a quote (Agent or Admin)

1. Go to **Create Quote** from the sidebar.
2. You should now see **Select Product** with your product(s) in the dropdown (e.g. "Life Safeguard (uuid)").
3. Choose a product, then fill:
   - First Name, Last Name, Email
   - Coverage Option ID (mock value is pre-filled; replace when you have real coverage setup)
   - Sum Insured (number)
4. Click **Generate Quote**.  
   The app calls the quote API; on success you get "Quote created successfully!".

---

## 4. Rest of the quote → policy flow

After the quote is created:

1. **Quote Lifecycle** — see the quote and its status (e.g. Draft, Submitted).
2. **Underwriting Decision** — log in as Underwriter (e.g. uw@insurance.com), find the quote, Approve / Refer / Decline.
3. **Policy Issuance** — log in as Agent (or Admin), find the approved quote, and issue the policy.

---

## Summary

| Step | Who        | Where                  | Action                          |
|------|------------|------------------------|---------------------------------|
| 1    | Admin      | Product Configuration  | Add at least one product        |
| 2    | Agent/Admin| Create Quote           | Select product, fill form, Generate Quote |
| 3    | —          | Quote Lifecycle        | Check status                    |
| 4    | Underwriter| Underwriting Decision  | Approve / Refer / Decline       |
| 5    | Agent/Admin| Policy Issuance        | Issue policy from approved quote |

If **Select Product** is empty or the dropdown does not open, go to **Product Configuration** and create a product first; then try Create Quote again.
