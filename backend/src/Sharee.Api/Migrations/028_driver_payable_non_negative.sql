CREATE OR REPLACE FUNCTION check_driver_payable_non_negative() RETURNS trigger AS $$
DECLARE
  bal bigint;
BEGIN
  IF NEW.account <> 'driver_payable' THEN RETURN NEW; END IF;
  SELECT coalesce(sum(CASE WHEN direction = 'C' THEN amount ELSE -amount END), 0)
  INTO bal FROM ledger_entries WHERE account = 'driver_payable';
  IF bal < 0 THEN
    RAISE EXCEPTION 'driver_payable balance cannot be negative: %', bal
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS driver_payable_non_negative_trg ON ledger_entries;
CREATE TRIGGER driver_payable_non_negative_trg
BEFORE INSERT ON ledger_entries
FOR EACH ROW EXECUTE FUNCTION check_driver_payable_non_negative();
