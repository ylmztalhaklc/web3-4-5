-- ============================================================
-- FILE    : 02_check_recovery_model.sql
-- PURPOSE : Display the current recovery model of the Northwind
--           database, its file sizes and locations, and any
--           existing backup history stored in msdb.
-- RUN     : Before setting the recovery model (03_set_recovery_model.sql).
-- ============================================================

USE master;
GO

-- 1. Current recovery model and log status
SELECT
    name                 AS [Database],
    recovery_model_desc  AS [Recovery Model],
    log_reuse_wait_desc  AS [Log Reuse Wait],
    state_desc           AS [State]
FROM sys.databases
WHERE name = 'Northwind';
GO

-- 2. Database file details (paths and sizes)
SELECT
    mf.name          AS [Logical Name],
    mf.type_desc     AS [File Type],
    mf.physical_name AS [Physical Path],
    CAST(mf.size * 8.0 / 1024 AS DECIMAL(10,2)) AS [Size MB]
FROM sys.master_files mf
INNER JOIN sys.databases d ON d.database_id = mf.database_id
WHERE d.name = 'Northwind';
GO

-- 3. Existing backup history for Northwind (most recent first)
SELECT TOP 10
    database_name                                                   AS [Database],
    CASE type
        WHEN 'D' THEN 'Full'
        WHEN 'I' THEN 'Differential'
        WHEN 'L' THEN 'Log'
        ELSE type
    END                                                             AS [Backup Type],
    backup_start_date                                               AS [Started],
    backup_finish_date                                              AS [Finished],
    CAST(backup_size / 1024.0 / 1024.0 AS DECIMAL(10,2))           AS [Size MB],
    physical_device_name                                            AS [Backup File]
FROM msdb.dbo.backupset bs
INNER JOIN msdb.dbo.backupmediafamily bmf
    ON bs.media_set_id = bmf.media_set_id
WHERE database_name = 'Northwind'
ORDER BY backup_finish_date DESC;
GO
