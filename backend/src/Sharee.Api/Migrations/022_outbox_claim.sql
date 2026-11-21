ALTER TABLE outbox ADD COLUMN IF NOT EXISTS claimed_at timestamptz;
CREATE INDEX IF NOT EXISTS outbox_claim_ix ON outbox (next_attempt_at, claimed_at)
  WHERE processed_at IS NULL AND dead_lettered_at IS NULL;
