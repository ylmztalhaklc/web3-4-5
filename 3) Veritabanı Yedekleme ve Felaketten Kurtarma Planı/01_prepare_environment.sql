-- ============================================================
-- FILE    : 01_prepare_environment.sql
-- PURPOSE : Verify that SQL Server Express is running correctly,
--           confirm Northwind is installed, and display baseline
--           row counts for all tables used in this project.
-- RUN     : Execute in SSMS before any other script.
-- ============================================================

-- 1. Confirm SQL Server edition and version
SELECT @@VERSION        AS [SQL Server Version];
SELECT @@SERVERNAME     AS [Server Name];
SELECT SERVERPROPERTY('Edition')       AS [Edition],
       SERVERPROPERTY('ProductVersion') AS [Version],
       SERVERPROPERTY('ProductLevel')   AS [Service Pack];
GO

-- 2. Confirm Northwind database exists and is online
SELECT
    name             AS [Database],
    state_desc       AS [State],
    recovery_model_desc AS [Recovery Model],
    compatibility_level AS [Compat Level]
FROM sys.databases
WHERE name = 'Northwind';
GO

-- 3. List all base tables in Northwind
USE Northwind;
GO

SELECT TABLE_NAME AS [Table Name], TABLE_TYPE AS [Type]
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME;
GO

-- 4. Baseline row counts for the key tables used in disaster scenarios
SELECT 'Customers'    AS [Table], COUNT(*) AS [Row Count] FROM Customers
UNION ALL
SELECT 'Orders',                  COUNT(*) FROM Orders
UNION ALL
SELECT 'Products',                COUNT(*) FROM Products
UNION ALL
SELECT 'Order Details',           COUNT(*) FROM [Order Details];
GO

-- 5. Database file info (data file + log file paths and sizes)
EXEC sp_helpdb 'Northwind';
GO

-- ============================================================
-- MANUAL STEP REQUIRED BEFORE RUNNING BACKUP SCRIPTS:
--   Create the backup folder: C:\SQLBackups\Northwind\
--   Option 1 — Windows Explorer: navigate to C:\ and create the folders.
--   Option 2 — PowerShell:
--     New-Item -ItemType Directory -Path "C:\SQLBackups\Northwind" -Force
--
-- If you prefer a different path, update the DISK path in:
--   04_full_backup.sql
--   05_differential_backup.sql
--   05b_log_backup.sql
--   07_restore_full.sql
--   08_restore_diff.sql
-- ============================================================
