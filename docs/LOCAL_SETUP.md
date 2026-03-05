# Run the project locally

You can run **only the Admin UI** (no Docker, no database) or the **full stack** (backend + DB). Docker is only needed if you want to run PostgreSQL and the API in containers.

---

## Option 1: Admin UI only (no Docker, no backend)

You can run the Flutter admin app alone; **login is email/password only**. API calls need the backend and a valid JWT.

### Prerequisites

- **Flutter SDK** (3.10+). Install: https://docs.flutter.dev/get-started/install

### Steps

1. Open a terminal in the project root.

2. Go to the admin app and install dependencies:
   ```bash
   cd admin_app
   flutter pub get
   ```

3. Run the app in Chrome (web):
   ```bash
   flutter run -d chrome
   ```
   Or run without specifying device (Flutter will prompt):
   ```bash
   flutter run
   ```

4. In the browser:
   - You'll be redirected to **Login**.
   - Turn on **"Use demo login (role selector)"**.
   - Click a role (e.g. **Admin**, **Underwriter**, **Finance**) to sign in with a mock JWT.
   Sign in with email and password (e.g. seeded user admin@insurance.com / Admin@123). The backend must be running; otherwise login and API calls will fail.

---

## Option 2: Full stack (Backend + Admin UI)

Runs the NestJS API and the Flutter Admin UI. You need **PostgreSQL** running (locally or via Docker). The API **starts without Temporal**; quote/claim workflows need Temporal running (see below).

### Prerequisites

- **Node.js** 18+ and **npm**
- **PostgreSQL** 14+ (local install or Docker)
- **Flutter SDK** (for Admin UI)

### 2a. Start PostgreSQL

**Using Docker (only for the database):**

```bash
docker run -d --name insurance-pg -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=insurance_db -p 5432:5432 postgres:15-alpine
```

**Or** install PostgreSQL on your machine and create a database:

```sql
CREATE DATABASE insurance_db;
```

### 2b. Backend (NestJS API)

1. In the project root, install dependencies and run the API:
   ```bash
   npm install
   npm run start:dev
   ```

2. Optional: copy env and adjust if needed (defaults work for local DB):
   ```bash
   edit `.env` if needed (it already exists in the project)
   ```
   For a **local** PostgreSQL (not Docker), use in `.env`:
   ```env
   DB_HOST=localhost
   DB_PORT=5432
   DB_USERNAME=postgres
   DB_PASSWORD=postgres
   DB_NAME=insurance_db
   PORT=3000
   JWT_SECRET=super-secret-key-change-me
   JWT_EXPIRATION=3600s
   ```

3. API will be at:
   - **API base:** http://localhost:3000/api  
   - **Swagger docs:** http://localhost:3000/docs  

### 2c. (Optional) Run Temporal for full workflows

Quote and claim workflows (create quote, submit claim, underwriting, payout) use **Temporal**. Without it, the API runs but starting a quote or claim workflow will fail.

**Option A – Run Temporal with Docker (recommended for full project):**

```bash
docker compose -f docker-compose.temporal.yml up -d
```

Then start the API as in 2b. Temporal will be at `localhost:7233` (default in `.env`).

**Option B – Run API without Temporal:**

In `.env` set:

```env
TEMPORAL_ENABLED=false
```

Then `npm run start:dev` will start the API without connecting to Temporal. All endpoints work except starting quote/claim workflows.

### 2d. Admin UI (Flutter)

1. In another terminal:
   ```bash
   cd admin_app
   flutter pub get
   flutter run -d chrome
   ```

2. Point the app at your API (see `admin_app/lib/core/constants.dart`; default is `http://localhost:3000/api`). To use the **real backend** instead of only demo login:
   - Leave "Use demo login" **off** and sign in with email/password (backend must expose `POST /api/auth/login` and return a JWT),  
   Sign in with email/password; all tabs call the API with the JWT from login.

---

## Summary

| Goal                         | Docker? | What to run                                      |
|-----------------------------|--------|---------------------------------------------------|
| Just try the Admin UI       | No     | `cd admin_app && flutter pub get && flutter run -d chrome` |
| Backend + Admin UI           | Optional (only for Postgres) | Postgres → `npm run start:dev` → `cd admin_app && flutter run -d chrome` |
| Full project (with workflows) | Yes (Temporal) | Postgres → `docker compose -f docker-compose.temporal.yml up -d` → `npm run start:dev` → Flutter |

- **Without Temporal:** set `TEMPORAL_ENABLED=false` in `.env`; the API starts and all non-workflow endpoints work.
- **With Temporal:** run `docker compose -f docker-compose.temporal.yml up -d`, then start the API; quote/claim workflows will work.
