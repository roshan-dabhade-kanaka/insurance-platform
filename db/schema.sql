-- =============================================================================
-- Insurance Policy Configuration & Underwriting Platform
-- PostgreSQL DDL Schema
-- Stack: NestJS · TypeORM · Temporal · json-rules-engine
-- =============================================================================
-- Usage:
--   psql -U postgres -d insurance_dev -f db/schema.sql
--
-- Requires PostgreSQL 14+ (uuid_generate_v4 / gen_random_uuid, JSONB, partitioning)
-- =============================================================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";   -- gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS "pg_trgm";    -- text search on claim/quote numbers

-- =============================================================================
-- SECTION 0 — Enum Types
-- =============================================================================

CREATE TYPE quote_status AS ENUM (
  'DRAFT','PENDING_ELIGIBILITY','ELIGIBLE','INELIGIBLE',
  'RATED','PRESENTED','ACCEPTED','DECLINED','EXPIRED'
);

CREATE TYPE policy_status AS ENUM (
  'PENDING_ISSUANCE','IN_FORCE','LAPSED','SUSPENDED',
  'CANCELLED','EXPIRED','REINSTATED','MATURED'
);

CREATE TYPE claim_status AS ENUM (
  'SUBMITTED','VALIDATED','VALIDATION_FAILED','UNDER_INVESTIGATION',
  'FRAUD_REVIEW','ASSESSED','APPROVED','PARTIALLY_PAID','PAID',
  'REJECTED','CLOSED','REOPENED','WITHDRAWN'
);

CREATE TYPE underwriting_status AS ENUM (
  'PENDING','IN_REVIEW','REFERRED','APPROVED',
  'DECLINED','CONDITIONALLY_APPROVED','CANCELLED'
);

CREATE TYPE uw_decision_outcome AS ENUM (
  'APPROVE','DECLINE','REFER','REQUEST_INFO','CONDITIONALLY_APPROVE'
);

CREATE TYPE payout_status AS ENUM (
  'PENDING_APPROVAL','PARTIALLY_APPROVED','APPROVED',
  'REJECTED','DISBURSED','PARTIALLY_DISBURSED','FAILED','CANCELLED'
);

CREATE TYPE disbursement_status AS ENUM (
  'SCHEDULED','PROCESSING','DISBURSED','FAILED','CANCELLED'
);

CREATE TYPE risk_band AS ENUM ('LOW','STANDARD','HIGH','DECLINED');

CREATE TYPE fraud_severity AS ENUM ('LOW','MEDIUM','HIGH','CRITICAL');

CREATE TYPE fraud_review_outcome AS ENUM ('CLEAR','FLAGGED','REFERRED','ESCALATED');

CREATE TYPE claim_validation_status AS ENUM ('PASS','FAIL','WARNING');

CREATE TYPE claim_validation_type AS ENUM (
  'COVERAGE_CHECK','DEDUCTIBLE_CHECK','POLICY_STATUS_CHECK',
  'DUPLICATE_CHECK','DATE_RANGE_CHECK','LIMIT_CHECK','ELIGIBILITY_CHECK'
);

CREATE TYPE investigation_status AS ENUM (
  'OPEN','IN_PROGRESS','PENDING_RESPONSE','COMPLETED','CLOSED'
);

CREATE TYPE approval_decision AS ENUM ('PENDING','APPROVED','REJECTED','ESCALATED');

CREATE TYPE product_version_status AS ENUM ('DRAFT','ACTIVE','DEPRECATED','ARCHIVED');

CREATE TYPE audit_entity_type AS ENUM (
  'TENANT','USER','PRODUCT','PRODUCT_VERSION','QUOTE',
  'POLICY','CLAIM','UW_CASE','PAYOUT','RULE','WORKFLOW'
);

CREATE TYPE workflow_type AS ENUM (
  'UNDERWRITING','CLAIM','PAYOUT','POLICY_ISSUANCE','RENEWAL'
);

CREATE TYPE tenant_plan_tier AS ENUM ('STARTER','PROFESSIONAL','ENTERPRISE');

CREATE TYPE user_status AS ENUM (
  'ACTIVE','INACTIVE','SUSPENDED','PENDING_VERIFICATION'
);

CREATE TYPE endorsement_type AS ENUM (
  'COVERAGE_CHANGE','BENEFICIARY_CHANGE','ADDRESS_CHANGE',
  'PREMIUM_ADJUSTMENT','POLICY_CORRECTION'
);

CREATE TYPE endorsement_status AS ENUM ('DRAFT','APPROVED','APPLIED','REJECTED');

CREATE TYPE product_type AS ENUM (
  'LIFE','HEALTH','AUTO','HOME','TRAVEL','LIABILITY','COMMERCIAL'
);

-- =============================================================================
-- SECTION 1 — Tenants & Subscription Plans
-- =============================================================================

CREATE TABLE tenants (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  name           VARCHAR(200) NOT NULL,
  slug           VARCHAR(100) NOT NULL UNIQUE,
  config         JSONB       NOT NULL DEFAULT '{}',
  is_active      BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_tenants_slug ON tenants (slug);

CREATE TABLE tenant_plans (
  id              UUID             PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID             NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  tier            tenant_plan_tier NOT NULL DEFAULT 'STARTER',
  max_users       INT              NOT NULL DEFAULT 10,
  max_products    INT              NOT NULL DEFAULT 5,
  features        JSONB            NOT NULL DEFAULT '{}',
  effective_from  DATE             NOT NULL,
  effective_to    DATE,
  is_active       BOOLEAN          NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ      NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ      NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_tenant_plans_tenant_active ON tenant_plans (tenant_id, is_active);

-- =============================================================================
-- SECTION 2 — Identity & Access Management (IAM)
-- =============================================================================

CREATE TABLE permissions (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   UUID        NOT NULL REFERENCES tenants (id) ON DELETE CASCADE,
  resource    VARCHAR(100) NOT NULL,
  action      VARCHAR(100) NOT NULL,
  description VARCHAR(300),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (tenant_id, resource, action)
);

CREATE TABLE roles (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id      UUID        NOT NULL REFERENCES tenants (id) ON DELETE CASCADE,
  name           VARCHAR(100) NOT NULL,
  description    VARCHAR(300),
  is_system_role BOOLEAN     NOT NULL DEFAULT FALSE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (tenant_id, name)
);

CREATE TABLE role_permissions (
  role_id       UUID NOT NULL REFERENCES roles (id) ON DELETE CASCADE,
  permission_id UUID NOT NULL REFERENCES permissions (id) ON DELETE CASCADE,
  PRIMARY KEY (role_id, permission_id)
);

CREATE TABLE users (
  id                 UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id          UUID        NOT NULL REFERENCES tenants (id) ON DELETE CASCADE,
  email              VARCHAR(150) NOT NULL,
  first_name         VARCHAR(100) NOT NULL,
  last_name          VARCHAR(100) NOT NULL,
  password_hash      TEXT,
  status             user_status NOT NULL DEFAULT 'PENDING_VERIFICATION',
  temporal_worker_id TEXT,
  metadata           JSONB       NOT NULL DEFAULT '{}',
  last_login_at      TIMESTAMPTZ,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (tenant_id, email)
);

CREATE INDEX idx_users_tenant_status ON users (tenant_id, status);

CREATE TABLE user_roles (
  user_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  role_id UUID NOT NULL REFERENCES roles (id) ON DELETE CASCADE,
  PRIMARY KEY (user_id, role_id)
);

-- =============================================================================
-- SECTION 3 — Product Configuration & Versioning
-- =============================================================================

CREATE TABLE insurance_products (
  id         UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id  UUID         NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  name       VARCHAR(200) NOT NULL,
  code       VARCHAR(80)  NOT NULL,
  type       product_type NOT NULL,
  description TEXT,
  is_active  BOOLEAN      NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  UNIQUE (tenant_id, code)
);

CREATE INDEX idx_insurance_products_tenant_active ON insurance_products (tenant_id, is_active);

CREATE TABLE product_versions (
  id               UUID                   PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id        UUID                   NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  product_id       UUID                   NOT NULL REFERENCES insurance_products (id) ON DELETE RESTRICT,
  version_number   INT                    NOT NULL DEFAULT 1,
  status           product_version_status NOT NULL DEFAULT 'DRAFT',
  effective_from   DATE                   NOT NULL,
  effective_to     DATE,
  changelog        TEXT,
  product_snapshot JSONB                  NOT NULL DEFAULT '{}',
  created_at       TIMESTAMPTZ            NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ            NOT NULL DEFAULT NOW(),
  UNIQUE (tenant_id, product_id, version_number)
);

CREATE INDEX idx_product_versions_tenant_status ON product_versions (tenant_id, status);

CREATE TABLE coverage_options (
  id                 UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id          UUID         NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  product_version_id UUID         NOT NULL REFERENCES product_versions (id) ON DELETE RESTRICT,
  name               VARCHAR(200) NOT NULL,
  code               VARCHAR(100) NOT NULL,
  is_mandatory       BOOLEAN      NOT NULL DEFAULT FALSE,
  min_sum_insured    NUMERIC(14,2),
  max_sum_insured    NUMERIC(14,2),
  parameters         JSONB        NOT NULL DEFAULT '{}',
  created_at         TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_coverage_options_version ON coverage_options (tenant_id, product_version_id);

CREATE TABLE riders (
  id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   UUID         NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  name        VARCHAR(200) NOT NULL,
  code        VARCHAR(100) NOT NULL,
  description TEXT,
  parameters  JSONB        NOT NULL DEFAULT '{}',
  is_active   BOOLEAN      NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  UNIQUE (tenant_id, code)
);

-- M:N product_versions ↔ riders
CREATE TABLE product_version_riders (
  product_version_id UUID NOT NULL REFERENCES product_versions (id) ON DELETE CASCADE,
  rider_id           UUID NOT NULL REFERENCES riders (id) ON DELETE CASCADE,
  PRIMARY KEY (product_version_id, rider_id)
);

CREATE TABLE deductibles (
  id                 UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id          UUID        NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  coverage_option_id UUID        NOT NULL REFERENCES coverage_options (id) ON DELETE CASCADE,
  label              VARCHAR(150) NOT NULL,
  flat_amount        NUMERIC(14,2),
  percentage         NUMERIC(5,2),
  is_default         BOOLEAN     NOT NULL DEFAULT FALSE,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_deductibles_coverage ON deductibles (tenant_id, coverage_option_id);

-- =============================================================================
-- SECTION 4 — Eligibility & Pricing Rules (JSONB / json-rules-engine)
-- =============================================================================

CREATE TABLE eligibility_rules (
  id                 UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id          UUID        NOT NULL REFERENCES tenants (id) ON DELETE CASCADE,
  product_version_id UUID        NOT NULL REFERENCES product_versions (id) ON DELETE CASCADE,
  name               VARCHAR(200) NOT NULL,
  description        TEXT,
  rule_logic         JSONB       NOT NULL,   -- json-rules-engine rule object
  priority           INT         NOT NULL DEFAULT 0,
  is_active          BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_eligibility_rules_version_active ON eligibility_rules (tenant_id, product_version_id, is_active);
CREATE INDEX idx_eligibility_rule_logic_gin ON eligibility_rules USING GIN (rule_logic);

CREATE TABLE pricing_rules (
  id                 UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id          UUID        NOT NULL REFERENCES tenants (id) ON DELETE CASCADE,
  product_version_id UUID        NOT NULL REFERENCES product_versions (id) ON DELETE CASCADE,
  name               VARCHAR(200) NOT NULL,
  rule_expression    JSONB       NOT NULL,   -- factor-based pricing JSONB
  effective_from     DATE,
  effective_to       DATE,
  is_active          BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_pricing_rules_version_active ON pricing_rules (tenant_id, product_version_id, is_active);
CREATE INDEX idx_pricing_rule_expression_gin ON pricing_rules USING GIN (rule_expression);

CREATE TABLE rate_tables (
  id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   UUID         NOT NULL REFERENCES tenants (id) ON DELETE CASCADE,
  code        VARCHAR(100) NOT NULL,
  name        VARCHAR(200) NOT NULL,
  description TEXT,
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  UNIQUE (tenant_id, code)
);

CREATE TABLE rate_table_entries (
  id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     UUID         NOT NULL REFERENCES tenants (id) ON DELETE CASCADE,
  rate_table_id UUID         NOT NULL REFERENCES rate_tables (id) ON DELETE CASCADE,
  band_key      VARCHAR(100) NOT NULL,
  rate          NUMERIC(10,6) NOT NULL,
  metadata      JSONB        NOT NULL DEFAULT '{}',
  created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_rate_table_entries_lookup ON rate_table_entries (tenant_id, rate_table_id, band_key);

CREATE TABLE fraud_rules (
  id           UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id    UUID          NOT NULL REFERENCES tenants (id) ON DELETE CASCADE,
  name         VARCHAR(200)  NOT NULL,
  description  TEXT,
  rule_logic   JSONB         NOT NULL,   -- json-rules-engine fraud detection rules
  severity     fraud_severity NOT NULL DEFAULT 'MEDIUM',
  score_weight INT           NOT NULL DEFAULT 10,
  is_active    BOOLEAN       NOT NULL DEFAULT TRUE,
  created_at   TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_fraud_rules_tenant_active ON fraud_rules (tenant_id, is_active);
CREATE INDEX idx_fraud_rule_logic_gin ON fraud_rules USING GIN (rule_logic);

-- =============================================================================
-- SECTION 5 — Risk Profiling
-- =============================================================================

CREATE TABLE risk_profiles (
  id                 UUID      PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id          UUID      NOT NULL REFERENCES tenants (id) ON DELETE CASCADE,
  applicant_ref      VARCHAR(200) NOT NULL,
  quote_id           UUID,
  profile_data       JSONB     NOT NULL,
  total_score        NUMERIC(7,2),
  risk_band          risk_band,
  loading_percentage NUMERIC(6,2) NOT NULL DEFAULT 0,
  underwriter_notes  TEXT,
  assessed_at        TIMESTAMPTZ,
  assessed_by        UUID REFERENCES users (id),
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_risk_profiles_applicant ON risk_profiles (tenant_id, applicant_ref);
CREATE INDEX idx_risk_profiles_quote     ON risk_profiles (tenant_id, quote_id);

CREATE TABLE risk_factors (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID        NOT NULL REFERENCES tenants (id) ON DELETE CASCADE,
  risk_profile_id UUID        NOT NULL REFERENCES risk_profiles (id) ON DELETE CASCADE,
  factor_name     VARCHAR(150) NOT NULL,
  factor_value    TEXT        NOT NULL,
  score           NUMERIC(7,2) NOT NULL,
  rationale       TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_risk_factors_profile ON risk_factors (tenant_id, risk_profile_id);

-- =============================================================================
-- SECTION 6 — Quote Lifecycle
-- Composite index on (tenant_id, status, created_at DESC) → sub-300ms listing
-- =============================================================================

CREATE TABLE quotes (
  id                   UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id            UUID         NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  quote_number         VARCHAR(50)  NOT NULL UNIQUE,
  product_version_id   UUID         NOT NULL REFERENCES product_versions (id) ON DELETE RESTRICT,
  applicant_ref        VARCHAR(200) NOT NULL,
  applicant_data       JSONB        NOT NULL,
  status               quote_status NOT NULL DEFAULT 'DRAFT',
  expires_at           TIMESTAMPTZ,
  temporal_workflow_id TEXT,
  originated_by        UUID REFERENCES users (id),
  assigned_to          UUID REFERENCES users (id),
  metadata             JSONB        NOT NULL DEFAULT '{}',
  created_at           TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- Critical performance indexes for sub-300ms quote operations
CREATE INDEX idx_quotes_tenant_status_created  ON quotes (tenant_id, status, created_at DESC);
CREATE INDEX idx_quotes_tenant_version_status  ON quotes (tenant_id, product_version_id, status);
CREATE INDEX idx_quotes_tenant_applicant       ON quotes (tenant_id, applicant_ref);
CREATE INDEX idx_quotes_number                 ON quotes (quote_number);

CREATE TABLE quote_line_items (
  id                 UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id          UUID         NOT NULL REFERENCES tenants (id) ON DELETE CASCADE,
  quote_id           UUID         NOT NULL REFERENCES quotes (id) ON DELETE CASCADE,
  coverage_option_id UUID         NOT NULL REFERENCES coverage_options (id),
  rider_id           UUID         REFERENCES riders (id),
  sum_insured        NUMERIC(14,2) NOT NULL,
  deductible_id      UUID         REFERENCES deductibles (id),
  calculated_premium NUMERIC(14,2),
  parameters         JSONB        NOT NULL DEFAULT '{}',
  created_at         TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_quote_line_items_quote ON quote_line_items (tenant_id, quote_id);

CREATE TABLE quote_status_history (
  id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id    UUID         NOT NULL REFERENCES tenants (id) ON DELETE CASCADE,
  quote_id     UUID         NOT NULL REFERENCES quotes (id) ON DELETE CASCADE,
  from_status  quote_status,
  to_status    quote_status NOT NULL,
  reason       TEXT,
  triggered_by UUID         REFERENCES users (id),
  occurred_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  context      JSONB        NOT NULL DEFAULT '{}'
);

CREATE INDEX idx_quote_status_history ON quote_status_history (tenant_id, quote_id, occurred_at);

-- =============================================================================
-- SECTION 7 — Premium Calculation Snapshot
-- =============================================================================

CREATE TABLE premium_snapshots (
  id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id           UUID        NOT NULL REFERENCES tenants (id) ON DELETE CASCADE,
  quote_id            UUID        NOT NULL REFERENCES quotes (id) ON DELETE CASCADE,
  product_version_id  UUID        NOT NULL REFERENCES product_versions (id),
  pricing_rule_id     UUID        REFERENCES pricing_rules (id),
  base_premium        NUMERIC(14,2) NOT NULL,
  rider_surcharge     NUMERIC(14,2) NOT NULL DEFAULT 0,
  risk_loading        NUMERIC(14,2) NOT NULL DEFAULT 0,
  discount_amount     NUMERIC(14,2) NOT NULL DEFAULT 0,
  tax_amount          NUMERIC(14,2) NOT NULL DEFAULT 0,
  total_premium       NUMERIC(14,2) NOT NULL,
  calculation_inputs  JSONB         NOT NULL,
  factor_breakdown    JSONB         NOT NULL DEFAULT '[]',
  calculated_at       TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  calculated_by       UUID          REFERENCES users (id)
);

CREATE INDEX idx_premium_snapshots_quote ON premium_snapshots (tenant_id, quote_id, calculated_at DESC);

-- =============================================================================
-- SECTION 8 — Underwriting Approval Workflow
-- =============================================================================

CREATE TABLE underwriting_cases (
  id                     UUID                NOT NULL DEFAULT gen_random_uuid(),
  tenant_id              UUID                NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  quote_id               UUID                NOT NULL REFERENCES quotes (id) ON DELETE RESTRICT UNIQUE,
  risk_profile_id        UUID                REFERENCES risk_profiles (id),
  status                 underwriting_status NOT NULL DEFAULT 'PENDING',
  assigned_underwriter_id UUID               REFERENCES users (id),
  current_approval_level INT                 NOT NULL DEFAULT 1,
  temporal_workflow_id   TEXT,
  sla_due_at             TIMESTAMPTZ,
  completed_at           TIMESTAMPTZ,
  underwriter_notes      TEXT,
  conditions             JSONB               NOT NULL DEFAULT '[]',
  created_at             TIMESTAMPTZ         NOT NULL DEFAULT NOW(),
  updated_at             TIMESTAMPTZ         NOT NULL DEFAULT NOW(),
  PRIMARY KEY (id)
);

CREATE INDEX idx_uw_cases_tenant_status      ON underwriting_cases (tenant_id, status);
CREATE INDEX idx_uw_cases_underwriter_status ON underwriting_cases (tenant_id, assigned_underwriter_id, status);

-- Optimistic concurrent lock — one active lock per case
CREATE TABLE underwriting_locks (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID        NOT NULL REFERENCES tenants (id) ON DELETE CASCADE,
  case_id         UUID        NOT NULL REFERENCES underwriting_cases (id) ON DELETE CASCADE UNIQUE,
  locked_by       UUID        NOT NULL REFERENCES users (id),
  locked_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  lock_expires_at TIMESTAMPTZ NOT NULL,
  lock_token      UUID        NOT NULL DEFAULT gen_random_uuid(),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Background expiry sweep uses this index
CREATE INDEX idx_uw_locks_expires ON underwriting_locks (lock_expires_at);
CREATE INDEX idx_uw_locks_tenant  ON underwriting_locks (tenant_id, locked_by);

CREATE TABLE underwriting_decisions (
  id                   UUID                NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  tenant_id            UUID                NOT NULL REFERENCES tenants (id) ON DELETE CASCADE,
  underwriting_case_id UUID                NOT NULL REFERENCES underwriting_cases (id) ON DELETE CASCADE,
  approval_level       INT                 NOT NULL,
  decided_by           UUID                NOT NULL REFERENCES users (id),
  outcome              uw_decision_outcome NOT NULL,
  notes                TEXT,
  lock_token_used      UUID,
  decided_at           TIMESTAMPTZ         NOT NULL DEFAULT NOW(),
  created_at           TIMESTAMPTZ         NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ         NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_uw_decisions_case_level ON underwriting_decisions (tenant_id, underwriting_case_id, approval_level);

CREATE TABLE approval_hierarchies (
  id                 UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id          UUID    NOT NULL REFERENCES tenants (id) ON DELETE CASCADE,
  product_version_id UUID    NOT NULL REFERENCES product_versions (id) ON DELETE RESTRICT,
  name               VARCHAR(200) NOT NULL,
  is_active          BOOLEAN NOT NULL DEFAULT TRUE,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_approval_hierarchies ON approval_hierarchies (tenant_id, product_version_id, is_active);

CREATE TABLE approval_hierarchy_levels (
  id                    UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id             UUID         NOT NULL REFERENCES tenants (id) ON DELETE CASCADE,
  hierarchy_id          UUID         NOT NULL REFERENCES approval_hierarchies (id) ON DELETE CASCADE,
  level_number          INT          NOT NULL,
  level_name            VARCHAR(150) NOT NULL,
  required_role_id      UUID         REFERENCES roles (id),
  sum_insured_threshold NUMERIC(14,2),
  risk_band_threshold   VARCHAR(50),
  sla_hours             INT          NOT NULL DEFAULT 24,
  created_at            TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_approval_hierarchy_levels ON approval_hierarchy_levels (hierarchy_id, level_number);

-- =============================================================================
-- SECTION 9 — Policy Issuance & Lifecycle
-- =============================================================================

CREATE TABLE policies (
  id                  UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id           UUID          NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  policy_number       VARCHAR(60)   NOT NULL UNIQUE,
  quote_id            UUID          NOT NULL REFERENCES quotes (id) ON DELETE RESTRICT UNIQUE,
  product_version_id  UUID          NOT NULL REFERENCES product_versions (id) ON DELETE RESTRICT,
  policy_holder_ref   VARCHAR(200)  NOT NULL,
  policy_holder_data  JSONB         NOT NULL,
  status              policy_status NOT NULL DEFAULT 'PENDING_ISSUANCE',
  inception_date      DATE          NOT NULL,
  expiry_date         DATE          NOT NULL,
  annual_premium      NUMERIC(14,2) NOT NULL,
  premium_snapshot_id UUID          NOT NULL REFERENCES premium_snapshots (id),
  issued_at           TIMESTAMPTZ,
  issued_by           UUID          REFERENCES users (id),
  temporal_workflow_id TEXT,
  parent_policy_id    UUID          REFERENCES policies (id),   -- for reinstatement chain
  created_at          TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_policies_tenant_status ON policies (tenant_id, status, policy_number);
CREATE INDEX idx_policies_tenant_holder ON policies (tenant_id, policy_holder_ref);

CREATE TABLE policy_coverages (
  id                 UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id          UUID    NOT NULL REFERENCES tenants (id) ON DELETE CASCADE,
  policy_id          UUID    NOT NULL REFERENCES policies (id) ON DELETE CASCADE,
  coverage_option_id UUID    NOT NULL REFERENCES coverage_options (id),
  sum_insured        NUMERIC(14,2) NOT NULL,
  deductible_id      UUID    REFERENCES deductibles (id),
  is_active          BOOLEAN NOT NULL DEFAULT TRUE,
  parameters         JSONB   NOT NULL DEFAULT '{}',
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_policy_coverages_policy ON policy_coverages (tenant_id, policy_id);

CREATE TABLE policy_riders (
  id            UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     UUID    NOT NULL REFERENCES tenants (id) ON DELETE CASCADE,
  policy_id     UUID    NOT NULL REFERENCES policies (id) ON DELETE CASCADE,
  rider_id      UUID    NOT NULL REFERENCES riders (id),
  rider_premium NUMERIC(14,2) NOT NULL DEFAULT 0,
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_policy_riders_policy ON policy_riders (tenant_id, policy_id);

CREATE TABLE policy_status_history (
  id           UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id    UUID          NOT NULL REFERENCES tenants (id) ON DELETE CASCADE,
  policy_id    UUID          NOT NULL REFERENCES policies (id) ON DELETE CASCADE,
  from_status  policy_status,
  to_status    policy_status NOT NULL,
  reason       TEXT,
  triggered_by UUID          REFERENCES users (id),
  occurred_at  TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  context      JSONB         NOT NULL DEFAULT '{}'
);

CREATE INDEX idx_policy_status_history ON policy_status_history (tenant_id, policy_id, occurred_at);

CREATE TABLE policy_endorsements (
  id                UUID              PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id         UUID              NOT NULL REFERENCES tenants (id) ON DELETE CASCADE,
  policy_id         UUID              NOT NULL REFERENCES policies (id) ON DELETE CASCADE,
  endorsement_type  endorsement_type  NOT NULL,
  status            endorsement_status NOT NULL DEFAULT 'DRAFT',
  effective_date    DATE              NOT NULL,
  change_details    JSONB             NOT NULL,
  premium_adjustment NUMERIC(14,2)   NOT NULL DEFAULT 0,
  approved_by       UUID              REFERENCES users (id),
  approved_at       TIMESTAMPTZ,
  notes             TEXT,
  created_at        TIMESTAMPTZ       NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ       NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_endorsements_policy_date ON policy_endorsements (tenant_id, policy_id, effective_date);

-- =============================================================================
-- SECTION 10 — Claim Lifecycle
-- Composite index on (tenant_id, policy_id, status) → sub-200ms claim validation
-- =============================================================================

CREATE TABLE claims (
  id                   UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id            UUID         NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  claim_number         VARCHAR(60)  NOT NULL UNIQUE,
  policy_id            UUID         NOT NULL REFERENCES policies (id) ON DELETE RESTRICT,
  policy_coverage_id   UUID         NOT NULL REFERENCES policy_coverages (id),
  status               claim_status NOT NULL DEFAULT 'SUBMITTED',
  loss_date            DATE         NOT NULL,
  reported_date        DATE         NOT NULL,
  claimed_amount       NUMERIC(14,2) NOT NULL,
  approved_amount      NUMERIC(14,2),
  paid_amount          NUMERIC(14,2) NOT NULL DEFAULT 0,
  loss_description     TEXT         NOT NULL,
  claimant_data        JSONB        NOT NULL,
  temporal_workflow_id TEXT,
  parent_claim_id      UUID         REFERENCES claims (id),   -- self-ref for reopening
  reopen_count         INT          NOT NULL DEFAULT 0,       -- max 3 reopens enforced in service
  submitted_by         UUID         REFERENCES users (id),
  assigned_adjuster_id UUID         REFERENCES users (id),
  created_at           TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- Critical performance indexes for sub-200ms claim validation
CREATE INDEX idx_claims_policy_status       ON claims (tenant_id, policy_id, status);
CREATE INDEX idx_claims_tenant_status_date  ON claims (tenant_id, status, created_at DESC);
CREATE INDEX idx_claims_parent              ON claims (tenant_id, parent_claim_id);
CREATE INDEX idx_claims_number              ON claims (claim_number);

CREATE TABLE claim_items (
  id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID         NOT NULL REFERENCES tenants (id) ON DELETE CASCADE,
  claim_id        UUID         NOT NULL REFERENCES claims (id) ON DELETE CASCADE,
  description     VARCHAR(200) NOT NULL,
  claimed_amount  NUMERIC(14,2) NOT NULL,
  approved_amount NUMERIC(14,2),
  metadata        JSONB        NOT NULL DEFAULT '{}',
  created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_claim_items_claim ON claim_items (tenant_id, claim_id);

CREATE TABLE claim_documents (
  id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     UUID         NOT NULL REFERENCES tenants (id) ON DELETE CASCADE,
  claim_id      UUID         NOT NULL REFERENCES claims (id) ON DELETE CASCADE,
  document_type VARCHAR(100) NOT NULL,
  file_name     VARCHAR(300) NOT NULL,
  s3_key        VARCHAR(500) NOT NULL,
  mime_type     VARCHAR(100) NOT NULL,
  file_size_bytes BIGINT,
  uploaded_by   UUID         NOT NULL REFERENCES users (id),
  created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_claim_documents_claim ON claim_documents (tenant_id, claim_id);

CREATE TABLE claim_status_history (
  id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id    UUID         NOT NULL REFERENCES tenants (id) ON DELETE CASCADE,
  claim_id     UUID         NOT NULL REFERENCES claims (id) ON DELETE CASCADE,
  from_status  claim_status,
  to_status    claim_status NOT NULL,
  reason       TEXT,
  triggered_by UUID         REFERENCES users (id),
  occurred_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  context      JSONB        NOT NULL DEFAULT '{}'
);

CREATE INDEX idx_claim_status_history ON claim_status_history (tenant_id, claim_id, occurred_at);

-- =============================================================================
-- SECTION 11 — Claim Validation
-- =============================================================================

CREATE TABLE claim_validations (
  id                UUID                    PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id         UUID                    NOT NULL REFERENCES tenants (id) ON DELETE CASCADE,
  claim_id          UUID                    NOT NULL REFERENCES claims (id) ON DELETE CASCADE,
  validation_type   claim_validation_type   NOT NULL,
  status            claim_validation_status NOT NULL,
  validation_detail JSONB                   NOT NULL DEFAULT '{}',
  validated_at      TIMESTAMPTZ             NOT NULL DEFAULT NOW(),
  validated_by      UUID                    REFERENCES users (id)
);

CREATE INDEX idx_claim_validations ON claim_validations (tenant_id, claim_id, validation_type);

-- =============================================================================
-- SECTION 12 — Claim Investigation
-- =============================================================================

CREATE TABLE claim_investigations (
  id                      UUID                NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  tenant_id               UUID                NOT NULL REFERENCES tenants (id) ON DELETE CASCADE,
  claim_id                UUID                NOT NULL REFERENCES claims (id) ON DELETE CASCADE,
  assigned_investigator_id UUID               REFERENCES users (id),
  status                  investigation_status NOT NULL DEFAULT 'OPEN',
  investigation_type      VARCHAR(100),
  started_at              TIMESTAMPTZ,
  due_date                DATE,
  completed_at            TIMESTAMPTZ,
  findings                TEXT,
  evidence_summary        JSONB               NOT NULL DEFAULT '[]',
  created_at              TIMESTAMPTZ         NOT NULL DEFAULT NOW(),
  updated_at              TIMESTAMPTZ         NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_claim_investigations_claim       ON claim_investigations (tenant_id, claim_id);
CREATE INDEX idx_claim_investigations_investigator ON claim_investigations (tenant_id, assigned_investigator_id, status);

CREATE TABLE investigation_activities (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID        NOT NULL REFERENCES tenants (id) ON DELETE CASCADE,
  investigation_id UUID       NOT NULL REFERENCES claim_investigations (id) ON DELETE CASCADE,
  activity_type   VARCHAR(100) NOT NULL,
  description     TEXT        NOT NULL,
  performed_by    UUID        NOT NULL REFERENCES users (id),
  performed_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  attachments     JSONB       NOT NULL DEFAULT '{}'
);

CREATE INDEX idx_investigation_activities ON investigation_activities (tenant_id, investigation_id, performed_at);

-- =============================================================================
-- SECTION 13 — Fraud Review
-- =============================================================================

CREATE TABLE fraud_reviews (
  id             UUID                 PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id      UUID                 NOT NULL REFERENCES tenants (id) ON DELETE CASCADE,
  claim_id       UUID                 NOT NULL REFERENCES claims (id) ON DELETE CASCADE,
  overall_score  NUMERIC(5,2)         NOT NULL DEFAULT 0,
  risk_level     fraud_severity,
  review_outcome fraud_review_outcome,
  reviewed_at    TIMESTAMPTZ,
  reviewed_by    UUID                 REFERENCES users (id),
  reviewer_notes TEXT,
  created_at     TIMESTAMPTZ          NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ          NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_fraud_reviews_claim   ON fraud_reviews (tenant_id, claim_id);
CREATE INDEX idx_fraud_reviews_outcome ON fraud_reviews (tenant_id, review_outcome);

CREATE TABLE fraud_review_flags (
  id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id         UUID        NOT NULL REFERENCES tenants (id) ON DELETE CASCADE,
  fraud_review_id   UUID        NOT NULL REFERENCES fraud_reviews (id) ON DELETE CASCADE,
  fraud_rule_id     UUID        NOT NULL REFERENCES fraud_rules (id),
  rule_name         VARCHAR(200) NOT NULL,
  score_contribution NUMERIC(5,2) NOT NULL,
  flag_detail       JSONB       NOT NULL DEFAULT '{}',
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_fraud_review_flags ON fraud_review_flags (tenant_id, fraud_review_id);

-- =============================================================================
-- SECTION 14 — Claim Assessment
-- =============================================================================

CREATE TABLE claim_assessments (
  id                   UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id            UUID         NOT NULL REFERENCES tenants (id) ON DELETE CASCADE,
  claim_id             UUID         NOT NULL REFERENCES claims (id) ON DELETE CASCADE,
  assessed_by          UUID         NOT NULL REFERENCES users (id),
  assessed_amount      NUMERIC(14,2) NOT NULL,
  deductible_applied   NUMERIC(14,2) NOT NULL DEFAULT 0,
  net_payout           NUMERIC(14,2) NOT NULL,
  assessment_notes     TEXT,
  line_item_assessment JSONB        NOT NULL DEFAULT '[]',
  reserve_amount       NUMERIC(14,2),
  assessed_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  created_at           TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_claim_assessments_claim ON claim_assessments (tenant_id, claim_id);

-- =============================================================================
-- SECTION 15 — Finance Payout Approval
-- =============================================================================

CREATE TABLE payout_requests (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id             UUID          NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  claim_id              UUID          NOT NULL REFERENCES claims (id) ON DELETE RESTRICT,
  assessment_id         UUID          NOT NULL REFERENCES claim_assessments (id),
  status                payout_status NOT NULL DEFAULT 'PENDING_APPROVAL',
  total_amount          NUMERIC(14,2)  NOT NULL,
  currency_code         VARCHAR(5)     NOT NULL DEFAULT 'INR',
  payee_details         JSONB          NOT NULL,
  requested_by          UUID           NOT NULL REFERENCES users (id),
  approved_amount       NUMERIC(14,2),
  current_approval_level INT           NOT NULL DEFAULT 1,
  temporal_workflow_id  TEXT,
  created_at            TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ    NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_payout_requests_claim  ON payout_requests (tenant_id, claim_id);
CREATE INDEX idx_payout_requests_status ON payout_requests (tenant_id, status);

CREATE TABLE payout_approvals (
  id               UUID             PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id        UUID             NOT NULL REFERENCES tenants (id) ON DELETE CASCADE,
  payout_request_id UUID            NOT NULL REFERENCES payout_requests (id) ON DELETE CASCADE,
  approval_level   INT              NOT NULL,
  approver_id      UUID             NOT NULL REFERENCES users (id),
  decision         approval_decision NOT NULL DEFAULT 'PENDING',
  approved_amount  NUMERIC(14,2),
  notes            TEXT,
  decided_at       TIMESTAMPTZ,
  created_at       TIMESTAMPTZ       NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ       NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_payout_approvals ON payout_approvals (tenant_id, payout_request_id, approval_level);

-- Partial payout installment tracking
CREATE TABLE payout_partial_records (
  id                UUID              PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id         UUID              NOT NULL REFERENCES tenants (id) ON DELETE CASCADE,
  payout_request_id UUID              NOT NULL REFERENCES payout_requests (id) ON DELETE CASCADE,
  installment_number INT              NOT NULL,
  amount            NUMERIC(14,2)     NOT NULL,
  scheduled_date    DATE              NOT NULL,
  disbursed_date    DATE,
  status            disbursement_status NOT NULL DEFAULT 'SCHEDULED',
  notes             TEXT,
  created_at        TIMESTAMPTZ       NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ       NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_payout_partial_request      ON payout_partial_records (tenant_id, payout_request_id, installment_number);
CREATE INDEX idx_payout_partial_schedule     ON payout_partial_records (tenant_id, status, scheduled_date);

CREATE TABLE payout_disbursements (
  id                UUID              PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id         UUID              NOT NULL REFERENCES tenants (id) ON DELETE CASCADE,
  payout_request_id UUID              NOT NULL REFERENCES payout_requests (id) ON DELETE CASCADE,
  partial_record_id UUID              REFERENCES payout_partial_records (id),
  amount            NUMERIC(14,2)     NOT NULL,
  status            disbursement_status NOT NULL DEFAULT 'PROCESSING',
  transaction_ref   VARCHAR(300),
  gateway_response  JSONB,
  processed_at      TIMESTAMPTZ,
  failure_reason    TEXT,
  created_at        TIMESTAMPTZ       NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ       NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_payout_disbursements_request ON payout_disbursements (tenant_id, payout_request_id);
CREATE INDEX idx_payout_disbursements_status  ON payout_disbursements (tenant_id, status, processed_at);

-- =============================================================================
-- SECTION 16 — Audit Logging (append-only, partitioned)
-- =============================================================================

CREATE TABLE audit_logs (
  id               BIGSERIAL        NOT NULL,
  tenant_id        UUID             NOT NULL,
  entity_type      audit_entity_type NOT NULL,
  entity_id        UUID             NOT NULL,
  action           VARCHAR(100)     NOT NULL,
  old_state        VARCHAR(100),
  new_state        VARCHAR(100),
  changed_by       UUID,
  temporal_run_id  TEXT,
  change_context   JSONB            NOT NULL DEFAULT '{}',
  ip_address       INET,
  user_agent       TEXT,
  occurred_at      TIMESTAMPTZ      NOT NULL DEFAULT NOW()
) PARTITION BY RANGE (occurred_at);

-- Create initial monthly partitions (example for 2025-2026)
CREATE TABLE audit_logs_2025_01 PARTITION OF audit_logs FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
CREATE TABLE audit_logs_2025_02 PARTITION OF audit_logs FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');
CREATE TABLE audit_logs_2025_03 PARTITION OF audit_logs FOR VALUES FROM ('2025-03-01') TO ('2025-04-01');
CREATE TABLE audit_logs_2025_04 PARTITION OF audit_logs FOR VALUES FROM ('2025-04-01') TO ('2025-05-01');
CREATE TABLE audit_logs_2025_05 PARTITION OF audit_logs FOR VALUES FROM ('2025-05-01') TO ('2025-06-01');
CREATE TABLE audit_logs_2025_06 PARTITION OF audit_logs FOR VALUES FROM ('2025-06-01') TO ('2025-07-01');
CREATE TABLE audit_logs_2025_07 PARTITION OF audit_logs FOR VALUES FROM ('2025-07-01') TO ('2025-08-01');
CREATE TABLE audit_logs_2025_08 PARTITION OF audit_logs FOR VALUES FROM ('2025-08-01') TO ('2025-09-01');
CREATE TABLE audit_logs_2025_09 PARTITION OF audit_logs FOR VALUES FROM ('2025-09-01') TO ('2025-10-01');
CREATE TABLE audit_logs_2025_10 PARTITION OF audit_logs FOR VALUES FROM ('2025-10-01') TO ('2025-11-01');
CREATE TABLE audit_logs_2025_11 PARTITION OF audit_logs FOR VALUES FROM ('2025-11-01') TO ('2025-12-01');
CREATE TABLE audit_logs_2025_12 PARTITION OF audit_logs FOR VALUES FROM ('2025-12-01') TO ('2026-01-01');
CREATE TABLE audit_logs_2026_01 PARTITION OF audit_logs FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');
CREATE TABLE audit_logs_2026_02 PARTITION OF audit_logs FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');
CREATE TABLE audit_logs_2026_03 PARTITION OF audit_logs FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');
CREATE TABLE audit_logs_2026_04 PARTITION OF audit_logs FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');
CREATE TABLE audit_logs_2026_05 PARTITION OF audit_logs FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');
CREATE TABLE audit_logs_2026_06 PARTITION OF audit_logs FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
CREATE TABLE audit_logs_2026_07 PARTITION OF audit_logs FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE audit_logs_2026_08 PARTITION OF audit_logs FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE audit_logs_2026_09 PARTITION OF audit_logs FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
CREATE TABLE audit_logs_2026_10 PARTITION OF audit_logs FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');
CREATE TABLE audit_logs_2026_11 PARTITION OF audit_logs FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');
CREATE TABLE audit_logs_2026_12 PARTITION OF audit_logs FOR VALUES FROM ('2026-12-01') TO ('2027-01-01');

CREATE INDEX idx_audit_logs_entity      ON audit_logs (tenant_id, entity_type, entity_id);
CREATE INDEX idx_audit_logs_time        ON audit_logs (tenant_id, occurred_at DESC);
CREATE INDEX idx_audit_logs_changed_by  ON audit_logs (tenant_id, changed_by, occurred_at DESC);

-- Prevent UPDATE and DELETE on audit_logs (append-only enforcement)
CREATE RULE no_update_audit_logs AS ON UPDATE TO audit_logs DO INSTEAD NOTHING;
CREATE RULE no_delete_audit_logs AS ON DELETE TO audit_logs DO INSTEAD NOTHING;

-- =============================================================================
-- SECTION 17 — Workflow Configuration (JSONB / Temporal)
-- =============================================================================

CREATE TABLE workflow_configurations (
  id                 UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id          UUID          NOT NULL REFERENCES tenants (id) ON DELETE CASCADE,
  workflow_type      workflow_type NOT NULL,
  product_version_id UUID          REFERENCES product_versions (id),
  name               VARCHAR(200)  NOT NULL,
  config             JSONB         NOT NULL,
  version_number     INT           NOT NULL DEFAULT 1,
  is_active          BOOLEAN       NOT NULL DEFAULT TRUE,
  activated_at       TIMESTAMPTZ,
  activated_by       UUID          REFERENCES users (id),
  created_at         TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_workflow_config_type_active   ON workflow_configurations (tenant_id, workflow_type, is_active);
CREATE INDEX idx_workflow_config_version       ON workflow_configurations (tenant_id, product_version_id, workflow_type);
CREATE INDEX idx_workflow_config_gin           ON workflow_configurations USING GIN (config);

-- =============================================================================
-- SECTION 18 — Row-Level Security (Tenant Isolation)
-- =============================================================================
-- Application MUST execute before each session/transaction:
--   SET LOCAL app.current_tenant_id = '<tenant-uuid>';
-- =============================================================================

-- Enable RLS on all tenant-scoped tables
ALTER TABLE tenant_plans             ENABLE ROW LEVEL SECURITY;
ALTER TABLE permissions              ENABLE ROW LEVEL SECURITY;
ALTER TABLE roles                    ENABLE ROW LEVEL SECURITY;
ALTER TABLE users                    ENABLE ROW LEVEL SECURITY;
ALTER TABLE insurance_products       ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_versions         ENABLE ROW LEVEL SECURITY;
ALTER TABLE coverage_options         ENABLE ROW LEVEL SECURITY;
ALTER TABLE riders                   ENABLE ROW LEVEL SECURITY;
ALTER TABLE deductibles              ENABLE ROW LEVEL SECURITY;
ALTER TABLE eligibility_rules        ENABLE ROW LEVEL SECURITY;
ALTER TABLE pricing_rules            ENABLE ROW LEVEL SECURITY;
ALTER TABLE rate_tables              ENABLE ROW LEVEL SECURITY;
ALTER TABLE rate_table_entries       ENABLE ROW LEVEL SECURITY;
ALTER TABLE fraud_rules              ENABLE ROW LEVEL SECURITY;
ALTER TABLE risk_profiles            ENABLE ROW LEVEL SECURITY;
ALTER TABLE risk_factors             ENABLE ROW LEVEL SECURITY;
ALTER TABLE quotes                   ENABLE ROW LEVEL SECURITY;
ALTER TABLE quote_line_items         ENABLE ROW LEVEL SECURITY;
ALTER TABLE quote_status_history     ENABLE ROW LEVEL SECURITY;
ALTER TABLE premium_snapshots        ENABLE ROW LEVEL SECURITY;
ALTER TABLE underwriting_cases       ENABLE ROW LEVEL SECURITY;
ALTER TABLE underwriting_locks       ENABLE ROW LEVEL SECURITY;
ALTER TABLE underwriting_decisions   ENABLE ROW LEVEL SECURITY;
ALTER TABLE approval_hierarchies     ENABLE ROW LEVEL SECURITY;
ALTER TABLE approval_hierarchy_levels ENABLE ROW LEVEL SECURITY;
ALTER TABLE policies                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE policy_coverages         ENABLE ROW LEVEL SECURITY;
ALTER TABLE policy_riders            ENABLE ROW LEVEL SECURITY;
ALTER TABLE policy_status_history    ENABLE ROW LEVEL SECURITY;
ALTER TABLE policy_endorsements      ENABLE ROW LEVEL SECURITY;
ALTER TABLE claims                   ENABLE ROW LEVEL SECURITY;
ALTER TABLE claim_items              ENABLE ROW LEVEL SECURITY;
ALTER TABLE claim_documents          ENABLE ROW LEVEL SECURITY;
ALTER TABLE claim_status_history     ENABLE ROW LEVEL SECURITY;
ALTER TABLE claim_validations        ENABLE ROW LEVEL SECURITY;
ALTER TABLE claim_investigations     ENABLE ROW LEVEL SECURITY;
ALTER TABLE investigation_activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE fraud_reviews            ENABLE ROW LEVEL SECURITY;
ALTER TABLE fraud_review_flags       ENABLE ROW LEVEL SECURITY;
ALTER TABLE claim_assessments        ENABLE ROW LEVEL SECURITY;
ALTER TABLE payout_requests          ENABLE ROW LEVEL SECURITY;
ALTER TABLE payout_approvals         ENABLE ROW LEVEL SECURITY;
ALTER TABLE payout_partial_records   ENABLE ROW LEVEL SECURITY;
ALTER TABLE payout_disbursements     ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs               ENABLE ROW LEVEL SECURITY;
ALTER TABLE workflow_configurations  ENABLE ROW LEVEL SECURITY;

-- Generic RLS policy template (one per table — abbreviated here with representative examples)
-- In production, generate CREATE POLICY statements for each table via migration.

CREATE POLICY tenant_isolation_users ON users
  USING (tenant_id = current_setting('app.current_tenant_id', TRUE)::uuid);

CREATE POLICY tenant_isolation_quotes ON quotes
  USING (tenant_id = current_setting('app.current_tenant_id', TRUE)::uuid);

CREATE POLICY tenant_isolation_policies ON policies
  USING (tenant_id = current_setting('app.current_tenant_id', TRUE)::uuid);

CREATE POLICY tenant_isolation_claims ON claims
  USING (tenant_id = current_setting('app.current_tenant_id', TRUE)::uuid);

CREATE POLICY tenant_isolation_audit_logs ON audit_logs
  USING (tenant_id = current_setting('app.current_tenant_id', TRUE)::uuid);

-- NOTE: Apply equivalent CREATE POLICY ... USING (tenant_id = ...) to ALL tables above.
-- This is best done via a migration generator script or pg_partman hooks.

-- =============================================================================
-- END OF SCHEMA
-- =============================================================================
