CREATE OR REPLACE FUNCTION enforce_booking_status_transition() RETURNS trigger AS $$
DECLARE
  allowed boolean := false;
BEGIN
  IF TG_OP = 'INSERT' OR NEW.status = OLD.status THEN
    RETURN NEW;
  END IF;

  allowed := CASE OLD.status
    WHEN 'pending_payment' THEN NEW.status IN
      ('confirmed','cancelled_by_passenger','cancelled_by_driver','expired','rejected','refunded')
    WHEN 'pending_driver' THEN NEW.status IN
      ('confirmed','cancelled_by_passenger','cancelled_by_driver','expired','rejected','refunded')
    WHEN 'confirmed' THEN NEW.status IN
      ('completed','cancelled_by_passenger','cancelled_by_driver','refunded')
    WHEN 'completed' THEN NEW.status IN ('refunded')
    WHEN 'cancelled_by_passenger' THEN NEW.status IN ('refunded')
    WHEN 'cancelled_by_driver' THEN NEW.status IN ('refunded')
    WHEN 'rejected' THEN NEW.status IN ('refunded')
    WHEN 'expired' THEN NEW.status IN ('refunded')
    WHEN 'refunded' THEN false
    ELSE false
  END;

  IF NOT allowed THEN
    RAISE EXCEPTION 'Invalid booking status transition % -> %', OLD.status, NEW.status
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS bookings_status_transition_trg ON bookings;
CREATE TRIGGER bookings_status_transition_trg
BEFORE UPDATE OF status ON bookings
FOR EACH ROW EXECUTE FUNCTION enforce_booking_status_transition();
