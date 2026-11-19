CREATE TABLE IF NOT EXISTS driver_presence (
  driver_id uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  vehicle_id uuid REFERENCES vehicles(id) ON DELETE SET NULL,
  online boolean NOT NULL DEFAULT false,
  location geography(Point, 4326) NOT NULL,
  heading real,
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS driver_presence_geo_ix ON driver_presence USING gist (location);
CREATE INDEX IF NOT EXISTS driver_presence_online_ix ON driver_presence (online, updated_at DESC);

CREATE TABLE IF NOT EXISTS ride_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  passenger_id uuid NOT NULL REFERENCES users(id),
  pickup geography(Point, 4326) NOT NULL,
  dropoff geography(Point, 4326) NOT NULL,
  pickup_label text NOT NULL,
  dropoff_label text NOT NULL,
  vehicle_class text NOT NULL DEFAULT 'car',
  payment_method text NOT NULL DEFAULT 'cash'
    CHECK (payment_method IN ('cash', 'bank', 'wallet')),
  note text,
  status text NOT NULL DEFAULT 'searching'
    CHECK (status IN ('searching','accepted','driver_arriving','arrived','in_progress','completed','cancelled','expired')),
  driver_id uuid REFERENCES users(id),
  vehicle_id uuid REFERENCES vehicles(id),
  accepted_at timestamptz,
  arrived_at timestamptz,
  started_at timestamptz,
  completed_at timestamptz,
  cancelled_at timestamptz,
  cancel_reason text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ride_requests_passenger_ix ON ride_requests (passenger_id, created_at DESC);
CREATE INDEX IF NOT EXISTS ride_requests_driver_ix ON ride_requests (driver_id, status);
CREATE INDEX IF NOT EXISTS ride_requests_status_ix ON ride_requests (status, created_at DESC);

-- Demo drivers must be able to go online/accept without uploading documents.
-- Production accounts still go through the normal KYC review.
UPDATE users
SET verification_status = 'approved',
    verified_level = 3,
    verification_expires_at = now() + interval '1 year',
    legal_name = coalesce(legal_name, full_name),
    date_of_birth = coalesce(date_of_birth, date '1990-01-01'),
    id_number = coalesce(id_number, 'DEMO-' || right(phone, 6)),
    license_number = coalesce(license_number, 'DEMO-LX-' || right(phone, 6)),
    license_expiry = coalesce(license_expiry, current_date + interval '1 year')
WHERE phone IN ('+84912000001', '+84912000002')
  AND email LIKE '%@example.com';

-- Demo presence so the passenger sees nearby cars immediately.
INSERT INTO driver_presence (driver_id, vehicle_id, online, location, heading)
SELECT u.id, v.id, true,
       ST_SetSRID(ST_MakePoint(s.lng, s.lat), 4326)::geography,
       s.heading
FROM (VALUES
  ('+84912000001', 105.7800, 21.0300, 90.0),
  ('+84912000002', 105.7700, 21.0180, 180.0)
) AS s(phone, lng, lat, heading)
JOIN users u ON u.phone = s.phone
JOIN LATERAL (
  SELECT id FROM vehicles WHERE owner_id = u.id AND status = 'active' ORDER BY created_at LIMIT 1
) v ON true
ON CONFLICT (driver_id) DO NOTHING;
