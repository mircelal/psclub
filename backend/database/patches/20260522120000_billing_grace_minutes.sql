-- İlk saatdan sonra 30 dəq bloklara keçmədən əvvəl güzəşt (dəq).
ALTER TABLE businesses
    ADD COLUMN billing_grace_minutes INT UNSIGNED NOT NULL DEFAULT 10
    AFTER billing_increment_minutes;
