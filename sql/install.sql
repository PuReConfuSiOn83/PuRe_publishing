CREATE TABLE IF NOT EXISTS `pure_publishing_documents` (
  `id` varchar(64) NOT NULL,
  `type` varchar(20) NOT NULL,
  `title` varchar(90) NOT NULL,
  `subtitle` varchar(160) DEFAULT NULL,
  `content` longtext NOT NULL,
  `status` enum('draft','published','archived') NOT NULL DEFAULT 'draft',
  `owner_identifier` varchar(100) NOT NULL,
  `author_name` varchar(100) NOT NULL DEFAULT 'Redaktion',
  `published_at` datetime DEFAULT NULL,
  `expires_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_pure_pub_type_status` (`type`,`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `pure_publishing_editions` (
  `id` varchar(64) NOT NULL,
  `document_id` varchar(64) NOT NULL,
  `snapshot` longtext NOT NULL,
  `published_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_pure_pub_edition_date` (`published_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `pure_publishing_locations` (
  `id` varchar(64) NOT NULL,
  `label` varchar(80) NOT NULL,
  `document_id` varchar(64) NOT NULL,
  `x` double NOT NULL,
  `y` double NOT NULL,
  `z` double NOT NULL,
  `heading` float NOT NULL DEFAULT 0,
  `created_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_pure_pub_location_doc` (`document_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
