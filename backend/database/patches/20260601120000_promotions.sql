CREATE TABLE IF NOT EXISTS promotions (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  business_id INT UNSIGNED NOT NULL DEFAULT 1,
  name VARCHAR(120) NOT NULL,
  discount_type ENUM('percent','fixed') NOT NULL,
  discount_value DECIMAL(10,2) NOT NULL DEFAULT 0,
  applies_to ENUM('time_only') NOT NULL DEFAULT 'time_only',
  scope ENUM('all_tables','tariffs') NOT NULL DEFAULT 'all_tables',
  tariff_names TEXT NULL COMMENT 'JSON array when scope=tariffs',
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  valid_from DATETIME NULL,
  valid_until DATETIME NULL,
  sort_order INT NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
