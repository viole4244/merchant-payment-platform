package utils

import (
	"context"
	"fmt"
	"log"

	"github.com/jackc/pgx/v5/pgxpool"
)

// RunInitQueries creates all enums, tables, and indexes if they do not already exist.
// Safe to call every time the server starts — fully idempotent.
func RunInitQueries(ctx context.Context, pool *pgxpool.Pool) error {
	log.Println("🛠️  Running DB init queries...")

	queries := []struct {
		name string
		sql  string
	}{
		{"enums", sqlEnums},
		{"tenants", sqlTenants},
		{"tenant_admins", sqlTenantAdmins},
		{"mcc_categories", sqlMCCCategories},
		{"merchant_categories", sqlMerchantCategories},
		{"merchants", sqlMerchants},
		{"mdr_rate_configs", sqlMDRRateConfigs},
		{"merchant_rate_assignments", sqlMerchantRateAssignments},
		{"settlement_batches", sqlSettlementBatches},
		{"transactions", sqlTransactions},
		{"outbox", sqlOutbox},
		{"audit_logs", sqlAuditLogs},
		{"seed_data", sqlSeedData},
	}

	for _, q := range queries {
		if _, err := pool.Exec(ctx, q.sql); err != nil {
			return fmt.Errorf("init [%s]: %w", q.name, err)
		}
		log.Printf("   ✓ %s", q.name)
	}

	log.Println("✅ All tables and indexes ready")
	return nil
}

// ─────────────────────────────────────────────
// ENUMS
// PostgreSQL has no CREATE TYPE IF NOT EXISTS,
// so we use a DO block with exception handling.
// ─────────────────────────────────────────────

const sqlEnums = `
DO $$ BEGIN
    CREATE TYPE tenant_status AS ENUM ('ACTIVE', 'SUSPENDED', 'ONBOARDING');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE admin_role AS ENUM ('SUPER_ADMIN', 'ADMIN', 'VIEWER');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE rbi_category AS ENUM (
        'UTILITY', 'FUEL', 'GOVERNMENT', 'EDUCATION',
        'HEALTHCARE', 'SMALL_MERCHANT', 'AGRICULTURE',
        'TELECOM', 'TRAVEL', 'GENERAL'
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE merchant_size AS ENUM ('MICRO', 'SMALL', 'MEDIUM', 'LARGE', 'ENTERPRISE');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE transaction_type AS ENUM (
        'UPI', 'CARD_CREDIT', 'CARD_DEBIT', 'NETBANKING', 'WALLET', 'PPI', 'BNPL'
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE card_network AS ENUM ('VISA', 'MASTERCARD', 'RUPAY', 'AMEX', 'DINERS');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE merchant_status AS ENUM (
        'ACTIVE', 'SUSPENDED', 'PENDING_KYC', 'REJECTED', 'OFFBOARDED'
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE kyc_status AS ENUM (
        'PENDING', 'IN_REVIEW', 'VERIFIED', 'REJECTED', 'EXPIRED'
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE transaction_status AS ENUM (
        'PENDING', 'SETTLED', 'FAILED', 'DISPUTED', 'REVERSED', 'HOLD'
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE settlement_status AS ENUM (
        'PENDING', 'PROCESSING', 'SETTLED', 'FAILED', 'CANCELLED'
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE settlement_cycle AS ENUM ('T0', 'T1', 'T2', 'T3');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE outbox_status AS ENUM ('PENDING', 'PUBLISHED', 'FAILED');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
`

// ─────────────────────────────────────────────
// TENANTS
// ─────────────────────────────────────────────

const sqlTenants = `
CREATE TABLE IF NOT EXISTS tenants (
    id                  UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    name                VARCHAR(255)    NOT NULL,
    code                VARCHAR(20)     NOT NULL UNIQUE,
    status              tenant_status   NOT NULL DEFAULT 'ONBOARDING',
    contact_email       VARCHAR(255)    NOT NULL,
    contact_phone       VARCHAR(20),
    webhook_url         VARCHAR(500),
    api_key_hash        VARCHAR(255)    NOT NULL,
    api_key_prefix      VARCHAR(10)     NOT NULL,
    settlement_account  VARCHAR(50),
    settlement_ifsc     VARCHAR(11),
    metadata            JSONB           DEFAULT '{}',
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tenants_code   ON tenants (code);
CREATE INDEX IF NOT EXISTS idx_tenants_status ON tenants (status);
`

// ─────────────────────────────────────────────
// TENANT ADMINS
// ─────────────────────────────────────────────

const sqlTenantAdmins = `
CREATE TABLE IF NOT EXISTS tenant_admins (
    id                  UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id           UUID            NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name                VARCHAR(255)    NOT NULL,
    email               VARCHAR(255)    NOT NULL UNIQUE,
    password_hash       VARCHAR(255)    NOT NULL,
    role                admin_role      NOT NULL DEFAULT 'ADMIN',
    is_active           BOOLEAN         NOT NULL DEFAULT true,
    failed_login_count  INT             NOT NULL DEFAULT 0,
    locked_until        TIMESTAMPTZ,
    last_login_at       TIMESTAMPTZ,
    last_login_ip       VARCHAR(45),
    password_changed_at TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by          UUID            REFERENCES tenant_admins(id) ON DELETE SET NULL,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tenant_admins_tenant_id ON tenant_admins (tenant_id);
CREATE INDEX IF NOT EXISTS idx_tenant_admins_email     ON tenant_admins (email);
CREATE INDEX IF NOT EXISTS idx_tenant_admins_role      ON tenant_admins (tenant_id, role);
`

// ─────────────────────────────────────────────
// MCC CATEGORIES (RBI Reference)
// ─────────────────────────────────────────────

const sqlMCCCategories = `
CREATE TABLE IF NOT EXISTS mcc_categories (
    code                    VARCHAR(4)      PRIMARY KEY,
    description             VARCHAR(255)    NOT NULL,
    rbi_category            rbi_category    NOT NULL,
    rbi_max_mdr_percentage  DECIMAL(6,4)    NOT NULL DEFAULT 0,
    rbi_max_flat_fee        DECIMAL(10,2),
    notes                   TEXT,
    is_zero_mdr             BOOLEAN         NOT NULL DEFAULT false,
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);
`

// ─────────────────────────────────────────────
// MERCHANT CATEGORIES (Size Tiers)
// ─────────────────────────────────────────────

const sqlMerchantCategories = `
CREATE TABLE IF NOT EXISTS merchant_categories (
    id                      UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    name                    merchant_size   NOT NULL UNIQUE,
    annual_turnover_min     DECIMAL(15,2)   NOT NULL DEFAULT 0,
    annual_turnover_max     DECIMAL(15,2),
    description             VARCHAR(255),
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);
`

// ─────────────────────────────────────────────
// MERCHANTS
// ─────────────────────────────────────────────

const sqlMerchants = `
CREATE TABLE IF NOT EXISTS merchants (
    id                      UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id               UUID            NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    vpa                     VARCHAR(255)    NOT NULL UNIQUE,
    name                    VARCHAR(255)    NOT NULL,
    email                   VARCHAR(255)    NOT NULL,
    phone                   VARCHAR(20),
    mcc_code                VARCHAR(4)      NOT NULL REFERENCES mcc_categories(code),
    merchant_category_id    UUID            NOT NULL REFERENCES merchant_categories(id),
    annual_turnover         DECIMAL(15,2)   NOT NULL DEFAULT 0,
    bank_account_number     VARCHAR(100)    NOT NULL,
    ifsc_code               VARCHAR(11)     NOT NULL,
    bank_name               VARCHAR(100),
    gstin                   VARCHAR(15),
    pan                     VARCHAR(10),
    status                  merchant_status NOT NULL DEFAULT 'PENDING_KYC',
    kyc_status              kyc_status      NOT NULL DEFAULT 'PENDING',
    kyc_reviewed_by         UUID            REFERENCES tenant_admins(id) ON DELETE SET NULL,
    kyc_reviewed_at         TIMESTAMPTZ,
    kyc_rejection_reason    TEXT,
    onboarded_by            UUID            REFERENCES tenant_admins(id) ON DELETE SET NULL,
    metadata                JSONB           DEFAULT '{}',
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_merchants_tenant_id          ON merchants (tenant_id);
CREATE INDEX IF NOT EXISTS idx_merchants_vpa                ON merchants (vpa);
CREATE INDEX IF NOT EXISTS idx_merchants_status             ON merchants (tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_merchants_mcc_code           ON merchants (mcc_code);
CREATE INDEX IF NOT EXISTS idx_merchants_kyc_status         ON merchants (tenant_id, kyc_status);
CREATE INDEX IF NOT EXISTS idx_merchants_merchant_category  ON merchants (merchant_category_id);
`

// ─────────────────────────────────────────────
// MDR RATE CONFIGS
// ─────────────────────────────────────────────

const sqlMDRRateConfigs = `
CREATE TABLE IF NOT EXISTS mdr_rate_configs (
    id                      UUID                PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id               UUID                NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name                    VARCHAR(255)        NOT NULL,
    description             TEXT,
    transaction_type        transaction_type    NOT NULL,
    card_network            card_network,
    rbi_category            rbi_category,
    merchant_category_id    UUID                REFERENCES merchant_categories(id),
    amount_slab_min         DECIMAL(15,2)       NOT NULL DEFAULT 0,
    amount_slab_max         DECIMAL(15,2),
    percentage_fee          DECIMAL(6,4)        NOT NULL DEFAULT 0,
    flat_fee                DECIMAL(10,2)       NOT NULL DEFAULT 0,
    min_fee                 DECIMAL(10,2),
    max_fee                 DECIMAL(10,2),
    is_auto_apply           BOOLEAN             NOT NULL DEFAULT false,
    priority                INT                 NOT NULL DEFAULT 0,
    effective_from          DATE                NOT NULL DEFAULT CURRENT_DATE,
    effective_to            DATE,
    created_by              UUID                NOT NULL REFERENCES tenant_admins(id) ON DELETE RESTRICT,
    updated_by              UUID                REFERENCES tenant_admins(id) ON DELETE RESTRICT,
    created_at              TIMESTAMPTZ         NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ         NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_mdr_amount_slab    CHECK (amount_slab_max IS NULL OR amount_slab_max > amount_slab_min),
    CONSTRAINT chk_mdr_pct_fee        CHECK (percentage_fee >= 0 AND percentage_fee <= 1),
    CONSTRAINT chk_mdr_flat_fee       CHECK (flat_fee >= 0),
    CONSTRAINT chk_mdr_min_max_fee    CHECK (min_fee IS NULL OR max_fee IS NULL OR max_fee >= min_fee),
    CONSTRAINT chk_mdr_dates          CHECK (effective_to IS NULL OR effective_to >= effective_from)
);

CREATE INDEX IF NOT EXISTS idx_mdr_tenant_txn_type ON mdr_rate_configs (tenant_id, transaction_type);
CREATE INDEX IF NOT EXISTS idx_mdr_auto_apply      ON mdr_rate_configs (tenant_id, is_auto_apply, transaction_type)
                                                   WHERE is_auto_apply = true;
CREATE INDEX IF NOT EXISTS idx_mdr_effective       ON mdr_rate_configs (tenant_id, effective_from, effective_to);
CREATE INDEX IF NOT EXISTS idx_mdr_priority        ON mdr_rate_configs (tenant_id, priority DESC);
`

// ─────────────────────────────────────────────
// MERCHANT RATE ASSIGNMENTS
// ─────────────────────────────────────────────

const sqlMerchantRateAssignments = `
CREATE TABLE IF NOT EXISTS merchant_rate_assignments (
    id                      UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_id             UUID            NOT NULL REFERENCES merchants(id) ON DELETE CASCADE,
    mdr_rate_config_id      UUID            NOT NULL REFERENCES mdr_rate_configs(id) ON DELETE RESTRICT,
    assigned_by             UUID            NOT NULL REFERENCES tenant_admins(id) ON DELETE RESTRICT,
    notes                   TEXT,
    effective_from          DATE            NOT NULL DEFAULT CURRENT_DATE,
    effective_to            DATE,
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_mra_dates CHECK (effective_to IS NULL OR effective_to >= effective_from)
);

CREATE INDEX IF NOT EXISTS idx_mra_merchant_id     ON merchant_rate_assignments (merchant_id);
CREATE INDEX IF NOT EXISTS idx_mra_rate_config_id  ON merchant_rate_assignments (mdr_rate_config_id);
CREATE INDEX IF NOT EXISTS idx_mra_merchant_active ON merchant_rate_assignments (merchant_id, effective_from, effective_to);
`

// ─────────────────────────────────────────────
// SETTLEMENT BATCHES (created before transactions so FK can reference it)
// ─────────────────────────────────────────────

const sqlSettlementBatches = `
CREATE TABLE IF NOT EXISTS settlement_batches (
    id                      UUID                PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id               UUID                NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    merchant_id             UUID                NOT NULL REFERENCES merchants(id) ON DELETE RESTRICT,
    status                  settlement_status   NOT NULL DEFAULT 'PENDING',
    settlement_cycle        settlement_cycle    NOT NULL DEFAULT 'T1',
    total_gross_amount      DECIMAL(15,2)       NOT NULL DEFAULT 0,
    total_mdr_amount        DECIMAL(15,2)       NOT NULL DEFAULT 0,
    total_net_amount        DECIMAL(15,2)       NOT NULL DEFAULT 0,
    txn_count               INT                 NOT NULL DEFAULT 0,
    txn_from                TIMESTAMPTZ         NOT NULL,
    txn_to                  TIMESTAMPTZ         NOT NULL,
    settlement_date         DATE                NOT NULL,
    bank_reference_number   VARCHAR(100),
    settled_at              TIMESTAMPTZ,
    failure_reason          TEXT,
    retry_count             INT                 NOT NULL DEFAULT 0,
    created_at              TIMESTAMPTZ         NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ         NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_settlement_amounts CHECK (
        total_gross_amount >= 0 AND
        total_mdr_amount   >= 0 AND
        total_net_amount   >= 0 AND
        total_net_amount    = total_gross_amount - total_mdr_amount
    )
);

CREATE INDEX IF NOT EXISTS idx_settlement_tenant_id  ON settlement_batches (tenant_id);
CREATE INDEX IF NOT EXISTS idx_settlement_merchant   ON settlement_batches (merchant_id);
CREATE INDEX IF NOT EXISTS idx_settlement_status     ON settlement_batches (tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_settlement_date       ON settlement_batches (settlement_date);
CREATE INDEX IF NOT EXISTS idx_settlement_pending    ON settlement_batches (settlement_date, merchant_id)
                                                     WHERE status = 'PENDING';
`

// ─────────────────────────────────────────────
// TRANSACTIONS
// ─────────────────────────────────────────────

const sqlTransactions = `
CREATE TABLE IF NOT EXISTS transactions (
    id                      UUID                PRIMARY KEY DEFAULT gen_random_uuid(),
    external_txn_id         VARCHAR(255)        NOT NULL UNIQUE,
    tenant_id               UUID                NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    merchant_id             UUID                NOT NULL REFERENCES merchants(id) ON DELETE RESTRICT,
    merchant_vpa            VARCHAR(255)        NOT NULL,
    transaction_type        transaction_type    NOT NULL,
    card_network            card_network,
    mcc_code                VARCHAR(4)          NOT NULL,
    currency                VARCHAR(3)          NOT NULL DEFAULT 'INR',
    gross_amount            DECIMAL(15,2)       NOT NULL,
    mdr_amount              DECIMAL(15,2)       NOT NULL,
    net_amount              DECIMAL(15,2)       NOT NULL,
    applied_rate_config_id  UUID                REFERENCES mdr_rate_configs(id) ON DELETE SET NULL,
    rate_snapshot           JSONB               NOT NULL,
    status                  transaction_status  NOT NULL DEFAULT 'PENDING',
    settlement_id           UUID                REFERENCES settlement_batches(id) ON DELETE SET NULL,
    failure_reason          TEXT,
    caller_metadata         JSONB               DEFAULT '{}',
    created_at              TIMESTAMPTZ         NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ         NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_txn_amounts CHECK (
        gross_amount  > 0  AND
        mdr_amount   >= 0  AND
        net_amount   >= 0  AND
        net_amount    = gross_amount - mdr_amount
    )
);

CREATE INDEX IF NOT EXISTS idx_txn_tenant_id        ON transactions (tenant_id);
CREATE INDEX IF NOT EXISTS idx_txn_merchant_id      ON transactions (merchant_id);
CREATE INDEX IF NOT EXISTS idx_txn_merchant_created ON transactions (merchant_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_txn_status           ON transactions (tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_txn_settlement_id    ON transactions (settlement_id) WHERE settlement_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_txn_external_id      ON transactions (external_txn_id);
CREATE INDEX IF NOT EXISTS idx_txn_created_at       ON transactions (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_txn_pending_settle   ON transactions (merchant_id, created_at)
                                                    WHERE status = 'PENDING';
`

// ─────────────────────────────────────────────
// OUTBOX
// ─────────────────────────────────────────────

const sqlOutbox = `
CREATE TABLE IF NOT EXISTS outbox (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    aggregate_type  VARCHAR(50)     NOT NULL,
    aggregate_id    UUID            NOT NULL,
    topic           VARCHAR(255)    NOT NULL,
    event_type      VARCHAR(100)    NOT NULL,
    payload         JSONB           NOT NULL,
    status          outbox_status   NOT NULL DEFAULT 'PENDING',
    retry_count     INT             NOT NULL DEFAULT 0,
    max_retries     INT             NOT NULL DEFAULT 5,
    last_error      TEXT,
    process_after   TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    published_at    TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_outbox_pending   ON outbox (status, process_after) WHERE status = 'PENDING';
CREATE INDEX IF NOT EXISTS idx_outbox_aggregate ON outbox (aggregate_type, aggregate_id);
CREATE INDEX IF NOT EXISTS idx_outbox_created   ON outbox (created_at);
`

// ─────────────────────────────────────────────
// AUDIT LOGS
// ─────────────────────────────────────────────

const sqlAuditLogs = `
CREATE TABLE IF NOT EXISTS audit_logs (
    id          UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id   UUID            REFERENCES tenants(id) ON DELETE SET NULL,
    actor_id    UUID,
    actor_type  VARCHAR(50)     NOT NULL DEFAULT 'admin',
    action      VARCHAR(100)    NOT NULL,
    entity_type VARCHAR(50)     NOT NULL,
    entity_id   UUID            NOT NULL,
    old_value   JSONB,
    new_value   JSONB,
    ip_address  VARCHAR(45),
    user_agent  TEXT,
    created_at  TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_tenant  ON audit_logs (tenant_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_entity  ON audit_logs (entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_actor   ON audit_logs (actor_id, created_at DESC);
`

// ─────────────────────────────────────────────
// SEED DATA
// ON CONFLICT DO NOTHING = safe to re-run
// ─────────────────────────────────────────────

const sqlSeedData = `
INSERT INTO merchant_categories (name, annual_turnover_min, annual_turnover_max, description) VALUES
    ('MICRO',      0,            2000000,    'Up to ₹20L — RBI zero MDR for UPI'),
    ('SMALL',      2000001,      20000000,   '₹20L – ₹2Cr'),
    ('MEDIUM',     20000001,     500000000,  '₹2Cr – ₹50Cr'),
    ('LARGE',      500000001,    5000000000, '₹50Cr – ₹500Cr'),
    ('ENTERPRISE', 5000000001,   NULL,       'Above ₹500Cr')
ON CONFLICT (name) DO NOTHING;

INSERT INTO mcc_categories (code, description, rbi_category, rbi_max_mdr_percentage, is_zero_mdr) VALUES
    ('9399', 'Government Services',              'GOVERNMENT', 0,     true),
    ('9222', 'Fines / Penalties',                'GOVERNMENT', 0,     true),
    ('9311', 'Tax Payments',                     'GOVERNMENT', 0,     true),
    ('9405', 'Post Office',                      'GOVERNMENT', 0,     true),
    ('4900', 'Utilities — Electric, Gas, Water', 'UTILITY',    0.005, false),
    ('4814', 'Telecommunications',               'UTILITY',    0.005, false),
    ('4911', 'Electric Companies',               'UTILITY',    0.005, false),
    ('4941', 'Water Supply',                     'UTILITY',    0.005, false),
    ('5541', 'Service Stations (Petrol/Diesel)', 'FUEL',       0.01,  false),
    ('5542', 'Automated Fuel Dispensers',        'FUEL',       0.01,  false),
    ('8211', 'Elementary and Secondary Schools', 'EDUCATION',  0.01,  false),
    ('8220', 'Colleges, Universities',           'EDUCATION',  0.01,  false),
    ('8299', 'Educational Services',             'EDUCATION',  0.01,  false),
    ('8062', 'Hospitals',                        'HEALTHCARE', 0.015, false),
    ('8099', 'Health Services',                  'HEALTHCARE', 0.015, false),
    ('4112', 'Passenger Railways',               'TRAVEL',     0.005, false),
    ('4111', 'Local Transport',                  'TRAVEL',     0.005, false),
    ('4511', 'Airlines',                         'TRAVEL',     0.02,  false),
    ('7011', 'Hotels / Motels',                  'TRAVEL',     0.02,  false),
    ('5411', 'Grocery Stores',                   'GENERAL',    0.02,  false),
    ('5812', 'Restaurants',                      'GENERAL',    0.02,  false),
    ('5732', 'Electronics Stores',               'GENERAL',    0.02,  false),
    ('5912', 'Pharmacies',                       'GENERAL',    0.02,  false),
    ('5999', 'Miscellaneous Retail',             'GENERAL',    0.02,  false),
    ('0000', 'Default / Unclassified',           'GENERAL',    0.02,  false)
ON CONFLICT (code) DO NOTHING;
`
