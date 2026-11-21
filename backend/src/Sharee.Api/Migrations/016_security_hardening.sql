-- Scope idempotency keys to the passenger+trip that created them. Keys are
-- client-generated; a global unique index lets one user block another user.
DROP INDEX IF EXISTS bookings_idem_uq;
CREATE UNIQUE INDEX IF NOT EXISTS bookings_idem_uq
  ON bookings (passenger_id, trip_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL;
