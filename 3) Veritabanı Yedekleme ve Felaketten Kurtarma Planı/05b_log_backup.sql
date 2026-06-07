-- ============================================================
-- FILE    : 05b_log_backup.sql
-- PURPOSE : Take a transaction log backup of Northwind.
--           Captures all committed transactions since the last
--           log backup. Enables point-in-time recovery.
--
-- OUTPUT  : C:\SQLBackups\Northwind\Northwind_Log_20260526.trn
--
-- PREREQUISITES:
--   1. FULL recovery model must be active (03_set_recovery_model.sql)
--   2. A full backup must exist to start the log chain (04_full_backup.sql)
-- ============================================================

USE master;
GO

-- 1. Confirm FULL recovery model is active
IF (
    SELECT recovery_model_desc
    FROM sys.databases
    WHERE name = 'Northwind'
) <> 'FULL'
BEGIN
    RAISERROR(
        'Northwind is not in FULL recovery model. Run 03_set_recovery_model.sql first.',
        16, 1
    );
    RETURN;
END
GO

-- 2. Take the transaction log backup
BACKUP LOG Northwind
TO DISK = 'C:\SQLBackups\Northwind\Northwind_Log_20260526.trn'
WITH
    STATS = 10,
    CHECKSUM,
    NAME = 'Northwind - Transaction Log Backup 2026-05-26';
GO

-- 3. Verify the log backup file
RESTORE VERIFYONLY
FROM DISK = 'C:\SQLBackups\Northwind\Northwind_Log_20260526.trn'
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
PRINT 'Transaction log backup completed and verified.';
PRINT 'File: C:\SQLBackups\Northwind\Northwind_Log_20260526.trn';
PRINT '';
PRINT 'With Full + Differential + Log backups, all three';
PRINT 'backup types are now demonstrated.';
PRINT 'Point-in-time recovery is now possible.';
PRINT '======================================================';
GO
