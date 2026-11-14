ALTER TABLE payments ADD COLUMN IF NOT EXISTS payment_link_id text;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS metadata jsonb NOT NULL DEFAULT '{}'::jsonb;
CREATE INDEX IF NOT EXISTS payments_status_ix ON payments (status, created_at DESC);
