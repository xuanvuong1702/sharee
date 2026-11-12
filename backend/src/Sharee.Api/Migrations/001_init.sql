CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  phone text NOT NULL UNIQUE,
  email text,
  full_name text NOT NULL,
  avatar_url text,
  bio text,
  role text NOT NULL DEFAULT 'user' CHECK (role IN ('user','admin')),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','blocked')),
  verified_level smallint NOT NULL DEFAULT 1,
  rating_avg numeric(3,2) NOT NULL DEFAULT 0,
  rating_count integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS user_verifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type text NOT NULL CHECK (type IN ('phone','id','license','vehicle')),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  document_ref text,
  reviewed_by uuid REFERENCES users(id),
  reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS vehicles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  make text NOT NULL,
  model text NOT NULL,
  year smallint,
  color text,
  plate text NOT NULL,
  seats smallint NOT NULL CHECK (seats BETWEEN 2 AND 9),
  photo_url text,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','hidden')),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS trips (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id uuid NOT NULL REFERENCES users(id),
  vehicle_id uuid NOT NULL REFERENCES vehicles(id),
  origin geography(Point,4326) NOT NULL,
  destination geography(Point,4326) NOT NULL,
  origin_label text NOT NULL,
  destination_label text NOT NULL,
  route geography(LineString,4326),
  distance_m integer NOT NULL DEFAULT 0,
  duration_s integer NOT NULL DEFAULT 0,
  departure_time timestamptz NOT NULL,
  arrive_estimate timestamptz NOT NULL,
  price_per_seat integer NOT NULL CHECK (price_per_seat >= 0),
  seats_total smallint NOT NULL CHECK (seats_total BETWEEN 1 AND 8),
  seats_available smallint NOT NULL CHECK (seats_available >= 0),
  booking_mode text NOT NULL DEFAULT 'instant' CHECK (booking_mode IN ('instant','manual')),
  luggage boolean NOT NULL DEFAULT true,
  pets_allowed boolean NOT NULL DEFAULT false,
  smoking_allowed boolean NOT NULL DEFAULT false,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('draft','open','full','ongoing','completed','cancelled')),
  version integer NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (seats_available <= seats_total)
);

CREATE TABLE IF NOT EXISTS trip_stops (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id uuid NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  seq smallint NOT NULL,
  name text NOT NULL,
  location geography(Point,4326) NOT NULL,
  eta_offset_min integer NOT NULL DEFAULT 0,
  allow_pickup boolean NOT NULL DEFAULT true,
  allow_dropoff boolean NOT NULL DEFAULT true,
  price_from_origin integer NOT NULL DEFAULT 0,
  UNIQUE (trip_id, seq)
);

CREATE TABLE IF NOT EXISTS bookings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id uuid NOT NULL REFERENCES trips(id),
  passenger_id uuid NOT NULL REFERENCES users(id),
  from_stop_id uuid NOT NULL REFERENCES trip_stops(id),
  to_stop_id uuid NOT NULL REFERENCES trip_stops(id),
  seats smallint NOT NULL CHECK (seats > 0),
  price_total integer NOT NULL,
  fee_amount integer NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'pending_payment'
    CHECK (status IN ('pending_driver','pending_payment','confirmed','completed',
                      'cancelled_by_passenger','cancelled_by_driver','rejected','expired','refunded')),
  idempotency_key text,
  expires_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS bookings_idem_uq ON bookings (idempotency_key) WHERE idempotency_key IS NOT NULL;
CREATE INDEX IF NOT EXISTS bookings_trip_ix ON bookings (trip_id) WHERE status IN ('pending_driver','pending_payment','confirmed');

CREATE TABLE IF NOT EXISTS payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id uuid NOT NULL UNIQUE REFERENCES bookings(id),
  provider text NOT NULL DEFAULT 'mock',
  provider_ref text,
  amount integer NOT NULL,
  currency char(3) NOT NULL DEFAULT 'VND',
  status text NOT NULL CHECK (status IN ('requires_capture','succeeded','refunded','failed')),
  captured_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS payments_provider_uq ON payments (provider, provider_ref);

CREATE TABLE IF NOT EXISTS ledger_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  type text NOT NULL CHECK (type IN ('payment','payout','refund','fee','adjustment')),
  ref_type text NOT NULL,
  ref_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS ledger_entries (
  id bigserial PRIMARY KEY,
  txn_id uuid NOT NULL REFERENCES ledger_transactions(id) ON DELETE CASCADE,
  account text NOT NULL,
  direction char(1) NOT NULL CHECK (direction IN ('D','C')),
  amount bigint NOT NULL CHECK (amount > 0),
  currency char(3) NOT NULL DEFAULT 'VND',
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ledger_txn_ix ON ledger_entries (txn_id);

CREATE TABLE IF NOT EXISTS conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id uuid NOT NULL UNIQUE REFERENCES bookings(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  sender_id uuid NOT NULL REFERENCES users(id),
  body text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  read_at timestamptz
);
CREATE INDEX IF NOT EXISTS messages_conv_ix ON messages (conversation_id, created_at);

CREATE TABLE IF NOT EXISTS reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id uuid NOT NULL REFERENCES bookings(id),
  reviewer_id uuid NOT NULL REFERENCES users(id),
  reviewee_id uuid NOT NULL REFERENCES users(id),
  role text NOT NULL CHECK (role IN ('passenger','driver')),
  rating smallint NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment text,
  published_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (booking_id, reviewer_id)
);

CREATE TABLE IF NOT EXISTS reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id uuid NOT NULL REFERENCES users(id),
  target_type text NOT NULL CHECK (target_type IN ('user','trip','booking')),
  target_id uuid NOT NULL,
  reason text NOT NULL,
  description text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','resolved','dismissed')),
  handled_by uuid REFERENCES users(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type text NOT NULL,
  title text NOT NULL,
  body text NOT NULL,
  data jsonb,
  read_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS audit_logs (
  id bigserial PRIMARY KEY,
  actor_id uuid REFERENCES users(id),
  action text NOT NULL,
  target_type text,
  target_id text,
  meta jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS outbox (
  id bigserial PRIMARY KEY,
  aggregate_type text NOT NULL,
  aggregate_id uuid NOT NULL,
  type text NOT NULL,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  attempts integer NOT NULL DEFAULT 0,
  next_attempt_at timestamptz NOT NULL DEFAULT now(),
  processed_at timestamptz,
  last_error text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS partners (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  type text NOT NULL CHECK (type IN ('collectivite','entreprise')),
  currency char(3) NOT NULL DEFAULT 'VND',
  status text NOT NULL DEFAULT 'active',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS lines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_id uuid NOT NULL REFERENCES partners(id),
  name text NOT NULL,
  brand text,
  description text,
  route geography(LineString,4326),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','paused')),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS line_stops (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  line_id uuid NOT NULL REFERENCES lines(id) ON DELETE CASCADE,
  seq smallint NOT NULL,
  name text NOT NULL,
  location geography(Point,4326) NOT NULL,
  qr_token text NOT NULL UNIQUE,
  UNIQUE (line_id, seq)
);

CREATE TABLE IF NOT EXISTS line_service_windows (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  line_id uuid NOT NULL REFERENCES lines(id) ON DELETE CASCADE,
  weekday smallint NOT NULL CHECK (weekday BETWEEN 1 AND 7),
  start_time time NOT NULL,
  end_time time NOT NULL,
  headway_min smallint NOT NULL DEFAULT 10
);

CREATE TABLE IF NOT EXISTS e_tickets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  passenger_id uuid NOT NULL REFERENCES users(id),
  line_id uuid NOT NULL REFERENCES lines(id),
  stop_id uuid NOT NULL REFERENCES line_stops(id),
  driver_id uuid REFERENCES users(id),
  status text NOT NULL DEFAULT 'waiting' CHECK (status IN ('waiting','assigned','picked_up','validated','expired','cancelled')),
  code char(4) NOT NULL,
  qr_token text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  assigned_at timestamptz,
  validated_at timestamptz
);

CREATE TABLE IF NOT EXISTS trip_validations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  e_ticket_id uuid NOT NULL UNIQUE REFERENCES e_tickets(id),
  driver_id uuid NOT NULL REFERENCES users(id),
  validated_at timestamptz NOT NULL DEFAULT now(),
  location geography(Point,4326),
  method text NOT NULL DEFAULT 'code' CHECK (method IN ('qr','code','gps')),
  distance_km numeric(6,2) NOT NULL DEFAULT 0,
  amount_minor bigint NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS subsidy_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_id uuid NOT NULL REFERENCES partners(id),
  line_id uuid REFERENCES lines(id),
  per_km_minor bigint NOT NULL,
  min_amount_minor bigint NOT NULL,
  max_amount_minor bigint NOT NULL,
  monthly_cap_minor bigint NOT NULL,
  effective_from date NOT NULL,
  effective_to date
);

CREATE TABLE IF NOT EXISTS driver_earnings (
  id bigserial PRIMARY KEY,
  driver_id uuid NOT NULL REFERENCES users(id),
  validation_id uuid NOT NULL UNIQUE REFERENCES trip_validations(id),
  amount_minor bigint NOT NULL,
  period date NOT NULL,
  status text NOT NULL DEFAULT 'accrued',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS trips_route_gix ON trips USING GIST (route);
CREATE INDEX IF NOT EXISTS trips_origin_gix ON trips USING GIST (origin);
CREATE INDEX IF NOT EXISTS trips_dest_gix ON trips USING GIST (destination);
CREATE INDEX IF NOT EXISTS trips_depart_ix ON trips (departure_time) WHERE status = 'open' AND seats_available > 0;
CREATE INDEX IF NOT EXISTS stops_trip_seq_ix ON trip_stops (trip_id, seq);
CREATE INDEX IF NOT EXISTS stops_loc_gix ON trip_stops USING GIST (location);
CREATE INDEX IF NOT EXISTS line_stops_loc_gix ON line_stops USING GIST (location);
CREATE INDEX IF NOT EXISTS bookings_passenger_ix ON bookings (passenger_id, created_at DESC);
CREATE INDEX IF NOT EXISTS tickets_passenger_ix ON e_tickets (passenger_id, created_at DESC);
