-- ============================================================
-- TABLE: outbox
-- Transactional Outbox pattern for reliable Kafka publishing.
-- Written in the SAME DB transaction as the business event.
-- A background worker polls this table and publishes to Kafka.
-- ============================================================

CREATE TABLE outbox (
    id                  UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    aggregate_type      VARCHAR(50)     NOT NULL,                  -- 'transaction', 'settlement', 'merchant'
    aggregate_id        UUID            NOT NULL,                  -- the ID of the row that triggered this
    topic               VARCHAR(255)    NOT NULL,                  -- Kafka topic name
    event_type          VARCHAR(100)    NOT NULL,                  -- e.g. 'transaction.created'
    payload             JSONB           NOT NULL,                  -- full event body
    status              outbox_status   NOT NULL DEFAULT 'PENDING',
    retry_count         INT             NOT NULL DEFAULT 0,
    max_retries         INT             NOT NULL DEFAULT 5,
    last_error          TEXT,                                      -- last failure reason
    process_after       TIMESTAMPTZ     NOT NULL DEFAULT NOW(),    -- enables delayed retry with backoff
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    published_at        TIMESTAMPTZ                                -- set when successfully published
);

-- Worker polls: WHERE status = 'PENDING' AND process_after <= NOW() ORDER BY created_at LIMIT 100 FOR UPDATE SKIP LOCKED
CREATE INDEX idx_outbox_pending         ON outbox (status, process_after)
                                        WHERE status = 'PENDING';
CREATE INDEX idx_outbox_aggregate       ON outbox (aggregate_type, aggregate_id);
CREATE INDEX idx_outbox_created_at      ON outbox (created_at);

COMMENT ON TABLE  outbox                    IS 'Transactional outbox for Kafka events. Worker polls and publishes asynchronously.';
COMMENT ON COLUMN outbox.process_after      IS 'Enables exponential backoff on retry. Worker only picks rows where process_after <= NOW().';
COMMENT ON COLUMN outbox.aggregate_id       IS 'Links back to the business entity (transaction_id, settlement_id etc.)';
COMMENT ON COLUMN outbox.payload            IS 'Complete event payload as it will be sent to Kafka. Immutable after insert.';

-- ============================================================
-- TABLE: audit_logs
-- Immutable record of every admin action.
-- Append-only — no UPDATE, no DELETE allowed (enforced in app).
-- ============================================================

CREATE TABLE audit_logs (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID            REFERENCES tenants(id) ON DELETE SET NULL,
    actor_id        UUID,                                          -- tenant_admin id or NULL for system
    actor_type      VARCHAR(50)     NOT NULL DEFAULT 'admin',      -- 'admin', 'system', 'api'
    action          VARCHAR(100)    NOT NULL,                      -- 'merchant.created', 'rate.updated'
    entity_type     VARCHAR(50)     NOT NULL,                      -- 'merchant', 'mdr_rate_config'
    entity_id       UUID            NOT NULL,
    old_value       JSONB,                                         -- before state
    new_value       JSONB,                                         -- after state
    ip_address      VARCHAR(45),
    user_agent      TEXT,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_tenant_id    ON audit_logs (tenant_id, created_at DESC);
CREATE INDEX idx_audit_entity       ON audit_logs (entity_type, entity_id);
CREATE INDEX idx_audit_actor        ON audit_logs (actor_id, created_at DESC);

COMMENT ON TABLE  audit_logs            IS 'Append-only audit trail. Never update or delete rows here.';
COMMENT ON COLUMN audit_logs.old_value  IS 'NULL for create actions';
COMMENT ON COLUMN audit_logs.new_value  IS 'NULL for delete actions';
