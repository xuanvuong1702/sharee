ALTER TABLE driver_withdrawals ADD COLUMN IF NOT EXISTS approved_by uuid REFERENCES users(id);
ALTER TABLE driver_withdrawals ADD COLUMN IF NOT EXISTS processing_started_at timestamptz;
ALTER TABLE driver_withdrawals ADD COLUMN IF NOT EXISTS idempotency_key text;
ALTER TABLE driver_withdrawals ADD COLUMN IF NOT EXISTS failure_reason text;
ALTER TABLE driver_withdrawals DROP CONSTRAINT IF EXISTS driver_withdrawals_status_check;
ALTER TABLE driver_withdrawals ADD CONSTRAINT driver_withdrawals_status_check
  CHECK (status IN ('pending','approved','processing','paid','rejected','failed'));
CREATE UNIQUE INDEX IF NOT EXISTS driver_withdrawals_idem_uq
  ON driver_withdrawals (idempotency_key) WHERE idempotency_key IS NOT NULL;
