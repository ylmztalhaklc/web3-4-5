-- ============================================================
-- FILE    : 04_full_backup.sql
-- PURPOSE : Take a full backup of the Northwind database.
--           This is the base backup that all differential and
--           transaction log backups depend on.
--
-- OUTPUT  : C:\SQLBackups\Northwind\Northwind_Full_20260526.bak
--
-- PATH NOTE: If you need to use a different folder, change the
--   DISK path in the BACKUP and RESTORE VERIFYONLY commands below.
--   Make sure the folder exists before running this script.
-- ============================================================

USE master;
GO

-- 1. Yedek klasörünü oluştur (zaten varsa hata vermez)
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 1;          RECONFIGURE;
GO
EXEC xp_cmdshell 'if not exist "C:\SQLBackups\Northwind" mkdir "C:\SQLBackups\Northwind"', no_output;
EXEC sp_configure 'xp_cmdshell', 0;          RECONFIGURE;
EXEC sp_configure 'show advanced options', 0; RECONFIGURE;
GO

-- 2. Take the full backup
BACKUP DATABASE Northwind
TO DISK = 'C:\SQLBackups\Northwind\Northwind_Full_20260526.bak'
WITH
    FORMAT,                -- Create a new media set (overwrites if exists)
    STATS = 10,            -- Print a progress message every 10%
    CHECKSUM,              -- Compute checksum for integrity verification
    NAME = 'Northwind - Full Backup 2026-05-26';
GO

-- 3. Verify that the backup file is readable and internally consistent
RESTORE VERIFYONLY
FROM DISK = 'C:\SQLBackups\Northwind\Northwind_Full_20260526.bak'
WITH CHECKSUM;
GO

-- 4. Confirm the backup appears in msdb history
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
PRINT 'Full backup completed and verified.';
PRINT 'File: C:\SQLBackups\Northwind\Northwind_Full_20260526.bak';
PRINT '';
PRINT 'NEXT STEPS:';
PRINT '  - Run 05_differential_backup.sql after making changes';
PRINT '  - Run 05b_log_backup.sql for a transaction log backup';
PRINT '======================================================';
GO
