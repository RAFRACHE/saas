-- phpMyAdmin SQL Dump
-- version 5.1.1
-- https://www.phpmyadmin.net/
--
-- Hôte : 127.0.0.1
-- Généré le : mar. 15 nov. 2022 à 14:02
-- Version du serveur : 10.4.19-MariaDB
-- Version de PHP : 8.0.7

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Base de données : `master_tenant`
--

-- --------------------------------------------------------

--
-- Structure de la table `master_tenant`
--

CREATE TABLE `master_tenant` (
  `ID` varchar(255) NOT NULL,
  `PASSWORD` varchar(30) DEFAULT NULL,
  `TENANT` varchar(255) DEFAULT NULL,
  `URL` varchar(256) DEFAULT NULL,
  `USERNAME` varchar(30) DEFAULT NULL,
  `version` int(11) NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

--
-- Déchargement des données de la table `master_tenant`
--

INSERT INTO `master_tenant` (`ID`, `PASSWORD`, `TENANT`, `URL`, `USERNAME`, `version`) VALUES
('1', NULL, 'tenant01', 'jdbc:mysql://localhost:3306/tenant01?useSSL=false', 'root', 1),
('2', NULL, 'tenant02', 'jdbc:mysql://localhost:3306/tenant02?useSSL=false', 'root', 1);

--
-- Index pour les tables déchargées
--

--
-- Index pour la table `master_tenant`
--
ALTER TABLE `master_tenant`
  ADD PRIMARY KEY (`ID`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
