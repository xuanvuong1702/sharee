CREATE OR REPLACE FUNCTION check_ledger_transaction_balance() RETURNS trigger AS $$
DECLARE
  debit bigint;
  credit bigint;
BEGIN
  SELECT coalesce(sum(amount) FILTER (WHERE direction = 'D'), 0),
         coalesce(sum(amount) FILTER (WHERE direction = 'C'), 0)
  INTO debit, credit
  FROM ledger_entries WHERE txn_id = COALESCE(NEW.txn_id, OLD.txn_id);

  IF debit <> credit THEN
    RAISE EXCEPTION 'Unbalanced ledger transaction %: debit=% credit=%',
      COALESCE(NEW.txn_id, OLD.txn_id), debit, credit
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS ledger_balance_trg ON ledger_entries;
CREATE CONSTRAINT TRIGGER ledger_balance_trg
AFTER INSERT OR UPDATE OR DELETE ON ledger_entries
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION check_ledger_transaction_balance();
