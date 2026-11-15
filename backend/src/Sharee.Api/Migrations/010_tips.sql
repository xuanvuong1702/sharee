CREATE TABLE IF NOT EXISTS driver_tip_accounts (
  driver_id uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  bank_bin char(6) NOT NULL CHECK (bank_bin ~ '^[0-9]{6}$'),
  bank_name text NOT NULL DEFAULT '',
  account_number text NOT NULL CHECK (account_number ~ '^[0-9]{6,19}$'),
  account_name text NOT NULL CHECK (char_length(account_name) BETWEEN 2 AND 80),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS tips (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id uuid NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  trip_id uuid NOT NULL REFERENCES trips(id),
  passenger_id uuid NOT NULL REFERENCES users(id),
  driver_id uuid NOT NULL REFERENCES users(id),
  amount integer NOT NULL CHECK (amount BETWEEN 1000 AND 1000000),
  message text CHECK (message IS NULL OR char_length(message) <= 200),
  method text NOT NULL CHECK (method IN ('bank_transfer', 'cash')),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'cancelled')),
  created_at timestamptz NOT NULL DEFAULT now(),
  sent_at timestamptz,
  confirmed_at timestamptz,
  cancelled_at timestamptz
);

CREATE UNIQUE INDEX IF NOT EXISTS tips_booking_passenger_uq
  ON tips (booking_id, passenger_id) WHERE status <> 'cancelled';
CREATE INDEX IF NOT EXISTS tips_driver_created_ix ON tips (driver_id, created_at DESC);
CREATE INDEX IF NOT EXISTS tips_booking_ix ON tips (booking_id);
CREATE INDEX IF NOT EXISTS tips_pending_ix ON tips (driver_id) WHERE status = 'pending';
