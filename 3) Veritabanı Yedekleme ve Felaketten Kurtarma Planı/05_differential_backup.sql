-- ============================================================
-- FILE    : 05_differential_backup.sql
-- PURPOSE : Take a differential backup of Northwind.
--           Captures all data pages that changed since the
--           last full backup. Faster to create and restore
--           than taking a second full backup.
--
-- OUTPUT  : C:\SQLBackups\Northwind\Northwind_Diff_20260526.bak
--
-- PREREQUISITE: A full backup must already exist.
--   Run 04_full_backup.sql before this script.
-- ============================================================

USE master;
GO

-- 1. Confirm a full backup exists before proceeding
IF NOT EXISTS (
    SELECT 1
    FROM msdb.dbo.backupset
    WHERE database_name = 'Northwind'
      AND type = 'D'
)
BEGIN
    RAISERROR(
        'No full backup found for Northwind. Run 04_full_backup.sql first.',
        16, 1
    );
    RETURN;
END
GO

-- 2. Take the differential backup
BACKUP DATABASE Northwind
TO DISK = 'C:\SQLBackups\Northwind\Northwind_Diff_20260526.bak'
WITH
    DIFFERENTIAL,          -- Only changed pages since the last full backup
    STATS = 10,
    CHECKSUM,
    NAME = 'Northwind - Differential Backup 2026-05-26';
GO

-- 3. Verify the backup file
RESTORE VERIFYONLY
FROM DISK = 'C:\SQLBackups\Northwind\Northwind_Diff_20260526.bak'
WITH CHECKSUM;
GO

-- 4. Confirm in backup history
SELECT TOP 5
    database_name                                         AS [Database],
    CASE type
        WHEN 'D' THEN 'Full'
        WHEN 'I' THEN 'Differential'
        WHEN 'L' THEN 'Log'
        ELSE type
    END                                                   AS [Type],
    backup_finish_date                                    AS [Completed],
    CAST(backup_size / 1024.0 / 1024.0 AS DECIMAL(10,2)) AS [Size MB],
    physical_device_name                                  AS [File]
FROM msdb.dbo.backupset bs
INNER JOIN msdb.dbo.backupmediafamily bmf
    ON bs.media_set_id = bmf.media_set_id
WHERE database_name = 'Northwind'
ORDER BY backup_finish_date DESC;
GO

PRINT '======================================================';
PRINT 'Differential backup completed and verified.';
PRINT 'File: C:\SQLBackups\Northwind\Northwind_Diff_20260526.bak';
PRINT '';
PRINT 'To restore using both backups, run 08_restore_diff.sql';
PRINT '======================================================';
GO
