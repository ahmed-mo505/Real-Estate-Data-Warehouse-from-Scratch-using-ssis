-- ============================================================
--  SCRIPT 02 — Create DWH Database — Star Schema
--  Dimension Tables first, then Fact Table (FK dependency)
--  Run AFTER Staging is loaded & transformed
-- ============================================================

-- ─────────────────────────────────────────────
-- STEP 1: Create Database
-- ─────────────────────────────────────────────
IF NOT EXISTS (
    SELECT name FROM sys.databases WHERE name = 'RealEstate_DWH'
)
BEGIN
    CREATE DATABASE RealEstate_DWH;
    PRINT '✅ Database RealEstate_DWH created.';
END
ELSE
    PRINT '⚠️  Database RealEstate_DWH already exists — skipped.';
GO

USE RealEstate_DWH;
GO

-- ─────────────────────────────────────────────
-- STEP 2: Schemas
-- ─────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'DIM')
    EXEC('CREATE SCHEMA DIM');

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'FACT')
    EXEC('CREATE SCHEMA FACT');
GO

-- ════════════════════════════════════════════════════════
--  DIMENSION TABLES  (بنبني الـ Dims الأول عشان الـ Fact محتاجة الـ Keys)
-- ════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────
-- DIM_Date  (بنملأها بكود SQL — مش بـ SSIS)
-- ─────────────────────────────────────────────
IF OBJECT_ID('DIM.DIM_Date', 'U') IS NOT NULL
    DROP TABLE DIM.DIM_Date;

CREATE TABLE DIM.DIM_Date (
    date_key            INT             PRIMARY KEY,   -- YYYYMMDD e.g. 20240115
    full_date           DATE            NOT NULL,
    day_of_week         TINYINT,                       -- 1=Sunday ... 7=Saturday
    day_name            NVARCHAR(15),
    day_of_month        TINYINT,
    day_of_year         SMALLINT,
    week_of_year        TINYINT,
    month_number        TINYINT,
    month_name          NVARCHAR(15),
    quarter_number      TINYINT,
    quarter_name        NCHAR(2),                      -- Q1, Q2, Q3, Q4
    year_number         SMALLINT,
    is_weekend          BIT,
    is_weekday          BIT
);
PRINT '✅ DIM.DIM_Date created.';

-- Populate DIM_Date (2020 → 2026)
DECLARE @d DATE = '2020-01-01';
DECLARE @end DATE = '2026-12-31';

WHILE @d <= @end
BEGIN
    INSERT INTO DIM.DIM_Date VALUES (
        CAST(FORMAT(@d,'yyyyMMdd') AS INT),
        @d,
        DATEPART(WEEKDAY,@d),
        DATENAME(WEEKDAY,@d),
        DAY(@d),
        DATEPART(DAYOFYEAR,@d),
        DATEPART(WEEK,@d),
        MONTH(@d),
        DATENAME(MONTH,@d),
        DATEPART(QUARTER,@d),
        'Q' + CAST(DATEPART(QUARTER,@d) AS NCHAR(1)),
        YEAR(@d),
        CASE WHEN DATEPART(WEEKDAY,@d) IN (1,7) THEN 1 ELSE 0 END,
        CASE WHEN DATEPART(WEEKDAY,@d) IN (1,7) THEN 0 ELSE 1 END
    );
    SET @d = DATEADD(DAY,1,@d);
END
PRINT '✅ DIM_Date populated (2020-2026).';
GO

-- ─────────────────────────────────────────────
-- DIM_Property
-- ─────────────────────────────────────────────
IF OBJECT_ID('DIM.DIM_Property', 'U') IS NOT NULL
    DROP TABLE DIM.DIM_Property;

CREATE TABLE DIM.DIM_Property (
    property_key        INT IDENTITY(1,1) PRIMARY KEY,  -- Surrogate Key
    property_id         INT             NOT NULL,        -- Natural Key (from source)
    property_type       NVARCHAR(50)    NOT NULL,
    city                NVARCHAR(100)   NOT NULL,
    country_code        NCHAR(2)        NOT NULL,
    size_sqm            FLOAT,
    bedrooms            TINYINT,
    bathrooms           TINYINT,
    floor_number        SMALLINT,
    year_built          SMALLINT,
    amenities           NVARCHAR(500),
    listing_date        DATE,
    status              NVARCHAR(30),

    -- SCD Type 1 audit
    dwh_insert_date     DATETIME        DEFAULT GETDATE(),
    dwh_update_date     DATETIME        DEFAULT GETDATE(),
    is_active           BIT             DEFAULT 1
);
PRINT '✅ DIM.DIM_Property created.';
GO

-- ─────────────────────────────────────────────
-- DIM_Agent
-- ─────────────────────────────────────────────
IF OBJECT_ID('DIM.DIM_Agent', 'U') IS NOT NULL
    DROP TABLE DIM.DIM_Agent;

CREATE TABLE DIM.DIM_Agent (
    agent_key           INT IDENTITY(1,1) PRIMARY KEY,
    agent_id            INT             NOT NULL,
    agent_name          NVARCHAR(200)   NOT NULL,
    agency              NVARCHAR(200),
    specialization      NVARCHAR(100),
    country             NCHAR(2),
    phone               NVARCHAR(50),
    email               NVARCHAR(200),
    hire_date           DATE,
    active              BIT             NOT NULL DEFAULT 1,
    experience_years    TINYINT,

    dwh_insert_date     DATETIME        DEFAULT GETDATE(),
    dwh_update_date     DATETIME        DEFAULT GETDATE()
);
PRINT '✅ DIM.DIM_Agent created.';
GO

-- ─────────────────────────────────────────────
-- DIM_Currency
-- ─────────────────────────────────────────────
IF OBJECT_ID('DIM.DIM_Currency', 'U') IS NOT NULL
    DROP TABLE DIM.DIM_Currency;

CREATE TABLE DIM.DIM_Currency (
    currency_key        INT IDENTITY(1,1) PRIMARY KEY,
    currency_code       NCHAR(3)        NOT NULL,
    currency_name       NVARCHAR(100),
    country_name        NVARCHAR(100),
    rate_to_usd         FLOAT           NOT NULL,   -- 1 USD = X
    effective_date      DATE            NOT NULL,

    dwh_insert_date     DATETIME        DEFAULT GETDATE()
);
PRINT '✅ DIM.DIM_Currency created.';

-- Insert static currency names (rates will come from Staging)
-- هيتملى من الـ Staging بعد الـ Transformation
GO

-- ─────────────────────────────────────────────
-- DIM_Location  (Bonus — مشتقة من listings)
-- ─────────────────────────────────────────────
IF OBJECT_ID('DIM.DIM_Location', 'U') IS NOT NULL
    DROP TABLE DIM.DIM_Location;

CREATE TABLE DIM.DIM_Location (
    location_key        INT IDENTITY(1,1) PRIMARY KEY,
    city                NVARCHAR(100)   NOT NULL,
    country_code        NCHAR(2)        NOT NULL,
    country_name        NVARCHAR(100),
    region              NVARCHAR(100),   -- Middle East / Europe / North America

    dwh_insert_date     DATETIME        DEFAULT GETDATE()
);
PRINT '✅ DIM.DIM_Location created.';
GO

-- ════════════════════════════════════════════════════════
--  FACT TABLE  (بنعملها بعد كل الـ Dims عشان الـ FK)
-- ════════════════════════════════════════════════════════

IF OBJECT_ID('FACT.FACT_PropertySales', 'U') IS NOT NULL
    DROP TABLE FACT.FACT_PropertySales;

CREATE TABLE FACT.FACT_PropertySales (
    -- Surrogate PK
    fact_id             BIGINT IDENTITY(1,1) PRIMARY KEY,

    -- ─── Foreign Keys → Dimension Tables ───
    property_key        INT             NOT NULL,
    agent_key           INT             NOT NULL,
    date_key            INT             NOT NULL,    -- transaction date
    listing_date_key    INT             NOT NULL,    -- listing date
    currency_key        INT             NOT NULL,
    location_key        INT             NOT NULL,

    -- ─── Natural Keys (للـ Reference) ───────
    property_id         INT             NOT NULL,
    transaction_id      INT             NOT NULL,
    agent_id            INT             NOT NULL,

    -- ─── Measures (الأرقام اللي بنحللها) ────
    sale_price_local    FLOAT,          -- السعر بالعملة الأصلية
    sale_price_usd      FLOAT,          -- السعر بعد التحويل لـ USD
    commission_pct      FLOAT,
    commission_amount   FLOAT,
    days_on_market      INT,            -- listing_date → transaction_date
    size_sqm            FLOAT,
    price_per_sqm_usd   FLOAT,          -- sale_price_usd / size_sqm

    -- ─── Transaction Info ────────────────────
    transaction_type    NVARCHAR(20),   -- Sale / Rent
    payment_method      NVARCHAR(50),
    buyer_nationality   NVARCHAR(100),
    country_code        NCHAR(2),
    currency_code       NCHAR(3),

    -- ─── Audit ───────────────────────────────
    dwh_insert_date     DATETIME        DEFAULT GETDATE(),

    -- ─── Foreign Key Constraints ─────────────
    CONSTRAINT FK_Fact_Property  FOREIGN KEY (property_key)     REFERENCES DIM.DIM_Property(property_key),
    CONSTRAINT FK_Fact_Agent     FOREIGN KEY (agent_key)        REFERENCES DIM.DIM_Agent(agent_key),
    CONSTRAINT FK_Fact_Date      FOREIGN KEY (date_key)         REFERENCES DIM.DIM_Date(date_key),
    CONSTRAINT FK_Fact_ListDate  FOREIGN KEY (listing_date_key) REFERENCES DIM.DIM_Date(date_key),
    CONSTRAINT FK_Fact_Currency  FOREIGN KEY (currency_key)     REFERENCES DIM.DIM_Currency(currency_key),
    CONSTRAINT FK_Fact_Location  FOREIGN KEY (location_key)     REFERENCES DIM.DIM_Location(location_key)
);
PRINT '✅ FACT.FACT_PropertySales created with all FK constraints.';
GO

-- ─────────────────────────────────────────────
-- Performance Indexes
-- ─────────────────────────────────────────────
CREATE INDEX IX_Fact_DateKey       ON FACT.FACT_PropertySales(date_key);
CREATE INDEX IX_Fact_PropertyKey   ON FACT.FACT_PropertySales(property_key);
CREATE INDEX IX_Fact_AgentKey      ON FACT.FACT_PropertySales(agent_key);
CREATE INDEX IX_Fact_CountryCode   ON FACT.FACT_PropertySales(country_code);
CREATE INDEX IX_Fact_TxnType       ON FACT.FACT_PropertySales(transaction_type);
PRINT '✅ Performance indexes created.';
GO

PRINT '';
PRINT '════════════════════════════════════════════';
PRINT '✅ DWH STAR SCHEMA CREATED SUCCESSFULLY';
PRINT '   4 Dimensions + 1 Fact Table + Indexes';
PRINT '════════════════════════════════════════════';
GO
