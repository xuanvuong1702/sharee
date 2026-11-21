ALTER TABLE outbox ADD COLUMN IF NOT EXISTS dead_lettered_at timestamptz;
CREATE INDEX IF NOT EXISTS outbox_dead_ix ON outbox (dead_lettered_at) WHERE dead_lettered_at IS NOT NULL;

CREATE TABLE IF NOT EXISTS driver_withdrawals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id uuid NOT NULL REFERENCES users(id),
  amount integer NOT NULL CHECK (amount > 0),
  bank_name text NOT NULL,
  account_number text NOT NULL,
  account_name text NOT NULL,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','approved','paid','rejected')),
  provider_ref text,
  note text,
  requested_at timestamptz NOT NULL DEFAULT now(),
  processed_at timestamptz,
  processed_by uuid REFERENCES users(id)
);
CREATE INDEX IF NOT EXISTS driver_withdrawals_driver_ix
  ON driver_withdrawals (driver_id, requested_at DESC);
CREATE INDEX IF NOT EXISTS driver_withdrawals_queue_ix
  ON driver_withdrawals (status, requested_at);

CREATE TABLE IF NOT EXISTS booking_status_history (
  id bigserial PRIMARY KEY,
  booking_id uuid NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  from_status text,
  to_status text NOT NULL,
  actor_id uuid REFERENCES users(id),
  reason text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS booking_status_history_booking_ix
  ON booking_status_history (booking_id, created_at DESC);

CREATE OR REPLACE FUNCTION log_booking_status_change() RETURNS trigger AS $$
BEGIN
  IF TG_OP = 'INSERT' OR NEW.status IS DISTINCT FROM OLD.status THEN
    INSERT INTO booking_status_history (booking_id, from_status, to_status)
    VALUES (NEW.id, CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE OLD.status END, NEW.status);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS bookings_status_history_trg ON bookings;
CREATE TRIGGER bookings_status_history_trg
AFTER INSERT OR UPDATE OF status ON bookings
FOR EACH ROW EXECUTE FUNCTION log_booking_status_change();

CREATE TABLE IF NOT EXISTS payment_refunds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id uuid NOT NULL REFERENCES bookings(id),
  payment_id uuid REFERENCES payments(id),
  amount integer NOT NULL CHECK (amount > 0),
  reason text NOT NULL,
  provider text NOT NULL DEFAULT 'payos',
  provider_ref text,
  status text NOT NULL DEFAULT 'requested'
    CHECK (status IN ('requested','processing','succeeded','failed','manual')),
  error text,
  created_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz
);
CREATE INDEX IF NOT EXISTS payment_refunds_booking_ix
  ON payment_refunds (booking_id, created_at DESC);
