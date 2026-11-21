ALTER TABLE driver_tip_accounts DROP CONSTRAINT IF EXISTS driver_tip_accounts_account_number_check;
ALTER TABLE driver_tip_accounts ADD CONSTRAINT driver_tip_accounts_account_number_check
  CHECK (account_number ~ '^[0-9]{6,19}$' OR account_number ~ '^enc:v1:[A-Za-z0-9+/=]+$');
