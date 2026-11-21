ALTER TABLE e_tickets ADD COLUMN IF NOT EXISTS failed_attempts integer NOT NULL DEFAULT 0;
