-- ============================================================
-- FILE    : 09_validation_queries.sql
-- PURPOSE : Verify that the Northwind database has been fully
--           and correctly restored. Each check produces a
--           PASS or FAIL result.
--
-- RUN AFTER: 07_restore_full.sql or 08_restore_diff.sql
-- EXPECTED : All checks should return PASS.
-- ============================================================

USE Northwind;
GO

PRINT '======================================================';
PRINT '  NORTHWIND DATABASE RESTORATION VALIDATION REPORT   ';
PRINT '======================================================';
GO

-- ============================================================
-- CHECK 1: Row count validation for all key tables
-- Expected values for the unmodified Northwind database:
--   Customers = 91 | Orders = 830 | Products = 77 | OD = 2155
-- ============================================================

PRINT '--- CHECK 1: Table Row Counts ---';

SELECT
    'Customers'    AS [Table],
    COUNT(*)       AS [Actual],
    91             AS [Expected],
    CASE WHEN COUNT(*) = 91   THEN 'PASS' ELSE 'FAIL' END AS [Status]
FROM Customers
UNION ALL
SELECT
    'Orders',      COUNT(*), 830,
    CASE WHEN COUNT(*) = 830  THEN 'PASS' ELSE 'FAIL' END
FROM Orders
UNION ALL
SELECT
    'Products',    COUNT(*), 77,
    CASE WHEN COUNT(*) = 77   THEN 'PASS' ELSE 'FAIL' END
FROM Products
UNION ALL
SELECT
    'Order Details', COUNT(*), 2155,
    CASE WHEN COUNT(*) = 2155 THEN 'PASS' ELSE 'FAIL' END
FROM [Order Details];
GO

-- ============================================================
-- CHECK 2: Scenario A — Deleted customers must be restored
-- Expected: ALFKI, ANATR, ANTON, AROUT, BERGS all present
-- ============================================================

PRINT '--- CHECK 2: Scenario A - Deleted Customers Restored ---';

-- Show restored customers
SELECT CustomerID, CompanyName, ContactName, 'PASS' AS [Status]
FROM Customers
WHERE CustomerID IN ('ALFKI','ANATR','ANTON','AROUT','BERGS')

UNION ALL

-- Show FAIL row for any customer that is still missing
SELECT
    v.CustomerID,
    'MISSING - RECORD NOT FOUND',
    '',
    'FAIL'
FROM (VALUES ('ALFKI'),('ANATR'),('ANTON'),('AROUT'),('BERGS')) AS v(CustomerID)
WHERE NOT EXISTS (
    SELECT 1 FROM Customers c WHERE c.CustomerID = v.CustomerID
);
GO

-- ============================================================
-- CHECK 3: Scenario B — Beverage prices must be non-zero
-- Expected: All Products WHERE CategoryID = 1 have UnitPrice > 0
-- ============================================================

PRINT '--- CHECK 3: Scenario B - Beverage Prices Restored ---';

SELECT
    ProductID,
    ProductName,
    UnitPrice,
    CASE
        WHEN UnitPrice > 0 THEN 'PASS'
        ELSE               'FAIL - Price is still 0.00'
    END AS [Status]
FROM Products
WHERE CategoryID = 1
ORDER BY ProductID;
GO

-- ============================================================
-- CHECK 4: Scenario C — VINET orders must be restored
-- Expected: CustomerID = VINET has exactly 5 orders
-- ============================================================

PRINT '--- CHECK 4: Scenario C - VINET Orders Restored ---';

SELECT
    COUNT(*)                                              AS [Actual Count],
    5                                                     AS [Expected Count],
    CASE WHEN COUNT(*) = 5 THEN 'PASS' ELSE 'FAIL' END   AS [Status]
FROM Orders
WHERE CustomerID = 'VINET';
GO

-- Detailed view of the restored VINET orders
SELECT OrderID, OrderDate, ShipName, ShipCity
FROM Orders
WHERE CustomerID = 'VINET'
ORDER BY OrderDate;
GO

-- ============================================================
-- CHECK 5: Backup history — confirm backups are registered
-- ============================================================

PRINT '--- CHECK 5: Backup History in msdb ---';

SELECT TOP 10
    database_name                                         AS [Database],
    CASE type
        WHEN 'D' THEN 'Full'
        WHEN 'I' THEN 'Differential'
        WHEN 'L' THEN 'Log'
        ELSE type
    END                                                   AS [Backup Type],
    backup_finish_date                                    AS [Completed],
    CAST(backup_size / 1024.0 / 1024.0 AS DECIMAL(10,2)) AS [Size MB],
    physical_device_name                                  AS [Backup File]
FROM msdb.dbo.backupset bs
INNER JOIN msdb.dbo.backupmediafamily bmf
    ON bs.media_set_id = bmf.media_set_id
WHERE database_name = 'Northwind'
ORDER BY backup_finish_date DESC;
GO

PRINT '======================================================';
PRINT 'Validation complete.';
PRINT 'All checks returning PASS = successful restoration.';
PRINT '======================================================';
GO
