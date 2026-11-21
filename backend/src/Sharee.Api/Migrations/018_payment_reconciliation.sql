CREATE TABLE IF NOT EXISTS payment_reconciliation (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id uuid NOT NULL REFERENCES bookings(id),
  order_code text NOT NULL,
  amount integer NOT NULL,
  reason text NOT NULL,
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','refunded','resolved')),
  note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  UNIQUE (order_code)
);
CREATE INDEX IF NOT EXISTS payment_reconciliation_status_ix
  ON payment_reconciliation (status, created_at DESC);
