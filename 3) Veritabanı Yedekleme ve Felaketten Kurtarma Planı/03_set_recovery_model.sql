-- ============================================================
-- FILE    : 03_set_recovery_model.sql
-- PURPOSE : Switch the Northwind database from SIMPLE to FULL
--           recovery model.
--
-- WHY FULL?
--   FULL recovery model enables all three backup types:
--     1. Full backup
--     2. Differential backup
--     3. Transaction log backup
--   SIMPLE model auto-truncates the transaction log after each
--   checkpoint, which prevents log backups and point-in-time
--   recovery. FULL is the correct choice for a transactional
--   OLTP database like Northwind.
--
-- IMPORTANT: After switching to FULL, a full backup MUST be
--   taken immediately to start the transaction log backup chain.
--   Run 04_full_backup.sql right after this script.
-- ============================================================

USE master;
GO

-- 1. Show current recovery model before the change
SELECT
    name                AS [Database],
    recovery_model_desc AS [Before Change]
FROM sys.databases
WHERE name = 'Northwind';
GO

-- 2. Switch to FULL recovery model
ALTER DATABASE Northwind SET RECOVERY FULL;
GO

-- 3. Confirm the change was applied
SELECT
    name                AS [Database],
    recovery_model_desc AS [After Change]
FROM sys.databases
WHERE name = 'Northwind';
GO

PRINT '======================================================';
PRINT 'Recovery model has been set to FULL.';
PRINT '';
PRINT 'NEXT STEP: Run 04_full_backup.sql immediately.';
PRINT 'A full backup is required to begin the log chain.';
PRINT 'Without it, transaction log backups cannot be taken.';
PRINT '======================================================';
GO
