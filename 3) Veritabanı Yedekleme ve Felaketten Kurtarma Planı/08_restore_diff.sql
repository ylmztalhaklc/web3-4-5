-- ============================================================
-- FILE    : 08_restore_diff.sql
-- PURPOSE : Restore Northwind using the full backup followed by
--           the differential backup. Recovers the database to
--           the more recent differential backup point.
--
-- USE WHEN:
--   - Scenario B: Beverage prices were zeroed out after the
--     full backup but a differential backup captured the correct
--     prices.
--
-- HOW IT WORKS:
--   Step 1: Restore the full backup WITH NORECOVERY.
--           The database enters "Restoring" state — this is
--           normal. Do NOT try to access it at this point.
--   Step 2: Apply the differential backup WITH RECOVERY.
--           This brings the database online at the differential
--           backup point.
--
-- PREREQUISITES:
--   C:\SQLBackups\Northwind\Northwind_Full_20260526.bak
--   C:\SQLBackups\Northwind\Northwind_Diff_20260526.bak
-- ============================================================

USE master;
GO

PRINT '======================================================';
PRINT 'Starting restore: FULL + DIFFERENTIAL...';
PRINT '======================================================';

-- 1. Switch to single-user mode to drop all active connections.
ALTER DATABASE Northwind
    SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
GO

PRINT 'Step 1 of 2: Restoring full backup (NORECOVERY)...';
PRINT 'Database will appear as "(Restoring)" — this is expected.';

-- 2. Restore the full backup WITHOUT recovery.
--    NORECOVERY leaves the database in a restoring state so
--    the differential backup can be applied next.
RESTORE DATABASE Northwind
FROM DISK = 'C:\SQLBackups\Northwind\Northwind_Full_20260526.bak'
WITH
    REPLACE,
    NORECOVERY,
    STATS = 10;
GO

PRINT 'Step 2 of 2: Applying differential backup (RECOVERY)...';

-- 3. Apply the differential backup and bring the database online.
--    RECOVERY finalises the restore and makes the database accessible.
RESTORE DATABASE Northwind
FROM DISK = 'C:\SQLBackups\Northwind\Northwind_Diff_20260526.bak'
WITH
    RECOVERY,
    STATS = 10;
GO

-- 4. Return the database to normal multi-user access.
ALTER DATABASE Northwind
    SET MULTI_USER;
GO

-- 5. Quick row count validation
USE Northwind;
GO

PRINT '--- POST-RESTORE ROW COUNTS ---';
SELECT
    'Customers'   AS [Table], COUNT(*) AS [Row Count] FROM Customers
UNION ALL
SELECT 'Orders',                COUNT(*) FROM Orders
UNION ALL
SELECT 'Products',              COUNT(*) FROM Products
UNION ALL
SELECT 'Order Details',         COUNT(*) FROM [Order Details];
GO

PRINT '======================================================';
PRINT 'Full + Differential restore completed.';
PRINT 'Run 09_validation_queries.sql for complete verification.';
PRINT '======================================================';
GO
