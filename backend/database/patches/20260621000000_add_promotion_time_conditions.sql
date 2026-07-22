ALTER TABLE promotions
    ADD COLUMN IF NOT EXISTS valid_days TEXT NULL COMMENT 'JSON array of weekdays (0=Monday, 6=Sunday) or null for all',
    ADD COLUMN IF NOT EXISTS valid_hours TEXT NULL COMMENT 'JSON array of {from: HH:MM, until: HH:MM} ranges or null for all day';
