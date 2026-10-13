-- Crear tabla catalogo_info
CREATE TABLE IF NOT EXISTS `catalogo_info` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `telefono` varchar(255) NOT NULL,
  `email` varchar(255) NOT NULL,
  `direccion` text NOT NULL,
  `horarios_semana` varchar(255) NOT NULL DEFAULT 'Lun-Sáb: 8:00-20:00',
  `horarios_domingo` varchar(255) NOT NULL DEFAULT 'Dom: 9:00-14:00',
  `facebook_url` varchar(500) DEFAULT NULL,
  `instagram_url` varchar(500) DEFAULT NULL,
  `tiktok_url` varchar(500) DEFAULT NULL,
  `whatsapp_url` varchar(500) DEFAULT NULL,
  `grupos_whatsapp` json DEFAULT NULL,
  `descripcion_empresa` text DEFAULT NULL,
  `logo_url` varchar(500) DEFAULT NULL,
  `banner_url` varchar(500) DEFAULT NULL,
  `activo` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insertar datos por defecto
INSERT INTO `catalogo_info` (
  `telefono`, 
  `email`, 
  `direccion`, 
  `horarios_semana`, 
  `horarios_domingo`, 
  `facebook_url`, 
  `instagram_url`, 
  `tiktok_url`, 
  `whatsapp_url`, 
  `grupos_whatsapp`, 
  `descripcion_empresa`, 
  `activo`
) VALUES (
  '+591 74842996',
  'info@channels.com',
  'Calle Omiste entre Sucre, frente a Impuestos Nacionales',
  'Lun-Sáb: 8:00-20:00',
  'Dom: 9:00-14:00',
  'https://www.facebook.com/share/1BJs4XPzVu/',
  'https://www.instagram.com',
  'https://www.tiktok.com/@accesorioschannels',
  'https://wa.me/59174842996',
  JSON_ARRAY(
    JSON_OBJECT('name', 'Grupo 1', 'link', 'https://chat.whatsapp.com/LqwALOUhgol9k9uFSgkijy', 'members', '250+', 'status', 'activo'),
    JSON_OBJECT('name', 'Grupo 2', 'link', 'https://chat.whatsapp.com/D8Z4wfqn730A2MXEqxLIT3', 'members', '230+', 'status', 'activo'),
    JSON_OBJECT('name', 'Grupo 3', 'link', 'https://chat.whatsapp.com/CToEbetZpr0KCdffPK3W4A', 'members', '200+', 'status', 'activo'),
    JSON_OBJECT('name', 'Grupo 4', 'link', 'https://chat.whatsapp.com/C9bLWNAGXwYIO82AtOG98E', 'members', '245+', 'status', 'activo'),
    JSON_OBJECT('name', 'Grupo 5', 'link', 'https://chat.whatsapp.com/Gqn3BZSy9a5JQpBZBH2G53', 'members', '210+', 'status', 'nuevo'),
    JSON_OBJECT('name', 'Grupo 6', 'link', 'https://chat.whatsapp.com/BUQSFdzGQQ4FS0Abp4HjJs', 'members', '190+', 'status', 'activo')
  ),
  'Bisutería Channels - Los mejores accesorios para ti',
  1
); 