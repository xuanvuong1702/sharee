CREATE TABLE IF NOT EXISTS recurring_trips (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  vehicle_id uuid NOT NULL REFERENCES vehicles(id),
  origin geography(Point,4326) NOT NULL,
  destination geography(Point,4326) NOT NULL,
  origin_label text NOT NULL,
  destination_label text NOT NULL,
  route geography(LineString,4326),
  distance_m integer NOT NULL DEFAULT 0,
  duration_s integer NOT NULL DEFAULT 0,
  departure_time time NOT NULL,
  weekdays smallint[] NOT NULL,
  price_per_seat integer NOT NULL,
  seats_total smallint NOT NULL,
  booking_mode text NOT NULL DEFAULT 'instant',
  luggage boolean NOT NULL DEFAULT true,
  pets_allowed boolean NOT NULL DEFAULT false,
  smoking_allowed boolean NOT NULL DEFAULT false,
  active boolean NOT NULL DEFAULT true,
  valid_from date NOT NULL DEFAULT current_date,
  valid_to date,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS recurring_trip_stops (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  recurring_trip_id uuid NOT NULL REFERENCES recurring_trips(id) ON DELETE CASCADE,
  seq smallint NOT NULL,
  name text NOT NULL,
  location geography(Point,4326) NOT NULL,
  eta_offset_min integer NOT NULL DEFAULT 0,
  allow_pickup boolean NOT NULL DEFAULT true,
  allow_dropoff boolean NOT NULL DEFAULT true,
  price_from_origin integer NOT NULL DEFAULT 0,
  UNIQUE (recurring_trip_id, seq)
);

ALTER TABLE trips ADD COLUMN IF NOT EXISTS source_recurring_id uuid;
ALTER TABLE trips
  ADD CONSTRAINT trips_source_recurring_fk
  FOREIGN KEY (source_recurring_id) REFERENCES recurring_trips(id) ON DELETE SET NULL;

CREATE UNIQUE INDEX IF NOT EXISTS trips_recurring_slot_uq
  ON trips (source_recurring_id, departure_time)
  WHERE source_recurring_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS recurring_driver_ix ON recurring_trips (driver_id, active);
