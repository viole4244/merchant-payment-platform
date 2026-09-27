-- ============================================================
-- TABLE: mcc_categories
-- RBI-defined Merchant Category Codes — seeded, never user-edited
-- ============================================================

CREATE TABLE mcc_categories (
    code                    VARCHAR(4)      PRIMARY KEY,           -- 4-digit MCC e.g. '5411'
    description             VARCHAR(255)    NOT NULL,             -- "Grocery Stores, Supermarkets"
    rbi_category            rbi_category    NOT NULL,             -- RBI grouping
    rbi_max_mdr_percentage  DECIMAL(6,4)    NOT NULL DEFAULT 0,   -- Hard RBI cap (0 = free)
    rbi_max_flat_fee        DECIMAL(10,2),                        -- Hard cap on flat fee
    notes                   TEXT,                                 -- RBI circular references
    is_zero_mdr             BOOLEAN         NOT NULL DEFAULT false, -- true = RBI mandates 0% MDR
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  mcc_categories                     IS 'RBI-defined MCC codes. Seeded once, never user-modified.';
COMMENT ON COLUMN mcc_categories.rbi_max_mdr_percentage IS 'Your platform must enforce this cap. Cannot be overridden by tenant.';
COMMENT ON COLUMN mcc_categories.is_zero_mdr         IS 'Government, utility MCCs where RBI mandates 0 MDR';

-- ============================================================
-- TABLE: merchant_categories
-- Merchant size tiers (MICRO/SMALL/MEDIUM/LARGE/ENTERPRISE)
-- ============================================================

CREATE TABLE merchant_categories (
    id                      UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    name                    merchant_size   NOT NULL UNIQUE,
    annual_turnover_min     DECIMAL(15,2)   NOT NULL DEFAULT 0,
    annual_turnover_max     DECIMAL(15,2),                        -- NULL = no upper cap
    description             VARCHAR(255),
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  merchant_categories                IS 'Merchant size classification. Used in MDR rate matching.';
COMMENT ON COLUMN merchant_categories.annual_turnover_max IS 'NULL means no upper limit (ENTERPRISE tier)';
