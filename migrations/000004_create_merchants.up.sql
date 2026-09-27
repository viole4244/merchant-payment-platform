-- ============================================================
-- TABLE: merchants
-- Merchants onboarded by a tenant bank
-- ============================================================

CREATE TABLE merchants (
    id                      UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id               UUID            NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    vpa                     VARCHAR(255)    NOT NULL UNIQUE,       -- 'store@ybl' — main lookup key
    name                    VARCHAR(255)    NOT NULL,
    email                   VARCHAR(255)    NOT NULL,
    phone                   VARCHAR(20),
    mcc_code                VARCHAR(4)      NOT NULL REFERENCES mcc_categories(code),
    merchant_category_id    UUID            NOT NULL REFERENCES merchant_categories(id),
    annual_turnover         DECIMAL(15,2)   NOT NULL DEFAULT 0,   -- used for category classification

    -- Settlement bank account (store encrypted in production via Vault)
    bank_account_number     VARCHAR(100)    NOT NULL,
    ifsc_code               VARCHAR(11)     NOT NULL,
    bank_name               VARCHAR(100),

    -- Business identity
    gstin                   VARCHAR(15),                           -- GST number
    pan                     VARCHAR(10),                           -- PAN (store encrypted)

    status                  merchant_status NOT NULL DEFAULT 'PENDING_KYC',
    kyc_status              kyc_status      NOT NULL DEFAULT 'PENDING',
    kyc_reviewed_by         UUID            REFERENCES tenant_admins(id) ON DELETE SET NULL,
    kyc_reviewed_at         TIMESTAMPTZ,
    kyc_rejection_reason    TEXT,

    onboarded_by            UUID            REFERENCES tenant_admins(id) ON DELETE SET NULL,
    metadata                JSONB           DEFAULT '{}',          -- flexible per-tenant extra fields
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- Indexes for common queries
CREATE INDEX idx_merchants_tenant_id           ON merchants (tenant_id);
CREATE INDEX idx_merchants_vpa                 ON merchants (vpa);             -- primary lookup
CREATE INDEX idx_merchants_status              ON merchants (tenant_id, status);
CREATE INDEX idx_merchants_mcc_code            ON merchants (mcc_code);
CREATE INDEX idx_merchants_kyc_status          ON merchants (tenant_id, kyc_status);
CREATE INDEX idx_merchants_merchant_category   ON merchants (merchant_category_id);

COMMENT ON TABLE  merchants                      IS 'Merchants onboarded by tenant banks';
COMMENT ON COLUMN merchants.vpa                  IS 'Virtual Payment Address — primary lookup key on transaction API calls';
COMMENT ON COLUMN merchants.bank_account_number  IS 'Should be encrypted at rest using Vault in production';
COMMENT ON COLUMN merchants.pan                  IS 'Should be encrypted at rest using Vault in production';
COMMENT ON COLUMN merchants.annual_turnover      IS 'Used to auto-assign merchant_category. Re-evaluate periodically.';
