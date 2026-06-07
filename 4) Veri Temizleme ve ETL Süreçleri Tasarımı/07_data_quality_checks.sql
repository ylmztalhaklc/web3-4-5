-- ============================================================
-- 07_data_quality_checks.sql
-- Purpose : Post-load assertions against the CLEAN tables.
--           Each check uses a SELECT that should return 0 rows
--           if the pipeline worked correctly.
--           A non-zero result set means a check FAILED.
--
-- How to read results:
--   - If a result set is EMPTY  → check PASSED  ✓
--   - If a result set has rows  → check FAILED  ✗
--     Investigate the rows and re-run the pipeline if needed.
--
-- Checks performed:
--   QC-01  No NULL CustomerID in CLEAN_Customers
--   QC-02  No duplicate CustomerID in CLEAN_Customers
--   QC-03  No NULL ContactName in CLEAN_Customers
--   QC-04  No NULL City in CLEAN_Customers
--   QC-05  No NULL Country in CLEAN_Customers
--   QC-06  All phones match NNN-NNN-NNNN or are 'N/A'
--   QC-07  No NULL OrderDate in CLEAN_Orders
--   QC-08  No future OrderDate in CLEAN_Orders
--   QC-09  No ShippedDate before OrderDate in CLEAN_Orders
--   QC-10  No orphan CustomerID in CLEAN_Orders
--   QC-11  No negative Freight in CLEAN_Orders
--   QC-12  No NULL ProductName in CLEAN_Products
--   QC-13  No negative UnitPrice in CLEAN_Products
--   QC-14  No negative UnitsInStock in CLEAN_Products
--   QC-15  DQ_IssueLog has at least 20 logged issues (pipeline ran)
--   QC-16  ETL_Log has 3 rows (all 3 entities loaded)
-- ============================================================

USE Northwind;
GO

PRINT '========== DATA QUALITY CHECK RESULTS ==========';
PRINT 'Empty result set = PASSED. Rows returned = FAILED.';
PRINT '================================================';
GO

-- ----------------------------------------------------------
-- QC-01: No NULL CustomerID in CLEAN_Customers
-- ----------------------------------------------------------
PRINT 'QC-01: NULL CustomerID in CLEAN_Customers (expect 0 rows)';
SELECT CustomerID, CompanyName
FROM dbo.CLEAN_Customers
WHERE CustomerID IS NULL;
GO

-- ----------------------------------------------------------
-- QC-02: No duplicate CustomerID in CLEAN_Customers
-- ----------------------------------------------------------
PRINT 'QC-02: Duplicate CustomerID in CLEAN_Customers (expect 0 rows)';
SELECT CustomerID, COUNT(*) AS DuplicateCount
FROM dbo.CLEAN_Customers
GROUP BY CustomerID
HAVING COUNT(*) > 1;
GO

-- ----------------------------------------------------------
-- QC-03: No NULL ContactName in CLEAN_Customers
-- ----------------------------------------------------------
PRINT 'QC-03: NULL ContactName in CLEAN_Customers (expect 0 rows)';
SELECT CustomerID, CompanyName
FROM dbo.CLEAN_Customers
WHERE ContactName IS NULL;
GO

-- ----------------------------------------------------------
-- QC-04: No NULL City in CLEAN_Customers
-- ----------------------------------------------------------
PRINT 'QC-04: NULL City in CLEAN_Customers (expect 0 rows)';
SELECT CustomerID, CompanyName
FROM dbo.CLEAN_Customers
WHERE City IS NULL;
GO

-- ----------------------------------------------------------
-- QC-05: No NULL Country in CLEAN_Customers
-- ----------------------------------------------------------
PRINT 'QC-05: NULL Country in CLEAN_Customers (expect 0 rows)';
SELECT CustomerID, CompanyName
FROM dbo.CLEAN_Customers
WHERE Country IS NULL;
GO

-- ----------------------------------------------------------
-- QC-06: Phone format — must be NNN-NNN-NNNN or 'N/A'
-- ----------------------------------------------------------
PRINT 'QC-06: Non-standard Phone in CLEAN_Customers (expect 0 rows)';
SELECT CustomerID, Phone
FROM dbo.CLEAN_Customers
WHERE Phone <> 'N/A'
  AND Phone NOT LIKE '[0-9][0-9][0-9]-[0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]';
GO

-- ----------------------------------------------------------
-- QC-07: No NULL OrderDate in CLEAN_Orders
-- ----------------------------------------------------------
PRINT 'QC-07: NULL OrderDate in CLEAN_Orders (expect 0 rows)';
SELECT OrderID, CustomerID
FROM dbo.CLEAN_Orders
WHERE OrderDate IS NULL;
GO

-- ----------------------------------------------------------
-- QC-08: No future OrderDate in CLEAN_Orders
-- ----------------------------------------------------------
PRINT 'QC-08: Future OrderDate in CLEAN_Orders (expect 0 rows)';
SELECT OrderID, CustomerID, OrderDate
FROM dbo.CLEAN_Orders
WHERE OrderDate > CAST(GETDATE() AS DATE);
GO

-- ----------------------------------------------------------
-- QC-09: No ShippedDate before OrderDate in CLEAN_Orders
-- ----------------------------------------------------------
PRINT 'QC-09: ShippedDate before OrderDate in CLEAN_Orders (expect 0 rows)';
SELECT OrderID, CustomerID, OrderDate, ShippedDate
FROM dbo.CLEAN_Orders
WHERE ShippedDate IS NOT NULL
  AND ShippedDate < OrderDate;
GO

-- ----------------------------------------------------------
-- QC-10: No orphan CustomerID in CLEAN_Orders
--        Every order's CustomerID must exist in CLEAN_Customers
-- ----------------------------------------------------------
PRINT 'QC-10: Orphan CustomerID in CLEAN_Orders (expect 0 rows)';
SELECT o.OrderID, o.CustomerID
FROM dbo.CLEAN_Orders o
LEFT JOIN dbo.CLEAN_Customers c ON o.CustomerID = c.CustomerID
WHERE c.CustomerID IS NULL;
GO

-- ----------------------------------------------------------
-- QC-11: No negative Freight in CLEAN_Orders
-- ----------------------------------------------------------
PRINT 'QC-11: Negative Freight in CLEAN_Orders (expect 0 rows)';
SELECT OrderID, CustomerID, Freight
FROM dbo.CLEAN_Orders
WHERE Freight < 0;
GO

-- ----------------------------------------------------------
-- QC-12: No NULL ProductName in CLEAN_Products
-- ----------------------------------------------------------
PRINT 'QC-12: NULL ProductName in CLEAN_Products (expect 0 rows)';
SELECT ProductID
FROM dbo.CLEAN_Products
WHERE ProductName IS NULL;
GO

-- ----------------------------------------------------------
-- QC-13: No negative UnitPrice in CLEAN_Products
-- ----------------------------------------------------------
PRINT 'QC-13: Negative UnitPrice in CLEAN_Products (expect 0 rows)';
SELECT ProductID, ProductName, UnitPrice
FROM dbo.CLEAN_Products
WHERE UnitPrice < 0;
GO

-- ----------------------------------------------------------
-- QC-14: No negative UnitsInStock in CLEAN_Products
-- ----------------------------------------------------------
PRINT 'QC-14: Negative UnitsInStock in CLEAN_Products (expect 0 rows)';
SELECT ProductID, ProductName, UnitsInStock
FROM dbo.CLEAN_Products
WHERE UnitsInStock < 0;
GO

-- ----------------------------------------------------------
-- QC-15: DQ_IssueLog should have been populated
-- ----------------------------------------------------------
PRINT 'QC-15: DQ_IssueLog issue count (expect >= 20)';
SELECT COUNT(*) AS TotalIssuesLogged FROM dbo.DQ_IssueLog;
GO

-- ----------------------------------------------------------
-- QC-16: ETL_Log must have exactly 3 rows (Customers/Orders/Products)
-- ----------------------------------------------------------
PRINT 'QC-16: ETL_Log entity count (expect 3)';
SELECT COUNT(DISTINCT EntityName) AS EntityCount FROM dbo.ETL_Log;
GO

-- ----------------------------------------------------------
-- Summary scorecard
-- ----------------------------------------------------------
PRINT '';
PRINT '========== SCORECARD ==========';
SELECT
    'QC-01 NULL CustomerID'   AS CheckName,
    CASE WHEN (SELECT COUNT(*) FROM dbo.CLEAN_Customers WHERE CustomerID IS NULL) = 0
         THEN 'PASSED' ELSE 'FAILED' END AS Result
UNION ALL SELECT 'QC-02 Duplicate CustomerID',
    CASE WHEN (SELECT COUNT(*) FROM (SELECT CustomerID FROM dbo.CLEAN_Customers GROUP BY CustomerID HAVING COUNT(*)>1) x) = 0
         THEN 'PASSED' ELSE 'FAILED' END
UNION ALL SELECT 'QC-03 NULL ContactName',
    CASE WHEN (SELECT COUNT(*) FROM dbo.CLEAN_Customers WHERE ContactName IS NULL) = 0
         THEN 'PASSED' ELSE 'FAILED' END
UNION ALL SELECT 'QC-04 NULL City',
    CASE WHEN (SELECT COUNT(*) FROM dbo.CLEAN_Customers WHERE City IS NULL) = 0
         THEN 'PASSED' ELSE 'FAILED' END
UNION ALL SELECT 'QC-05 NULL Country',
    CASE WHEN (SELECT COUNT(*) FROM dbo.CLEAN_Customers WHERE Country IS NULL) = 0
         THEN 'PASSED' ELSE 'FAILED' END
UNION ALL SELECT 'QC-06 Phone Format',
    CASE WHEN (SELECT COUNT(*) FROM dbo.CLEAN_Customers
               WHERE Phone <> 'N/A'
                 AND Phone NOT LIKE '[0-9][0-9][0-9]-[0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]') = 0
         THEN 'PASSED' ELSE 'FAILED' END
UNION ALL SELECT 'QC-07 NULL OrderDate',
    CASE WHEN (SELECT COUNT(*) FROM dbo.CLEAN_Orders WHERE OrderDate IS NULL) = 0
         THEN 'PASSED' ELSE 'FAILED' END
UNION ALL SELECT 'QC-08 Future OrderDate',
    CASE WHEN (SELECT COUNT(*) FROM dbo.CLEAN_Orders WHERE OrderDate > CAST(GETDATE() AS DATE)) = 0
         THEN 'PASSED' ELSE 'FAILED' END
UNION ALL SELECT 'QC-09 ShippedDate < OrderDate',
    CASE WHEN (SELECT COUNT(*) FROM dbo.CLEAN_Orders WHERE ShippedDate IS NOT NULL AND ShippedDate < OrderDate) = 0
         THEN 'PASSED' ELSE 'FAILED' END
UNION ALL SELECT 'QC-10 Orphan CustomerID Orders',
    CASE WHEN (SELECT COUNT(*) FROM dbo.CLEAN_Orders o LEFT JOIN dbo.CLEAN_Customers c ON o.CustomerID=c.CustomerID WHERE c.CustomerID IS NULL) = 0
         THEN 'PASSED' ELSE 'FAILED' END
UNION ALL SELECT 'QC-11 Negative Freight',
    CASE WHEN (SELECT COUNT(*) FROM dbo.CLEAN_Orders WHERE Freight < 0) = 0
         THEN 'PASSED' ELSE 'FAILED' END
UNION ALL SELECT 'QC-12 NULL ProductName',
    CASE WHEN (SELECT COUNT(*) FROM dbo.CLEAN_Products WHERE ProductName IS NULL) = 0
         THEN 'PASSED' ELSE 'FAILED' END
UNION ALL SELECT 'QC-13 Negative UnitPrice',
    CASE WHEN (SELECT COUNT(*) FROM dbo.CLEAN_Products WHERE UnitPrice < 0) = 0
         THEN 'PASSED' ELSE 'FAILED' END
UNION ALL SELECT 'QC-14 Negative UnitsInStock',
    CASE WHEN (SELECT COUNT(*) FROM dbo.CLEAN_Products WHERE UnitsInStock < 0) = 0
         THEN 'PASSED' ELSE 'FAILED' END
UNION ALL SELECT 'QC-15 DQ_IssueLog populated',
    CASE WHEN (SELECT COUNT(*) FROM dbo.DQ_IssueLog) >= 20
         THEN 'PASSED' ELSE 'FAILED' END
UNION ALL SELECT 'QC-16 ETL_Log 3 entities',
    CASE WHEN (SELECT COUNT(DISTINCT EntityName) FROM dbo.ETL_Log) = 3
         THEN 'PASSED' ELSE 'FAILED' END;
GO

PRINT '07_data_quality_checks.sql completed.';
PRINT 'All PASSED = pipeline is working correctly.';
GO
