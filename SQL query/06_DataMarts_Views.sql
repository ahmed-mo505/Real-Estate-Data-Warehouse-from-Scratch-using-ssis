-- ============================================================
--  SCRIPT 06 — Data Marts (Views)
--  كل View بتمثل Data Mart منفصل
-- ============================================================

USE RealEstate_DWH;
GO

-- ═══════════════════════════════════════════════════════════
-- VIEW 1: vw_SalesByLocation
-- متوسط الأسعار وعدد الصفقات لكل مدينة
-- ═══════════════════════════════════════════════════════════
CREATE OR ALTER VIEW dbo.vw_SalesByLocation AS
SELECT
    l.city,
    l.country_name,
    l.region,
    f.transaction_type,
    COUNT(*)                        AS total_transactions,
    AVG(f.sale_price_local)         AS avg_price,
    MIN(f.sale_price_local)         AS min_price,
    MAX(f.sale_price_local)         AS max_price,
    AVG(f.size_sqm)                 AS avg_size_sqm,
    AVG(f.price_per_sqm_usd)        AS avg_price_per_sqm,
    AVG(f.days_on_market)           AS avg_days_on_market
FROM FACT.FACT_PropertySales f
JOIN DIM.DIM_Location l ON f.location_key = l.location_key
GROUP BY
    l.city,
    l.country_name,
    l.region,
    f.transaction_type;
GO

-- ═══════════════════════════════════════════════════════════
-- VIEW 2: vw_SalesByPropertyType
-- مقارنة أنواع العقارات
-- ═══════════════════════════════════════════════════════════
CREATE OR ALTER VIEW dbo.vw_SalesByPropertyType AS
SELECT
    p.property_type,
    l.country_name,
    f.transaction_type,
    COUNT(*)                        AS total_transactions,
    AVG(f.sale_price_local)         AS avg_price,
    AVG(f.size_sqm)                 AS avg_size_sqm,
    AVG(f.price_per_sqm_usd)        AS avg_price_per_sqm,
    AVG(CAST(p.bedrooms AS FLOAT))  AS avg_bedrooms,
    AVG(f.days_on_market)           AS avg_days_on_market,
    SUM(f.commission_amount)        AS total_commission
FROM FACT.FACT_PropertySales f
JOIN DIM.DIM_Property p ON f.property_key = p.property_key
JOIN DIM.DIM_Location l ON f.location_key = l.location_key
GROUP BY
    p.property_type,
    l.country_name,
    f.transaction_type;
GO

-- ═══════════════════════════════════════════════════════════
-- VIEW 3: vw_AgentPerformance
-- أداء الوكلاء العقاريين
-- ═══════════════════════════════════════════════════════════
CREATE OR ALTER VIEW dbo.vw_AgentPerformance AS
SELECT
    a.agent_id,
    a.agent_name,
    a.agency,
    a.specialization,
    a.country,
    a.experience_years,
    COUNT(*)                        AS total_deals,
    SUM(f.sale_price_local)         AS total_sales_value,
    AVG(f.sale_price_local)         AS avg_deal_value,
    SUM(f.commission_amount)        AS total_commission_earned,
    AVG(f.commission_pct)           AS avg_commission_pct,
    AVG(f.days_on_market)           AS avg_days_on_market,
    COUNT(CASE WHEN f.transaction_type = 'Sale' THEN 1 END) AS total_sales,
    COUNT(CASE WHEN f.transaction_type = 'Rent' THEN 1 END) AS total_rentals
FROM FACT.FACT_PropertySales f
JOIN DIM.DIM_Agent a ON f.agent_key = a.agent_key
GROUP BY
    a.agent_id,
    a.agent_name,
    a.agency,
    a.specialization,
    a.country,
    a.experience_years;
GO

-- ═══════════════════════════════════════════════════════════
-- VIEW 4: vw_MonthlyTrends
-- اتجاه الأسعار والصفقات بالوقت
-- ═══════════════════════════════════════════════════════════
CREATE OR ALTER VIEW dbo.vw_MonthlyTrends AS
SELECT
    d.year_number,
    d.month_number,
    d.month_name,
    d.quarter_name,
    l.country_name,
    l.region,
    f.transaction_type,
    COUNT(*)                        AS total_transactions,
    AVG(f.sale_price_local)         AS avg_price,
    SUM(f.sale_price_local)         AS total_sales_value,
    SUM(f.commission_amount)        AS total_commission,
    AVG(f.days_on_market)           AS avg_days_on_market,
    AVG(f.size_sqm)                 AS avg_size_sqm
FROM FACT.FACT_PropertySales f
JOIN DIM.DIM_Date     d ON f.date_key     = d.date_key
JOIN DIM.DIM_Location l ON f.location_key = l.location_key
GROUP BY
    d.year_number,
    d.month_number,
    d.month_name,
    d.quarter_name,
    l.country_name,
    l.region,
    f.transaction_type;
GO

-- ═══════════════════════════════════════════════════════════
-- VIEW 5: vw_BuyerAnalysis
-- تحليل جنسيات المشترين وطرق الدفع
-- ═══════════════════════════════════════════════════════════
CREATE OR ALTER VIEW dbo.vw_BuyerAnalysis AS
SELECT
    f.buyer_nationality,
    f.payment_method,
    l.country_name,
    l.region,
    p.property_type,
    f.transaction_type,
    COUNT(*)                        AS total_transactions,
    AVG(f.sale_price_local)         AS avg_price,
    SUM(f.sale_price_local)         AS total_value,
    AVG(f.days_on_market)           AS avg_days_on_market
FROM FACT.FACT_PropertySales f
JOIN DIM.DIM_Location l ON f.location_key = l.location_key
JOIN DIM.DIM_Property p ON f.property_key = p.property_key
WHERE f.buyer_nationality IS NOT NULL
  AND f.buyer_nationality != ''
GROUP BY
    f.buyer_nationality,
    f.payment_method,
    l.country_name,
    l.region,
    p.property_type,
    f.transaction_type;
GO

-- ═══════════════════════════════════════════════════════════
-- VIEW 6: vw_FullDashboard
-- View شاملة للـ Power BI Dashboard
-- ═══════════════════════════════════════════════════════════
CREATE OR ALTER VIEW dbo.vw_FullDashboard AS
SELECT
    -- Transaction Info
    f.fact_id,
    f.transaction_id,
    f.transaction_type,
    f.payment_method,
    f.buyer_nationality,

    -- Property Info
    p.property_id,
    p.property_type,
    p.bedrooms,
    p.bathrooms,
    p.size_sqm,
    p.year_built,
    p.status,

    -- Location Info
    l.city,
    l.country_code,
    l.country_name,
    l.region,

    -- Agent Info
    a.agent_name,
    a.agency,
    a.specialization,

    -- Date Info
    d.full_date          AS transaction_date,
    d.year_number,
    d.month_name,
    d.quarter_name,
    d.is_weekend,

    -- Measures
    f.sale_price_local,
    f.commission_pct,
    f.commission_amount,
    f.days_on_market,
    f.price_per_sqm_usd,
    f.currency_code

FROM FACT.FACT_PropertySales f
JOIN DIM.DIM_Property p ON f.property_key = p.property_key
JOIN DIM.DIM_Agent    a ON f.agent_key    = a.agent_key
JOIN DIM.DIM_Date     d ON f.date_key     = d.date_key
JOIN DIM.DIM_Location l ON f.location_key = l.location_key;
GO

PRINT '✅ ALL DATA MART VIEWS CREATED SUCCESSFULLY';
PRINT '';
PRINT 'Views Created:';
PRINT '  1. vw_SalesByLocation';
PRINT '  2. vw_SalesByPropertyType';
PRINT '  3. vw_AgentPerformance';
PRINT '  4. vw_MonthlyTrends';
PRINT '  5. vw_BuyerAnalysis';
PRINT '  6. vw_FullDashboard';
GO
