ALTER TABLE trips ADD COLUMN IF NOT EXISTS tracking_status text NOT NULL DEFAULT 'scheduled';
ALTER TABLE trips ADD COLUMN IF NOT EXISTS started_at timestamptz;
ALTER TABLE trips ADD COLUMN IF NOT EXISTS completed_at timestamptz;

CREATE TABLE IF NOT EXISTS trip_locations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id uuid NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role text NOT NULL,
  lat double precision NOT NULL,
  lng double precision NOT NULL,
  heading double precision,
  speed double precision,
  accuracy double precision,
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (trip_id, user_id)
);

CREATE INDEX IF NOT EXISTS trip_locations_trip_ix ON trip_locations (trip_id, role);
