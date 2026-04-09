-- ============================================================
--  SCRIPT 03 — Execute SQL Tasks داخل الـ SSIS Package
--  هتحط كل Query دي في Execute SQL Task منفصلة
-- ============================================================

-- ════════════════════════════════════════════
-- Task 1A — Check & Create Database
-- (أول Execute SQL Task في الـ Package)
-- ════════════════════════════════════════════
/*
  Connection: master (مش RealEstate_Staging)
  لأن لازم تكون على master عشان تعمل CREATE DATABASE
*/
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'RealEstate_Staging')
BEGIN
    CREATE DATABASE RealEstate_Staging;
END
GO

-- ════════════════════════════════════════════
-- Task 1B — Create Schema & Tables
-- (تاني Execute SQL Task)
-- ════════════════════════════════════════════
/*
  Connection: RealEstate_Staging
*/
USE RealEstate_Staging;
GO

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'STG')
    EXEC('CREATE SCHEMA STG');
GO

-- بعدين نفذ Script 01 كامل لإنشاء الجداول

-- ════════════════════════════════════════════
-- Task 1C — Truncate Tables (قبل كل Load)
-- (تالت Execute SQL Task)
-- بنعمل Truncate عشان ميتراكمش داتا قديمة في الـ Staging
-- ════════════════════════════════════════════
USE RealEstate_Staging;

TRUNCATE TABLE STG.STG_Listings;
TRUNCATE TABLE STG.STG_Transactions;
TRUNCATE TABLE STG.STG_Agents;
TRUNCATE TABLE STG.STG_Currency;

INSERT INTO STG.STG_Load_Log (package_name, table_name, run_start, status)
VALUES ('RealEstate_Load_Staging', 'ALL_TABLES', GETDATE(), 'RUNNING');
GO
