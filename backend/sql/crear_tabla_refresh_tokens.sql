CREATE TABLE IF NOT EXISTS `refresh_tokens` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `token` VARCHAR(255) NOT NULL UNIQUE,
  `user_id` INT NOT NULL,
  `expires_at` DATETIME NOT NULL,
  `revoked` TINYINT(1) NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_refresh_token_user` FOREIGN KEY (`user_id`) 
    REFERENCES `usuarios` (`id`) ON DELETE CASCADE
);

-- Crear índice para búsqueda rápida por token
CREATE INDEX `idx_refresh_token` ON `refresh_tokens` (`token`);
