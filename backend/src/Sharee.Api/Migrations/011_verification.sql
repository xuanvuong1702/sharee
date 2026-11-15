ALTER TABLE users ADD COLUMN IF NOT EXISTS verification_status text NOT NULL DEFAULT 'unverified';
ALTER TABLE users ADD COLUMN IF NOT EXISTS verification_expires_at timestamptz;
ALTER TABLE users ADD COLUMN IF NOT EXISTS verification_submitted_at timestamptz;
ALTER TABLE users ADD COLUMN IF NOT EXISTS verification_reviewed_at timestamptz;
ALTER TABLE users ADD COLUMN IF NOT EXISTS verification_rejection_reason text;
ALTER TABLE users ADD COLUMN IF NOT EXISTS legal_name text;
ALTER TABLE users ADD COLUMN IF NOT EXISTS date_of_birth date;
ALTER TABLE users ADD COLUMN IF NOT EXISTS id_number text;
ALTER TABLE users ADD COLUMN IF NOT EXISTS id_issued_at date;
ALTER TABLE users ADD COLUMN IF NOT EXISTS id_expiry date;
ALTER TABLE users ADD COLUMN IF NOT EXISTS license_number text;
ALTER TABLE users ADD COLUMN IF NOT EXISTS license_class text;
ALTER TABLE users ADD COLUMN IF NOT EXISTS license_expiry date;
ALTER TABLE users ADD COLUMN IF NOT EXISTS vehicle_registration text;
ALTER TABLE users ADD COLUMN IF NOT EXISTS insurance_expiry date;

CREATE UNIQUE INDEX IF NOT EXISTS users_id_number_uq ON users (id_number) WHERE id_number IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS users_license_number_uq ON users (license_number) WHERE license_number IS NOT NULL;

CREATE TABLE IF NOT EXISTS verification_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type text NOT NULL CHECK (type IN (
    'id_front', 'id_back', 'license_front', 'license_back',
    'vehicle_registration', 'insurance', 'selfie'
  )),
  original_name text NOT NULL,
  stored_path text NOT NULL,
  mime_type text NOT NULL,
  size_bytes integer NOT NULL CHECK (size_bytes > 0 AND size_bytes <= 10485760),
  sha256 char(64) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, type)
);
CREATE INDEX IF NOT EXISTS verification_documents_user_ix ON verification_documents (user_id);

CREATE TABLE IF NOT EXISTS verification_events (
  id bigserial PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  actor_id uuid REFERENCES users(id),
  action text NOT NULL,
  detail jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Grandfather demo drivers created by the earlier seed.
UPDATE users
SET verification_status = 'approved',
    verification_expires_at = now() + interval '1 year',
    verification_submitted_at = coalesce(verification_submitted_at, now()),
    verification_reviewed_at = coalesce(verification_reviewed_at, now())
WHERE verified_level >= 3 AND verification_status = 'unverified';
