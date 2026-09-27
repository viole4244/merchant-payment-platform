-- ============================================================
-- ENUMS: Create all custom types first (referenced by later tables)
-- ============================================================

CREATE TYPE tenant_status AS ENUM ('ACTIVE', 'SUSPENDED', 'ONBOARDING');

CREATE TYPE admin_role AS ENUM ('SUPER_ADMIN', 'ADMIN', 'VIEWER');

CREATE TYPE rbi_category AS ENUM (
    'UTILITY',
    'FUEL',
    'GOVERNMENT',
    'EDUCATION',
    'HEALTHCARE',
    'SMALL_MERCHANT',
    'AGRICULTURE',
    'TELECOM',
    'TRAVEL',
    'GENERAL'
);

CREATE TYPE merchant_size AS ENUM ('MICRO', 'SMALL', 'MEDIUM', 'LARGE', 'ENTERPRISE');

CREATE TYPE transaction_type AS ENUM (
    'UPI',
    'CARD_CREDIT',
    'CARD_DEBIT',
    'NETBANKING',
    'WALLET',
    'PPI',
    'BNPL'
);

CREATE TYPE card_network AS ENUM ('VISA', 'MASTERCARD', 'RUPAY', 'AMEX', 'DINERS');

CREATE TYPE merchant_status AS ENUM ('ACTIVE', 'SUSPENDED', 'PENDING_KYC', 'REJECTED', 'OFFBOARDED');

CREATE TYPE kyc_status AS ENUM ('PENDING', 'IN_REVIEW', 'VERIFIED', 'REJECTED', 'EXPIRED');

CREATE TYPE transaction_status AS ENUM ('PENDING', 'SETTLED', 'FAILED', 'DISPUTED', 'REVERSED', 'HOLD');

CREATE TYPE settlement_status AS ENUM ('PENDING', 'PROCESSING', 'SETTLED', 'FAILED', 'CANCELLED');

CREATE TYPE settlement_cycle AS ENUM ('T0', 'T1', 'T2', 'T3');

CREATE TYPE outbox_status AS ENUM ('PENDING', 'PUBLISHED', 'FAILED');

-- ============================================================
-- TABLE: tenants
-- Banks and financial institutions that use your platform
-- ============================================================

CREATE TABLE tenants (
    id                  UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    name                VARCHAR(255)    NOT NULL,
    code                VARCHAR(20)     NOT NULL UNIQUE,           -- 'AXIS', 'SBI', 'KOTAK'
    status              tenant_status   NOT NULL DEFAULT 'ONBOARDING',
    contact_email       VARCHAR(255)    NOT NULL,
    contact_phone       VARCHAR(20),
    webhook_url         VARCHAR(500),                              -- POST settlement reports here
    api_key_hash        VARCHAR(255)    NOT NULL,                  -- bcrypt hashed API key
    api_key_prefix      VARCHAR(10)     NOT NULL,                  -- e.g. 'ax_live_' for display
    settlement_account  VARCHAR(50),                               -- tenant's own settlement bank account
    settlement_ifsc     VARCHAR(11),
    metadata            JSONB           DEFAULT '{}',              -- flexible extra config
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_tenants_code   ON tenants (code);
CREATE INDEX idx_tenants_status ON tenants (status);

COMMENT ON TABLE  tenants                IS 'Banks/FIs onboarded as platform clients';
COMMENT ON COLUMN tenants.code           IS 'Short unique identifier, used in API key prefix';
COMMENT ON COLUMN tenants.api_key_hash   IS 'Bcrypt hash of the API key issued to this tenant';
COMMENT ON COLUMN tenants.api_key_prefix IS 'Non-secret prefix shown in dashboard e.g. ax_live_****';
