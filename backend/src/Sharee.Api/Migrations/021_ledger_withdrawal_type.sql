ALTER TABLE ledger_transactions DROP CONSTRAINT IF EXISTS ledger_transactions_type_check;
ALTER TABLE ledger_transactions ADD CONSTRAINT ledger_transactions_type_check
  CHECK (type IN ('payment','payout','refund','fee','adjustment','withdrawal'));
