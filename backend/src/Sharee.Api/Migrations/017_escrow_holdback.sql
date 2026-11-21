ALTER TABLE escrow_holds ADD COLUMN IF NOT EXISTS release_at timestamptz;
CREATE INDEX IF NOT EXISTS escrow_release_ix ON escrow_holds (status, release_at)
  WHERE status = 'held';

-- Preserve existing released holds; give still-held completed bookings a
-- short dispute window instead of releasing money immediately on completion.
UPDATE escrow_holds e
SET release_at = now() + interval '2 hours'
FROM bookings b
WHERE e.booking_id = b.id
  AND e.status = 'held'
  AND b.status = 'completed'
  AND e.release_at IS NULL;
