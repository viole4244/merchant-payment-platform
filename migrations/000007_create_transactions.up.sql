-- ============================================================
-- TABLE: transactions
-- Created on every incoming API call. One row = one payment notification.
-- ============================================================

CREATE TABLE transactions (
    id                      UUID            PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Idempotency: if caller sends same external_txn_id twice, return cached result
    external_txn_id         VARCHAR(255)    NOT NULL UNIQUE,

    tenant_id               UUID            NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    merchant_id             UUID            NOT NULL REFERENCES merchants(id) ON DELETE RESTRICT,
    merchant_vpa            VARCHAR(255)    NOT NULL,              -- snapshot of VPA at txn time

    -- Transaction details (as received from caller)
    transaction_type        transaction_type NOT NULL,
    card_network            card_network,                          -- NULL for UPI/NETBANKING
    mcc_code                VARCHAR(4)      NOT NULL,              -- snapshot at txn time
    currency                VARCHAR(3)      NOT NULL DEFAULT 'INR',
    gross_amount            DECIMAL(15,2)   NOT NULL,             -- what the customer paid

    -- Calculated MDR
    mdr_amount              DECIMAL(15,2)   NOT NULL,             -- your cut
    net_amount              DECIMAL(15,2)   NOT NULL,             -- gross - mdr (to merchant)

    -- Rate audit trail (critical for disputes)
    applied_rate_config_id  UUID            REFERENCES mdr_rate_configs(id) ON DELETE SET NULL,
    rate_snapshot           JSONB           NOT NULL,             -- exact rate values at time of txn
    -- rate_snapshot structure:
    -- {
    --   "rate_config_id": "...",
    --   "percentage_fee": 0.0175,
    --   "flat_fee": 2.00,
    --   "min_fee": null,
    --   "max_fee": null,
    --   "applied_percentage": 0.0175,
    --   "applied_flat": 2.00,
    --   "calculation": "1000 * 0.0175 + 2 = 19.50"
    -- }

    status                  transaction_status NOT NULL DEFAULT 'PENDING',
    settlement_id           UUID,                                  -- FK added after settlement_batches table exists
    failure_reason          TEXT,                                  -- if status = FAILED

    -- Caller's additional metadata
    caller_metadata         JSONB           DEFAULT '{}',         -- any extra fields caller sends

    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    -- Derived checks
    CONSTRAINT chk_amounts  CHECK (
        gross_amount > 0 AND
        mdr_amount >= 0 AND
        net_amount >= 0 AND
        net_amount = gross_amount - mdr_amount
    )
);

-- Primary query patterns
CREATE INDEX idx_txn_tenant_id          ON transactions (tenant_id);
CREATE INDEX idx_txn_merchant_id        ON transactions (merchant_id);
CREATE INDEX idx_txn_merchant_created   ON transactions (merchant_id, created_at DESC);   -- paginate merchant txns
CREATE INDEX idx_txn_status             ON transactions (tenant_id, status);
CREATE INDEX idx_txn_settlement_id      ON transactions (settlement_id) WHERE settlement_id IS NOT NULL;
CREATE INDEX idx_txn_external_id        ON transactions (external_txn_id);                 -- idempotency lookup
CREATE INDEX idx_txn_created_at         ON transactions (created_at DESC);                 -- time-range queries
-- Partial index for pending settlement job
CREATE INDEX idx_txn_pending_settle     ON transactions (merchant_id, created_at)
                                        WHERE status = 'PENDING';

COMMENT ON TABLE  transactions                       IS 'One row per incoming payment notification from external system';
COMMENT ON COLUMN transactions.external_txn_id       IS 'Idempotency key from caller. Duplicate calls return same response.';
COMMENT ON COLUMN transactions.rate_snapshot         IS 'JSONB snapshot of rate at txn time. Never changes even if rate_config is updated later.';
COMMENT ON COLUMN transactions.applied_rate_config_id IS 'Can become NULL if rate config is deleted, but rate_snapshot always preserves the values.';
