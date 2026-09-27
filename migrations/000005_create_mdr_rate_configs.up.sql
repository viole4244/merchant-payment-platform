-- ============================================================
-- TABLE: mdr_rate_configs
-- MDR rate rules defined by tenant admin.
-- A single config row = one rule for one combination of
-- (txn_type, card_network, rbi_category, merchant_size, amount_slab)
--
-- NULL in a matching column means "applies to ALL values of that field"
-- e.g. card_network IS NULL means this rate applies to any card network
-- ============================================================

CREATE TABLE mdr_rate_configs (
    id                      UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id               UUID            NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name                    VARCHAR(255)    NOT NULL,              -- "Axis Standard UPI 2024"
    description             TEXT,

    -- Matching dimensions (NULL = wildcard / applies to all)
    transaction_type        transaction_type NOT NULL,
    card_network            card_network,                          -- NULL for UPI/NETBANKING/WALLET
    rbi_category            rbi_category,                         -- NULL = applies to all MCC categories
    merchant_category_id    UUID            REFERENCES merchant_categories(id), -- NULL = all sizes

    -- Amount slab
    amount_slab_min         DECIMAL(15,2)   NOT NULL DEFAULT 0,
    amount_slab_max         DECIMAL(15,2),                        -- NULL = no upper cap

    -- Fee structure
    percentage_fee          DECIMAL(6,4)    NOT NULL DEFAULT 0,   -- e.g. 0.0175 = 1.75%
    flat_fee                DECIMAL(10,2)   NOT NULL DEFAULT 0,   -- added on top of % fee
    min_fee                 DECIMAL(10,2),                        -- floor — never charge less
    max_fee                 DECIMAL(10,2),                        -- cap — never charge more (RBI)

    -- Auto-apply: if true, this rate applies to ALL merchants of this tenant
    -- unless merchant has a specific override via merchant_rate_assignments
    is_auto_apply           BOOLEAN         NOT NULL DEFAULT false,

    -- Priority for conflict resolution when multiple rules match.
    -- Higher number = evaluated first. First match wins.
    priority                INT             NOT NULL DEFAULT 0,

    -- Validity period
    effective_from          DATE            NOT NULL DEFAULT CURRENT_DATE,
    effective_to            DATE,                                  -- NULL = currently active

    -- Audit
    created_by              UUID            NOT NULL REFERENCES tenant_admins(id) ON DELETE RESTRICT,
    updated_by              UUID            REFERENCES tenant_admins(id) ON DELETE RESTRICT,
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    -- Constraint: slab range must be valid
    CONSTRAINT chk_amount_slab      CHECK (amount_slab_max IS NULL OR amount_slab_max > amount_slab_min),
    -- Constraint: fees must be non-negative
    CONSTRAINT chk_percentage_fee   CHECK (percentage_fee >= 0 AND percentage_fee <= 1),
    CONSTRAINT chk_flat_fee         CHECK (flat_fee >= 0),
    CONSTRAINT chk_min_max_fee      CHECK (min_fee IS NULL OR max_fee IS NULL OR max_fee >= min_fee),
    -- Constraint: effective date range
    CONSTRAINT chk_effective_dates  CHECK (effective_to IS NULL OR effective_to >= effective_from)
);

-- Indexes for rate resolution query (the hot path)
CREATE INDEX idx_mdr_tenant_txn_type       ON mdr_rate_configs (tenant_id, transaction_type);
CREATE INDEX idx_mdr_auto_apply            ON mdr_rate_configs (tenant_id, is_auto_apply, transaction_type)
                                           WHERE is_auto_apply = true;
CREATE INDEX idx_mdr_effective             ON mdr_rate_configs (tenant_id, effective_from, effective_to);
CREATE INDEX idx_mdr_priority              ON mdr_rate_configs (tenant_id, priority DESC);

COMMENT ON TABLE  mdr_rate_configs              IS 'MDR rate rules configured by tenant admins. NULL dimensions = wildcard match.';
COMMENT ON COLUMN mdr_rate_configs.is_auto_apply IS 'If true, applies to all tenant merchants unless a merchant_rate_assignment overrides it';
COMMENT ON COLUMN mdr_rate_configs.priority     IS 'Higher number wins. Use to make specific rules take precedence over generic ones.';
COMMENT ON COLUMN mdr_rate_configs.percentage_fee IS 'Stored as decimal fraction. 1.75% = 0.0175. Max 1 = 100%.';
COMMENT ON COLUMN mdr_rate_configs.max_fee      IS 'Must never exceed rbi_max_mdr_percentage of transaction amount — enforced in application layer';
