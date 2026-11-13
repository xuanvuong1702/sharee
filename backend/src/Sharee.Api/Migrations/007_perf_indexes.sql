CREATE INDEX IF NOT EXISTS trips_status_departure_ix ON trips (status, departure_time);
CREATE INDEX IF NOT EXISTS bookings_passenger_ix ON bookings (passenger_id, created_at DESC);
CREATE INDEX IF NOT EXISTS bookings_trip_status_ix ON bookings (trip_id, status);
CREATE INDEX IF NOT EXISTS messages_conversation_ix ON messages (conversation_id, created_at);
CREATE INDEX IF NOT EXISTS notifications_user_ix ON notifications (user_id, read_at, created_at DESC);
CREATE INDEX IF NOT EXISTS trip_locations_trip_updated_ix ON trip_locations (trip_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS outbox_pending_ix ON outbox (next_attempt_at) WHERE processed_at IS NULL;
CREATE INDEX IF NOT EXISTS audit_logs_created_ix ON audit_logs (created_at DESC);
