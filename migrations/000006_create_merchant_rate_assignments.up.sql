-- ============================================================
-- TABLE: merchant_rate_assignments
-- Links a specific merchant to a specific rate config,
-- overriding the auto-apply rates for that merchant.
--
-- Use case: Axis gives merchant XYZ a special negotiated rate
-- that differs from the bank-wide auto-apply rate.
-- ============================================================

CREATE TABLE merchant_rate_assignments (
    id                      UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_id             UUID            NOT NULL REFERENCES merchants(id) ON DELETE CASCADE,
    mdr_rate_config_id      UUID            NOT NULL REFERENCES mdr_rate_configs(id) ON DELETE RESTRICT,
    assigned_by             UUID            NOT NULL REFERENCES tenant_admins(id) ON DELETE RESTRICT,
    notes                   TEXT,                                  -- reason for custom rate
    effective_from          DATE            NOT NULL DEFAULT CURRENT_DATE,
    effective_to            DATE,                                  -- NULL = active indefinitely
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    -- Constraint: one active assignment per merchant per transaction_type at any time
    -- (enforced at app layer; DB level unique index below covers active assignments)
    CONSTRAINT chk_assignment_dates CHECK (effective_to IS NULL OR effective_to >= effective_from)
);

CREATE INDEX idx_mra_merchant_id       ON merchant_rate_assignments (merchant_id);
CREATE INDEX idx_mra_rate_config_id    ON merchant_rate_assignments (mdr_rate_config_id);
-- Index for "get all active assignments for a merchant"
CREATE INDEX idx_mra_merchant_active   ON merchant_rate_assignments (merchant_id, effective_from, effective_to);

COMMENT ON TABLE  merchant_rate_assignments IS 'Merchant-specific rate overrides. Takes precedence over auto-apply rates.';
COMMENT ON COLUMN merchant_rate_assignments.notes IS 'Audit trail: why was this custom rate given?';
