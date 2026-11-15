CREATE INDEX IF NOT EXISTS users_verification_status_ix ON users (verification_status, role);
CREATE INDEX IF NOT EXISTS bookings_passenger_status_ix ON bookings (passenger_id, status);
CREATE INDEX IF NOT EXISTS bookings_trip_status_ix ON bookings (trip_id, status);
CREATE INDEX IF NOT EXISTS appeals_booking_ix ON appeals (booking_id, created_at DESC);
CREATE INDEX IF NOT EXISTS ledger_ref_ix ON ledger_transactions (ref_type, ref_id, type);
