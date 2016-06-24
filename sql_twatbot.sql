-- MySQL dump 10.13  Distrib 5.7.12, for Linux (x86_64)
--
-- Host: localhost    Database: moesizlak
-- ------------------------------------------------------
-- Server version	5.7.12-0ubuntu1

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `TitleBot`
--

DROP TABLE IF EXISTS `TitleBot`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `TitleBot` (
  `ID` int(6) NOT NULL AUTO_INCREMENT,
  `Date` datetime NOT NULL,
  `Nick` varchar(25) NOT NULL,
  `URL` varchar(200) NOT NULL,
  `Title` varchar(200) NOT NULL,
  `ImageFile` varchar(512) DEFAULT NULL,
  PRIMARY KEY (`ID`)
) ENGINE=MyISAM AUTO_INCREMENT=91376 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `WORDS1`
--

DROP TABLE IF EXISTS `WORDS1`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `WORDS1` (
  `Word1` varbinary(256) NOT NULL,
  `Word2` varbinary(256) NOT NULL,
  `Nick` varbinary(32) NOT NULL,
  KEY `Nick` (`Nick`),
  KEY `Word1Nick` (`Word1`,`Nick`),
  KEY `Word1Word2` (`Word1`,`Word2`),
  KEY `Word1` (`Word1`),
  KEY `Word2Nick` (`Word2`,`Nick`),
  KEY `Word2` (`Word2`),
  KEY `Word1Word2Nick` (`Word1`,`Word2`,`Nick`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `WORDS2`
--

DROP TABLE IF EXISTS `WORDS2`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `WORDS2` (
  `Word1` varbinary(256) NOT NULL,
  `Word2` varbinary(256) NOT NULL,
  `Word3` varbinary(256) NOT NULL,
  `Nick` varbinary(32) NOT NULL,
  KEY `Nick` (`Nick`),
  KEY `Word1Word2Nick` (`Word1`,`Word2`,`Nick`),
  KEY `Word1Word2Word3` (`Word1`,`Word2`,`Word3`),
  KEY `Word1Word2` (`Word1`,`Word2`),
  KEY `Word3Nick` (`Word3`,`Nick`),
  KEY `Word3Word2Nick` (`Word3`,`Word2`,`Nick`),
  KEY `Word3Word2` (`Word3`,`Word2`),
  KEY `Word3` (`Word3`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `quote_scr`
--

DROP TABLE IF EXISTS `quote_scr`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `quote_scr` (
  `handle` varchar(20) NOT NULL DEFAULT '0',
  `score` tinyint(2) unsigned NOT NULL DEFAULT '0',
  `id` tinytext NOT NULL,
  KEY `score` (`id`(6))
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `quotes`
--

DROP TABLE IF EXISTS `quotes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `quotes` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `nick` varchar(20) NOT NULL DEFAULT '',
  `host` varchar(255) NOT NULL DEFAULT '',
  `quote` mediumtext NOT NULL,
  `channel` varchar(50) NOT NULL DEFAULT '',
  `timestamp` bigint(20) DEFAULT NULL,
  `score` mediumint(10) NOT NULL DEFAULT '5',
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=1371 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2016-06-24 18:57:00
