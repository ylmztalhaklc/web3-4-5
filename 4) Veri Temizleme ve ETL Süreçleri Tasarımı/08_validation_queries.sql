-- ============================================================
-- 08_validation_queries.sql
-- Purpose : Side-by-side before/after comparison queries for
--           classroom demonstration. Run these after the full
--           pipeline has completed (scripts 01–07).
--           Each query pair shows what the data looked like in
--           RAW vs what it looks like in CLEAN.
--
-- Sections:
--   V1 - Row count comparison (RAW vs CLEAN vs Rejected)
--   V2 - Phone format: before vs after
--   V3 - City values: before vs after
--   V4 - Country values: before vs after
--   V5 - NULL counts per column: before vs after
--   V6 - Duplicate check: before vs after
--   V7 - Order date problems: before vs after
--   V8 - Product price issues: before vs after
--   V9 - DQ_IssueLog summary (issues by type)
--   V10 - ETL_Log run history
-- ============================================================

USE Northwind;
GO

-- ============================================================
-- V1: Row count comparison
-- ============================================================
PRINT '=== V1: ROW COUNTS ===';

SELECT
    'RAW_Customers'   AS Source, COUNT(*) AS [RowCount] FROM dbo.RAW_Customers UNION ALL
SELECT 'STG_Customers CLEAN',    COUNT(*) FROM dbo.STG_Customers WHERE STG_Status='CLEAN' UNION ALL
SELECT 'STG_Customers REJECTED', COUNT(*) FROM dbo.STG_Customers WHERE STG_Status='REJECTED' UNION ALL
SELECT 'CLEAN_Customers',        COUNT(*) FROM dbo.CLEAN_Customers

UNION ALL SELECT '---', NULL UNION ALL

SELECT 'RAW_Orders',             COUNT(*) FROM dbo.RAW_Orders UNION ALL
SELECT 'STG_Orders CLEAN',       COUNT(*) FROM dbo.STG_Orders WHERE STG_Status='CLEAN' UNION ALL
SELECT 'STG_Orders REJECTED',    COUNT(*) FROM dbo.STG_Orders WHERE STG_Status='REJECTED' UNION ALL
SELECT 'CLEAN_Orders',           COUNT(*) FROM dbo.CLEAN_Orders

UNION ALL SELECT '---', NULL UNION ALL

SELECT 'RAW_Products',           COUNT(*) FROM dbo.RAW_Products UNION ALL
SELECT 'STG_Products CLEAN',     COUNT(*) FROM dbo.STG_Products WHERE STG_Status='CLEAN' UNION ALL
SELECT 'STG_Products REJECTED',  COUNT(*) FROM dbo.STG_Products WHERE STG_Status='REJECTED' UNION ALL
SELECT 'CLEAN_Products',         COUNT(*) FROM dbo.CLEAN_Products;
GO

-- ============================================================
-- V2: Phone format — before vs after
-- ============================================================
PRINT '=== V2: PHONE FORMATS ===';

PRINT '--- BEFORE (RAW_Customers) ---';
SELECT CustomerID, Phone AS RawPhone
FROM dbo.RAW_Customers
WHERE CustomerID IN ('BONAP','BOTTM','BSBEV','CACTU')
ORDER BY CustomerID;

PRINT '--- AFTER (CLEAN_Customers) ---';
SELECT CustomerID, Phone AS CleanPhone
FROM dbo.CLEAN_Customers
WHERE CustomerID IN ('BONAP','BOTTM','BSBEV','CACTU')
ORDER BY CustomerID;
GO

-- ============================================================
-- V3: City values — before vs after (typos corrected)
-- ============================================================
PRINT '=== V3: CITY VALUES ===';

PRINT '--- BEFORE (RAW_Customers) —';
SELECT CustomerID, City AS RawCity
FROM dbo.RAW_Customers
WHERE CustomerID IN ('ANTON','AROUT','BERGS','BLAUS','BLONP','CENTC','CHOPS')
ORDER BY CustomerID;

PRINT '--- AFTER (CLEAN_Customers) ---';
SELECT CustomerID, City AS CleanCity
FROM dbo.CLEAN_Customers
WHERE CustomerID IN ('ANTON','AROUT','BERGS','BLAUS','BLONP','CENTC','CHOPS')
ORDER BY CustomerID;
GO

-- ============================================================
-- V4: Country normalization — before vs after
-- ============================================================
PRINT '=== V4: COUNTRY VALUES ===';

PRINT '--- BEFORE (RAW_Customers) — distinct country values ---';
SELECT DISTINCT Country AS RawCountry, COUNT(*) AS Cnt
FROM dbo.RAW_Customers
GROUP BY Country
ORDER BY Country;

PRINT '--- AFTER (CLEAN_Customers) — distinct country values ---';
SELECT DISTINCT Country AS CleanCountry, COUNT(*) AS Cnt
FROM dbo.CLEAN_Customers
GROUP BY Country
ORDER BY Country;
GO

-- ============================================================
-- V5: NULL counts per column — before vs after (Customers)
-- ============================================================
PRINT '=== V5: NULL COUNTS IN CUSTOMER DATA ===';

PRINT '--- BEFORE (RAW_Customers) ---';
SELECT
    SUM(CASE WHEN CustomerID  IS NULL THEN 1 ELSE 0 END) AS NULL_CustomerID,
    SUM(CASE WHEN ContactName IS NULL THEN 1 ELSE 0 END) AS NULL_ContactName,
    SUM(CASE WHEN City        IS NULL THEN 1 ELSE 0 END) AS NULL_City,
    SUM(CASE WHEN Country     IS NULL THEN 1 ELSE 0 END) AS NULL_Country,
    SUM(CASE WHEN Phone       IS NULL THEN 1 ELSE 0 END) AS NULL_Phone
FROM dbo.RAW_Customers;

PRINT '--- AFTER (CLEAN_Customers) ---';
SELECT
    SUM(CASE WHEN CustomerID  IS NULL THEN 1 ELSE 0 END) AS NULL_CustomerID,
    SUM(CASE WHEN ContactName IS NULL THEN 1 ELSE 0 END) AS NULL_ContactName,
    SUM(CASE WHEN City        IS NULL THEN 1 ELSE 0 END) AS NULL_City,
    SUM(CASE WHEN Country     IS NULL THEN 1 ELSE 0 END) AS NULL_Country,
    SUM(CASE WHEN Phone       IS NULL THEN 1 ELSE 0 END) AS NULL_Phone
FROM dbo.CLEAN_Customers;
GO

-- ============================================================
-- V6: Duplicate check — before vs after (Customers)
-- ============================================================
PRINT '=== V6: DUPLICATE CUSTOMER ROWS ===';

PRINT '--- BEFORE (RAW_Customers) — rows sharing same CustomerID ---';
SELECT CustomerID, COUNT(*) AS TimesAppearing
FROM dbo.RAW_Customers
WHERE CustomerID IS NOT NULL
GROUP BY CustomerID
HAVING COUNT(*) > 1
ORDER BY CustomerID;

PRINT '--- AFTER (CLEAN_Customers) — should be empty ---';
SELECT CustomerID, COUNT(*) AS TimesAppearing
FROM dbo.CLEAN_Customers
GROUP BY CustomerID
HAVING COUNT(*) > 1
ORDER BY CustomerID;
GO

-- ============================================================
-- V7: Order date problems — before vs after
-- ============================================================
PRINT '=== V7: ORDER DATE PROBLEMS ===';

PRINT '--- BEFORE (RAW_Orders) — NULL or future OrderDate ---';
SELECT OrderID, CustomerID, OrderDate
FROM dbo.RAW_Orders
WHERE OrderDate IS NULL
   OR (ISDATE(OrderDate) = 1 AND CAST(OrderDate AS DATE) > CAST(GETDATE() AS DATE))
ORDER BY OrderID;

PRINT '--- AFTER (CLEAN_Orders) — should be empty ---';
SELECT OrderID, CustomerID, OrderDate
FROM dbo.CLEAN_Orders
WHERE OrderDate IS NULL
   OR OrderDate > CAST(GETDATE() AS DATE);
GO

-- ============================================================
-- V8: Product price issues — before vs after
-- ============================================================
PRINT '=== V8: PRODUCT PRICE ISSUES ===';

PRINT '--- BEFORE (RAW_Products) — zero or negative UnitPrice ---';
SELECT ProductID, ProductName, UnitPrice
FROM dbo.RAW_Products
WHERE ISNUMERIC(UnitPrice) = 1
  AND CAST(UnitPrice AS DECIMAL(10,2)) <= 0
ORDER BY ProductID;

PRINT '--- AFTER (CLEAN_Products) — should be empty ---';
SELECT ProductID, ProductName, UnitPrice
FROM dbo.CLEAN_Products
WHERE UnitPrice <= 0;
GO

-- ============================================================
-- V9: DQ_IssueLog — summary of all issues found
-- ============================================================
PRINT '=== V9: DATA QUALITY ISSUE SUMMARY ===';

SELECT
    SourceTable,
    IssueType,
    COUNT(*)    AS IssueCount,
    MIN(ActionTaken) AS SampleAction
FROM dbo.DQ_IssueLog
GROUP BY SourceTable, IssueType
ORDER BY SourceTable, IssueCount DESC;
GO

-- ============================================================
-- V10: ETL_Log — pipeline run history
-- ============================================================
PRINT '=== V10: ETL RUN HISTORY ===';

SELECT
    LogID,
    RunAt,
    EntityName,
    RowsInRaw,
    RowsLoaded,
    RowsRejected,
    RowsInRaw - RowsLoaded - RowsRejected AS RowsDropped,
    Notes
FROM dbo.ETL_Log
ORDER BY LogID;
GO

PRINT '08_validation_queries.sql completed.';
PRINT 'Use these result sets for your classroom demo and report screenshots.';
GO
