-- ============================================================
--  SCRIPT 01 — Create Staging Database & Tables
--  Run this ONCE manually OR let SSIS Execute SQL Task run it
--  No FK, No Constraints — Raw data as-is
-- ============================================================

-- ─────────────────────────────────────────────
-- STEP 1: Create Database if not exists
-- ─────────────────────────────────────────────
IF NOT EXISTS (
    SELECT name FROM sys.databases WHERE name = 'RealEstate_Staging'
)
BEGIN
    CREATE DATABASE RealEstate_Staging;
    PRINT '✅ Database RealEstate_Staging created.';
END
ELSE
BEGIN
    PRINT '⚠️  Database RealEstate_Staging already exists — skipped.';
END
GO

USE RealEstate_Staging;
GO

-- ─────────────────────────────────────────────
-- STEP 2: Create Schema
-- ─────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'STG')
BEGIN
    EXEC('CREATE SCHEMA STG');
    PRINT '✅ Schema STG created.';
END
GO

-- ─────────────────────────────────────────────
-- STEP 3: STG_Listings
--  Source: properties_listings.csv
--  كل الأعمدة NVARCHAR أو FLOAT لاستقبال الأخطاء
-- ─────────────────────────────────────────────
IF OBJECT_ID('STG.STG_Listings', 'U') IS NOT NULL
    DROP TABLE STG.STG_Listings;

CREATE TABLE STG.STG_Listings (
    -- Metadata
    stg_id              INT IDENTITY(1,1) PRIMARY KEY,
    load_date           DATETIME          DEFAULT GETDATE(),
    source_file         NVARCHAR(100)     DEFAULT 'properties_listings.csv',

    -- Raw columns (all NVARCHAR to accept dirty data)
    property_id         NVARCHAR(20),
    property_type       NVARCHAR(50),      -- may have typos: Apartmnt, Vlla
    city                NVARCHAR(100),     -- may be NULL
    country_code        NVARCHAR(10),
    currency_code       NVARCHAR(10),
    price_local         NVARCHAR(30),      -- may be negative string
    size_sqm            NVARCHAR(20),      -- may be NULL
    bedrooms            NVARCHAR(10),
    bathrooms           NVARCHAR(10),
    floor_number        NVARCHAR(10),
    year_built          NVARCHAR(10),
    amenities           NVARCHAR(500),
    listing_date        NVARCHAR(30),      -- may be YYYY/MM/DD or YYYY-MM-DD
    status              NVARCHAR(30),
    agent_id            NVARCHAR(20)
);
PRINT '✅ STG.STG_Listings created.';
GO

-- ─────────────────────────────────────────────
-- STEP 4: STG_Transactions
--  Source: properties_transactions.csv
-- ─────────────────────────────────────────────
IF OBJECT_ID('STG.STG_Transactions', 'U') IS NOT NULL
    DROP TABLE STG.STG_Transactions;

CREATE TABLE STG.STG_Transactions (
    stg_id              INT IDENTITY(1,1) PRIMARY KEY,
    load_date           DATETIME          DEFAULT GETDATE(),
    source_file         NVARCHAR(100)     DEFAULT 'properties_transactions.csv',

    transaction_id      NVARCHAR(20),
    property_id         NVARCHAR(20),      -- may be orphan (not in listings)
    agent_id            NVARCHAR(20),
    transaction_type    NVARCHAR(20),
    sale_price_local    NVARCHAR(30),
    currency_code       NVARCHAR(10),
    commission_pct      NVARCHAR(20),      -- may be negative
    commission_amount   NVARCHAR(30),
    transaction_date    NVARCHAR(30),      -- may be wrong format
    buyer_nationality   NVARCHAR(100),     -- may be NULL
    payment_method      NVARCHAR(50),      -- may have typos
    country_code        NVARCHAR(10)
);
PRINT '✅ STG.STG_Transactions created.';
GO

-- ─────────────────────────────────────────────
-- STEP 5: STG_Agents
--  Source: agents.txt (pipe-delimited)
-- ─────────────────────────────────────────────
IF OBJECT_ID('STG.STG_Agents', 'U') IS NOT NULL
    DROP TABLE STG.STG_Agents;

CREATE TABLE STG.STG_Agents (
    stg_id              INT IDENTITY(1,1) PRIMARY KEY,
    load_date           DATETIME          DEFAULT GETDATE(),
    source_file         NVARCHAR(100)     DEFAULT 'agents.txt',

    agent_id            NVARCHAR(20),
    agent_name          NVARCHAR(200),
    agency              NVARCHAR(200),
    specialization      NVARCHAR(100),
    country             NVARCHAR(10),
    phone               NVARCHAR(50),      -- may be 'N/A'
    email               NVARCHAR(200),
    hire_date           NVARCHAR(30),      -- may be wrong format
    active              NVARCHAR(10),      -- Y / Yes / 1 / TRUE — inconsistent
    experience_years    NVARCHAR(10)
);
PRINT '✅ STG.STG_Agents created.';
GO

-- ─────────────────────────────────────────────
-- STEP 6: STG_Currency
--  Source: Exchange Rate API (JSON)
--  SSIS Script Task هيملى الجدول ده
-- ─────────────────────────────────────────────
IF OBJECT_ID('STG.STG_Currency', 'U') IS NOT NULL
    DROP TABLE STG.STG_Currency;

CREATE TABLE STG.STG_Currency (
    stg_id              INT IDENTITY(1,1) PRIMARY KEY,
    load_date           DATETIME          DEFAULT GETDATE(),
    source_file         NVARCHAR(100)     DEFAULT 'Exchange Rate API',

    base_currency       NVARCHAR(10),      -- USD
    target_currency     NVARCHAR(10),      -- EGP / AED / GBP / SAR
    rate_to_base        FLOAT,             -- e.g. 48.5 (1 USD = 48.5 EGP)
    fetch_date          DATE               DEFAULT CAST(GETDATE() AS DATE)
);
PRINT '✅ STG.STG_Currency created.';
GO

-- ─────────────────────────────────────────────
-- STEP 7: STG_Load_Log  (مهمة جداً للـ Automation)
--  بتسجل كل مرة بيشتغل الـ Package
-- ─────────────────────────────────────────────
IF OBJECT_ID('STG.STG_Load_Log', 'U') IS NOT NULL
    DROP TABLE STG.STG_Load_Log;

CREATE TABLE STG.STG_Load_Log (
    log_id              INT IDENTITY(1,1) PRIMARY KEY,
    package_name        NVARCHAR(200),
    table_name          NVARCHAR(100),
    run_start           DATETIME,
    run_end             DATETIME,
    rows_loaded         INT,
    status              NVARCHAR(20),      -- SUCCESS / FAILED
    error_message       NVARCHAR(MAX)      NULL
);
PRINT '✅ STG.STG_Load_Log created.';
PRINT '';
PRINT '════════════════════════════════════════════';
PRINT '✅ ALL STAGING TABLES CREATED SUCCESSFULLY';
PRINT '════════════════════════════════════════════';
GO
