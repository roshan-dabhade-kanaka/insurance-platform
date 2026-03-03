# Login: Normal flow only

Demo login (role selector chips and mock JWT) has been **removed**. The app uses **normal login only**:

- Sign in with **email** and **password**.
- The backend validates credentials and returns a **signed JWT** with the user’s roles.
- Tab access (sidebar and routes) is driven by the **roles in that JWT** (see `role_access.dart`).
- All API calls (audit logs, fraud, payouts, etc.) send this token and succeed when the user has the right role.

Use the **seeded users** (e.g. `admin@insurance.com` / `Admin@123`) after running the backend and seed. See project docs for full stack setup.
