ALTER TABLE transactions DROP CONSTRAINT IF EXISTS fk_transactions_settlement;
DROP TABLE IF EXISTS settlement_batches;
