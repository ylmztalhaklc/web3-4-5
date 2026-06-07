-- ============================================================
-- 09_validation_queries.sql
-- PURPOSE: Verify optimizations were successful.
--   1. Check query results are identical before/after
--   2. Verify created indexes exist
--   3. Prove indexes are actually being used
--   4. Check data integrity
--   5. Verify ideal index usage
-- ============================================================

USE Northwind;
GO

PRINT '========================================================';
PRINT '  VALIDATION AND VERIFICATION';
PRINT '  Date: ' + CONVERT(varchar, GETDATE(), 120);
PRINT '========================================================';
PRINT '';

-- ============================================================
-- V1: QUERY RESULT VALIDATION (EXCEPT)
-- ============================================================
-- PURPOSE: Verify Q1 and Q2 optimized versions produce
--          the same results as baseline versions.
-- NOTE: EXCEPT operator finds the difference between two result sets.
--       Empty result = both queries produce identical results.
-- ============================================================
PRINT '--- V1: Query Result Validation (EXCEPT) ---';
PRINT '';
PRINT 'Q1 Test: Baseline vs Optimized (Sargable DateFilter)';

-- Q1 Baseline
SELECT
    o.OrderID, c.CompanyName, o.OrderDate,
    SUM(od.UnitPrice * od.Quantity * (1.0 - od.Discount)) AS OrderTotal
FROM Orders o
JOIN Customers c ON c.CustomerID = o.CustomerID
JOIN [Order Details] od ON od.OrderID = o.OrderID
WHERE YEAR(o.OrderDate) = 1997 AND MONTH(o.OrderDate) BETWEEN 1 AND 6
GROUP BY o.OrderID, c.CompanyName, o.OrderDate

EXCEPT

-- Q1 Optimized
SELECT
    o.OrderID, c.CompanyName, o.OrderDate,
    SUM(od.UnitPrice * od.Quantity * (1.0 - od.Discount)) AS OrderTotal
FROM Orders o
JOIN Customers c ON c.CustomerID = o.CustomerID
JOIN [Order Details] od ON od.OrderID = o.OrderID
WHERE o.OrderDate >= '1997-01-01' AND o.OrderDate < '1997-07-01'
GROUP BY o.OrderID, c.CompanyName, o.OrderDate;

IF @@ROWCOUNT = 0
    PRINT 'OK: Q1 baseline and optimized results match';
ELSE
    PRINT 'ERROR: Q1 results differ!';

PRINT '';
PRINT 'Q2 Test: Baseline vs Optimized (Correlated CTE)';

-- Q2 CTE Definition
;WITH CustomerRevenue AS
(
    SELECT o.CustomerID,
           SUM(od.UnitPrice * od.Quantity * (1.0 - od.Discount)) AS TotalRevenue,
           COUNT(DISTINCT o.OrderID) AS OrderCount
    FROM Orders o
    JOIN [Order Details] od ON od.OrderID = o.OrderID
    GROUP BY o.CustomerID
)
-- Q2 Baseline
SELECT
    c.CompanyName, c.Country,
    (SELECT SUM(od.UnitPrice * od.Quantity * (1.0 - od.Discount))
     FROM Orders o
     JOIN [Order Details] od ON od.OrderID = o.OrderID
     WHERE o.CustomerID = c.CustomerID) AS TotalRevenue,
    (SELECT COUNT(*) FROM Orders o2 WHERE o2.CustomerID = c.CustomerID) AS OrderCount
FROM Customers c
WHERE c.Country IN ('Germany', 'UK', 'France', 'USA')

EXCEPT

-- Q2 Optimized
SELECT c.CompanyName, c.Country, mg.TotalRevenue, mg.OrderCount
FROM Customers c
JOIN CustomerRevenue mg ON mg.CustomerID = c.CustomerID
WHERE c.Country IN ('Germany', 'UK', 'France', 'USA');

IF @@ROWCOUNT = 0
    PRINT 'OK: Q2 baseline and optimized results match';
ELSE
    PRINT 'ERROR: Q2 results differ!';

PRINT '';

-- ============================================================
-- V2: CREATED INDEX VERIFICATION
-- ============================================================
PRINT '--- V2: Created Index Structures ---';
PRINT '';

SELECT
    OBJECT_NAME(i.object_id)            AS [Table],
    i.name                              AS [Index],
    CASE
        WHEN i.name = 'IX_Orders_OrderDate_Covering'
             THEN 'EXPECTED'
        WHEN i.name = 'IX_Orders_CustomerID_OrderDate'
             THEN 'EXPECTED'
        WHEN i.name = 'IX_OrderDetails_ProductID_Covering'
             THEN 'EXPECTED'
        ELSE 'CHECK'
    END                                 AS [Status],
    i.type_desc,
    STRING_AGG(CASE WHEN ic.is_included_column = 0 THEN c.name ELSE NULL END, ', ')
        WITHIN GROUP (ORDER BY ic.key_ordinal)
                                        AS [Key_Columns]
FROM sys.indexes i
LEFT JOIN sys.index_columns ic ON i.object_id = ic.object_id
                               AND i.index_id = ic.index_id
LEFT JOIN sys.columns c ON ic.object_id = c.object_id
                        AND ic.column_id = c.column_id
WHERE (i.name LIKE 'IX_%' OR i.is_primary_key = 1)
  AND OBJECT_NAME(i.object_id) IN ('Orders', 'Order Details')
GROUP BY i.object_id, i.index_id, i.name, i.type_desc
ORDER BY OBJECT_NAME(i.object_id), i.name;

PRINT '';
PRINT 'Expected: See 3 new indexes (IX_*) and PKs above.';
PRINT 'Expected: CustomersOrders and EmployeesOrders were deleted';
PRINT '';

-- ============================================================
-- V3: INDEX USAGE STATUS CHECK
-- ============================================================
-- PURPOSE: Were the newly created indexes actually used?
--          user_seeks and user_scans should be > 0.
-- ============================================================
PRINT '--- V3: Index Usage Statistics ---';
PRINT '';

SELECT
    OBJECT_NAME(i.object_id)            AS [Tablo],
    i.name                              AS [Index],
    ISNULL(u.user_seeks, 0)             AS [Seek_Sayisi],
    ISNULL(u.user_scans, 0)             AS [Scan_Sayisi],
    ISNULL(u.user_lookups, 0)           AS [Lookups],
    ISNULL(u.user_updates, 0)           AS [Updates],
    CASE
        WHEN (ISNULL(u.user_seeks, 0) + ISNULL(u.user_scans, 0)) > 0
             THEN 'ACTIVE'
        WHEN i.name LIKE 'IX_%' THEN 'NEW_NOT_USED'
        ELSE 'DEFAULT'
    END                                 AS [Status]
FROM sys.indexes i
LEFT JOIN sys.dm_db_index_usage_stats u
       ON u.object_id = i.object_id
      AND u.index_id = i.index_id
      AND u.database_id = DB_ID('Northwind')
WHERE OBJECT_NAME(i.object_id) IN ('Orders', 'Order Details')
  AND (i.name LIKE 'IX_%' OR i.is_primary_key = 1)
ORDER BY OBJECT_NAME(i.object_id), i.name;

PRINT '';
PRINT 'NOTE: If new indexes (IX_*) show 0 seek/scan';
PRINT '      07_query_optimization.sql queries may not have run yet';
PRINT '      Run the script again.';
PRINT '';

-- ============================================================
-- V4: DATA INTEGRITY CHECK
-- ============================================================
-- PURPOSE: Verify no data was lost during optimization.
--          FK relationships between Orders, [Order Details],
--          Customers should still be intact.
-- ============================================================
PRINT '--- V4: Data Integrity Check ---';
PRINT '';

PRINT 'Orphan Orders (invalid CustomerID):';
SELECT COUNT(*) AS [Problem_Count]
FROM Orders o
WHERE NOT EXISTS (SELECT 1 FROM Customers c WHERE c.CustomerID = o.CustomerID);

PRINT 'Orphan [Order Details] (invalid OrderID):';
SELECT COUNT(*) AS [Problem_Count]
FROM [Order Details] od
WHERE NOT EXISTS (SELECT 1 FROM Orders o WHERE o.OrderID = od.OrderID);

PRINT 'Orphan [Order Details] (invalid ProductID):';
SELECT COUNT(*) AS [Problem_Count]
FROM [Order Details] od
WHERE NOT EXISTS (SELECT 1 FROM Products p WHERE p.ProductID = od.ProductID);

PRINT '';
PRINT 'All three queries should return 0 (no orphan records)';
PRINT '';

-- ============================================================
-- V5: TABLE SIZE CHECK
-- ============================================================
PRINT '--- V5: Table Size Check ---';
PRINT '';

SELECT
    OBJECT_NAME(p.object_id)            AS [Table],
    SUM(p.rows)                         AS [Rows],
    CAST(
        ISNULL((SELECT SUM(au.total_pages * 8.0 / 1024)
                FROM sys.allocation_units au
                WHERE au.container_id IN (
                    SELECT partition_id
                    FROM sys.partitions
                    WHERE object_id = p.object_id
                )), 0)
    AS decimal(10,2))                   AS [Total_MB]
FROM sys.partitions p
JOIN sys.objects o ON p.object_id = o.object_id
WHERE o.type = 'U'
  AND p.index_id IN (0, 1)
  AND OBJECT_NAME(p.object_id) IN ('Orders', 'Order Details')
GROUP BY p.object_id
ORDER BY SUM(p.rows) DESC;

PRINT '';

-- ============================================================
-- V6: FINAL SUMMARY
-- ============================================================
PRINT '';
PRINT '========================================================';
PRINT '  VALIDATION SUMMARY';
PRINT '========================================================';
PRINT '';
PRINT 'Checklist:';
PRINT '  [x] V1: Query results (EXCEPT returns 0)';
PRINT '  [x] V2: New indexes created (3x IX_* found)';
PRINT '  [x] V3: Index usage (Seeks > 0)';
PRINT '  [x] V4: FK integrity (Orphan records 0)';
PRINT '  [x] V5: Table sizes (Orders ~50,000)';
PRINT '';
PRINT 'If all checks passed, optimization is successful!';
PRINT '';
PRINT '========================================================';
PRINT 'Next: Generate reports (README, REPORT, VIDEO)';
PRINT '========================================================';
