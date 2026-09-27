-- ============================================================
-- TABLE: tenant_admins
-- Axis/SBI bank employees who log in to manage their merchants
-- ============================================================

CREATE TABLE tenant_admins (
    id                  UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id           UUID            NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name                VARCHAR(255)    NOT NULL,
    email               VARCHAR(255)    NOT NULL UNIQUE,
    password_hash       VARCHAR(255)    NOT NULL,                  -- bcrypt
    role                admin_role      NOT NULL DEFAULT 'ADMIN',
    is_active           BOOLEAN         NOT NULL DEFAULT true,
    failed_login_count  INT             NOT NULL DEFAULT 0,
    locked_until        TIMESTAMPTZ,                               -- account lockout after N failures
    last_login_at       TIMESTAMPTZ,
    last_login_ip       VARCHAR(45),                               -- IPv4 or IPv6
    password_changed_at TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by          UUID            REFERENCES tenant_admins(id) ON DELETE SET NULL,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_tenant_admins_tenant_id ON tenant_admins (tenant_id);
CREATE INDEX idx_tenant_admins_email     ON tenant_admins (email);
CREATE INDEX idx_tenant_admins_role      ON tenant_admins (tenant_id, role);

COMMENT ON TABLE  tenant_admins                    IS 'Admin users for each tenant bank';
COMMENT ON COLUMN tenant_admins.role               IS 'SUPER_ADMIN can create other admins; ADMIN manages merchants/rates; VIEWER read-only';
COMMENT ON COLUMN tenant_admins.failed_login_count IS 'Reset to 0 on successful login';
COMMENT ON COLUMN tenant_admins.locked_until       IS 'Account locked if failed_login_count >= 5';
COMMENT ON COLUMN tenant_admins.password_changed_at IS 'Used to force 90-day password rotation';
