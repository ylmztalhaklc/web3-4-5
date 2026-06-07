-- ============================================================
-- FILE    : 07_restore_full.sql
-- PURPOSE : Restore the Northwind database from the full backup
--           only. Recovers the database to the exact state it
--           was in at the time the full backup was taken.
--
-- USE WHEN:
--   - Scenario A: 5 customers were deleted
--   - Scenario C: VINET orders were deleted
--   - Any data loss that occurred after the full backup
--
-- EFFECT  : All changes made AFTER the full backup are discarded.
--           The database is returned to the full backup point.
--
-- PREREQUISITE:
--   C:\SQLBackups\Northwind\Northwind_Full_20260526.bak must exist.
-- ============================================================

USE master;
GO

PRINT '======================================================';
PRINT 'Starting restore from FULL BACKUP...';
PRINT 'File: C:\SQLBackups\Northwind\Northwind_Full_20260526.bak';
PRINT '======================================================';

-- 1. Switch to single-user mode to drop all active connections.
--    ROLLBACK IMMEDIATE terminates any running transactions.
ALTER DATABASE Northwind
    SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
GO

-- 2. Restore from the full backup and bring the database online.
--    REPLACE  : overwrite the existing database files.
--    RECOVERY : apply undo/redo and bring the database online after restore.
RESTORE DATABASE Northwind
FROM DISK = 'C:\SQLBackups\Northwind\Northwind_Full_20260526.bak'
WITH
    REPLACE,
    RECOVERY,
    STATS = 10;
GO

-- 3. Return the database to normal multi-user access.
ALTER DATABASE Northwind
    SET MULTI_USER;
GO

-- 4. Quick row count validation
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
PRINT 'Full backup restore completed.';
PRINT 'Run 09_validation_queries.sql for complete verification.';
PRINT '======================================================';
GO
