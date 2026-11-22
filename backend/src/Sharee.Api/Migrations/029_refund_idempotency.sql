CREATE UNIQUE INDEX IF NOT EXISTS payment_refunds_idem_uq
  ON payment_refunds (booking_id, amount, reason)
  WHERE status IN ('processing','succeeded','requested');
