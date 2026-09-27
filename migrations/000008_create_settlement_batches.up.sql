-- ============================================================
-- TABLE: settlement_batches
-- Groups multiple transactions into one batch for settlement.
-- A batch is per-merchant per-cycle (T+1, T+2 etc.)
-- ============================================================

CREATE TABLE settlement_batches (
    id                      UUID                PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id               UUID                NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    merchant_id             UUID                NOT NULL REFERENCES merchants(id) ON DELETE RESTRICT,
    status                  settlement_status   NOT NULL DEFAULT 'PENDING',
    settlement_cycle        settlement_cycle    NOT NULL DEFAULT 'T1',

    -- Aggregated financials (computed when batch is created)
    total_gross_amount      DECIMAL(15,2)       NOT NULL DEFAULT 0,
    total_mdr_amount        DECIMAL(15,2)       NOT NULL DEFAULT 0,
    total_net_amount        DECIMAL(15,2)       NOT NULL DEFAULT 0,
    txn_count               INT                 NOT NULL DEFAULT 0,

    -- Settlement window
    txn_from                TIMESTAMPTZ         NOT NULL,          -- earliest txn in this batch
    txn_to                  TIMESTAMPTZ         NOT NULL,          -- latest txn in this batch
    settlement_date         DATE                NOT NULL,          -- date when merchant gets credited

    -- Bank transfer details (filled after actual transfer)
    bank_reference_number   VARCHAR(100),                          -- UTR number
    settled_at              TIMESTAMPTZ,

    -- Failure handling
    failure_reason          TEXT,
    retry_count             INT                 NOT NULL DEFAULT 0,

    created_at              TIMESTAMPTZ         NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ         NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_settlement_amounts CHECK (
        total_gross_amount >= 0 AND
        total_mdr_amount >= 0 AND
        total_net_amount >= 0 AND
        total_net_amount = total_gross_amount - total_mdr_amount
    )
);

-- Add FK from transactions to settlement_batches (now that the table exists)
ALTER TABLE transactions
    ADD CONSTRAINT fk_transactions_settlement
    FOREIGN KEY (settlement_id) REFERENCES settlement_batches(id) ON DELETE SET NULL;

CREATE INDEX idx_settlement_tenant_id        ON settlement_batches (tenant_id);
CREATE INDEX idx_settlement_merchant_id      ON settlement_batches (merchant_id);
CREATE INDEX idx_settlement_status           ON settlement_batches (tenant_id, status);
CREATE INDEX idx_settlement_date             ON settlement_batches (settlement_date);
-- Partial index: pending batches for settlement job to pick up
CREATE INDEX idx_settlement_pending          ON settlement_batches (settlement_date, merchant_id)
                                             WHERE status = 'PENDING';

COMMENT ON TABLE  settlement_batches                    IS 'Batched settlement per merchant per cycle. Created by settlement job.';
COMMENT ON COLUMN settlement_batches.bank_reference_number IS 'UTR number from the bank after NEFT/IMPS transfer. Filled post-settlement.';
COMMENT ON COLUMN settlement_batches.txn_from           IS 'Defines the settlement window — transactions between txn_from and txn_to are included.';
