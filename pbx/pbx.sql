# ************************************************************
# Sequel Ace SQL dump
# Version 20102
#
# https://sequel-ace.com/
# https://github.com/Sequel-Ace/Sequel-Ace
#
# Host: 127.0.0.1 (MySQL 5.5.5-10.5.29-MariaDB-ubu2004-log)
# Database: pbx
# Generation Time: 2026-08-04 15:55:17 +0000
# ************************************************************


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
SET NAMES utf8mb4;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE='NO_AUTO_VALUE_ON_ZERO', SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;


# Dump of table access
# ------------------------------------------------------------

DROP TABLE IF EXISTS `access`;

CREATE TABLE `access` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `enabled` tinyint(1) DEFAULT 1,
  `admin` tinyint(1) DEFAULT 0,
  `name` varchar(256) DEFAULT NULL,
  `telephone` varchar(32) DEFAULT NULL,
  `email` varchar(256) DEFAULT NULL,
  `notification_state` tinyint(1) DEFAULT 0,
  `notify_before_end` int(11) DEFAULT 86400,
  `start` int(11) DEFAULT 0,
  `end` int(11) DEFAULT 0,
  `comment` text DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `telephone_idx` (`telephone`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;



# Dump of table log
# ------------------------------------------------------------

DROP TABLE IF EXISTS `log`;

CREATE TABLE `log` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `caller_id` varchar(16) DEFAULT NULL,
  `event` varchar(256) DEFAULT NULL,
  `unix_time` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;



# Dump of table sms_auth
# ------------------------------------------------------------

DROP TABLE IF EXISTS `sms_auth`;

CREATE TABLE `sms_auth` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `cookie_token` varchar(256) DEFAULT NULL,
  `session` tinyint(1) NOT NULL DEFAULT 0,
  `serial` varchar(16) DEFAULT NULL,
  `auth_state` set('new','login','sms_code_sent','sms_code_verified','deny') DEFAULT 'new',
  `phone` varchar(64) DEFAULT NULL,
  `sms_code` varchar(256) DEFAULT NULL,
  `remote_host` varchar(256) DEFAULT NULL,
  `orig_uri` longtext DEFAULT NULL,
  `user_agent` longtext DEFAULT NULL,
  `unix_time` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_cookie_token` (`cookie_token`(64)),
  KEY `idx_phone` (`phone`),
  KEY `idx_unix_time` (`unix_time`),
  KEY `idx_auth_state` (`auth_state`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;




/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;
/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
