-- Enforce strict verification: any legacy "approved" record without complete
-- legal identity/licence data must re-submit documents.
UPDATE users
SET verification_status = 'unverified',
    verified_level = 1,
    verification_expires_at = NULL
WHERE verification_status = 'approved'
  AND (id_number IS NULL OR license_number IS NULL);
