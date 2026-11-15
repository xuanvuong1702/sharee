ALTER TABLE bookings ADD COLUMN IF NOT EXISTS payment_method text NOT NULL DEFAULT 'payos';

CREATE TABLE IF NOT EXISTS escrow_holds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id uuid NOT NULL UNIQUE REFERENCES bookings(id) ON DELETE CASCADE,
  amount integer NOT NULL CHECK (amount > 0),
  currency char(3) NOT NULL DEFAULT 'VND',
  method text NOT NULL DEFAULT 'payos',
  status text NOT NULL DEFAULT 'held'
    CHECK (status IN ('held','cash_pending','released','refunded','disputed','partial_refunded')),
  held_at timestamptz NOT NULL DEFAULT now(),
  released_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS escrow_status_ix ON escrow_holds (status);

CREATE TABLE IF NOT EXISTS appeals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id uuid NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  opened_by uuid NOT NULL REFERENCES users(id),
  against_id uuid NOT NULL REFERENCES users(id),
  reason text NOT NULL,
  description text NOT NULL,
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','investigating','resolved','rejected','cancelled')),
  resolution text,
  resolution_note text,
  resolved_by uuid REFERENCES users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz
);
CREATE UNIQUE INDEX IF NOT EXISTS appeals_open_uq
  ON appeals (booking_id) WHERE status IN ('open','investigating');
CREATE INDEX IF NOT EXISTS appeals_status_ix ON appeals (status, created_at DESC);

CREATE TABLE IF NOT EXISTS appeal_evidence (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  appeal_id uuid NOT NULL REFERENCES appeals(id) ON DELETE CASCADE,
  uploader_id uuid NOT NULL REFERENCES users(id),
  original_name text NOT NULL,
  stored_path text NOT NULL,
  mime_type text NOT NULL,
  size_bytes integer NOT NULL CHECK (size_bytes > 0 AND size_bytes <= 10485760),
  sha256 char(64) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS appeal_evidence_appeal_ix ON appeal_evidence (appeal_id);

-- Backfill escrow for bookings that were confirmed/completed before this feature.
INSERT INTO escrow_holds (booking_id, amount, method, status, held_at, released_at)
SELECT b.id, b.price_total, 'legacy',
       CASE WHEN b.status = 'completed' THEN 'released' ELSE 'held' END,
       b.created_at, CASE WHEN b.status = 'completed' THEN b.updated_at ELSE NULL END
FROM bookings b
WHERE b.status IN ('confirmed','completed')
ON CONFLICT (booking_id) DO NOTHING;
