-- ============================================================
-- DOSYA   : 10_reset_project.sql
-- AMAÇ    : Projenin yaptığı tüm değişiklikleri geri alır.
--           Demo bitince çalıştır; bir sonraki demo için
--           Northwind temiz hale gelir, 00_install_northwind.sql
--           çalıştırmana gerek kalmaz.
--
-- YAPILAN İŞLEMLER:
--   1. Northwind'i tam yedekten geri yükler (temiz veri)
--   2. Kurtarma modelini SIMPLE'a döndürür (orijinal hal)
--   3. Tüm yedek dosyalarını diskten siler (.bak, .trn)
--   4. msdb yedekleme geçmişini temizler
--   5. xp_cmdshell'i tekrar kapatır
--
-- ÇALIŞTIR: 07_restore_full.sql veya 08_restore_diff.sql
--           çalıştırdıktan ve demo bitince bu betiği çalıştır.
-- ============================================================

USE master;
GO

PRINT '======================================================';
PRINT '  PROJE SIFIRLAMA BASLADI';
PRINT '======================================================';
GO

-- ============================================================
-- ADIM 1: xp_cmdshell'i aç
-- ============================================================
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sp_configure 'xp_cmdshell',           1; RECONFIGURE;
GO

-- ============================================================
-- ADIM 2: Northwind'i tam yedekten geri yükle (temiz veri)
--         Yedek dosyası yoksa bu adım atlanır, veri olduğu
--         gibi kalır — sonraki adımlar yine de çalışır.
-- ============================================================
IF EXISTS (
    SELECT 1 FROM sys.databases WHERE name = 'Northwind'
)
AND EXISTS (
    SELECT 1 FROM msdb.dbo.backupset
    WHERE database_name = 'Northwind' AND type = 'D'
)
BEGIN
    PRINT 'Adim 2: Northwind tam yedekten geri yukleniyor...';

    -- Yedek dosyasının adını msdb'den al
    DECLARE @backupFile NVARCHAR(512);
    SELECT TOP 1 @backupFile = bmf.physical_device_name
    FROM msdb.dbo.backupset bs
    JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id
    WHERE bs.database_name = 'Northwind' AND bs.type = 'D'
    ORDER BY bs.backup_finish_date DESC;

    DECLARE @restoreSql NVARCHAR(1000) =
        'ALTER DATABASE Northwind SET SINGLE_USER WITH ROLLBACK IMMEDIATE; '
      + 'RESTORE DATABASE Northwind FROM DISK = ''' + @backupFile + ''' '
      + 'WITH REPLACE, RECOVERY, STATS = 10; '
      + 'ALTER DATABASE Northwind SET MULTI_USER;';

    EXEC sp_executesql @restoreSql;

    PRINT 'Adim 2: Geri yukleme tamamlandi.';
END
ELSE
BEGIN
    PRINT 'Adim 2: Yedek dosyasi bulunamadi — veri oldugu gibi korunuyor.';
END
GO

-- ============================================================
-- ADIM 3: Kurtarma modelini SIMPLE'a döndür
--         (projeye başlamadan önceki orijinal hal)
-- ============================================================
PRINT 'Adim 3: Kurtarma modeli SIMPLE olarak ayarlaniyor...';
ALTER DATABASE Northwind SET RECOVERY SIMPLE;
GO

SELECT name AS [Veritabani], recovery_model_desc AS [Kurtarma Modeli]
FROM sys.databases
WHERE name = 'Northwind';
GO

-- ============================================================
-- ADIM 4: Yedek dosyalarını diskten sil
-- ============================================================
PRINT 'Adim 4: Yedek dosyalari siliniyor...';

EXEC xp_cmdshell 'del /Q "C:\SQLBackups\Northwind\*.bak" 2>nul && echo .bak dosyalari silindi || echo .bak dosyasi bulunamadi';
EXEC xp_cmdshell 'del /Q "C:\SQLBackups\Northwind\*.trn" 2>nul && echo .trn dosyalari silindi || echo .trn dosyasi bulunamadi';
EXEC xp_cmdshell 'del /Q "C:\SQLBackups\instnwnd.sql"   2>nul && echo instnwnd.sql silindi   || echo instnwnd.sql bulunamadi';
GO

-- Klasörü göster (boş olmalı)
EXEC xp_cmdshell 'dir "C:\SQLBackups\Northwind\" /B 2>nul || echo Klasor bos.';
GO

-- ============================================================
-- ADIM 5: msdb yedekleme geçmişini temizle
-- ============================================================
PRINT 'Adim 5: msdb yedekleme gecmisi temizleniyor...';

EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = 'Northwind';
GO

-- Geçmiş temizlendi mi kontrol et (0 satır dönmeli)
SELECT COUNT(*) AS [Kalan Gecmis Kaydi]
FROM msdb.dbo.backupset
WHERE database_name = 'Northwind';
GO

-- ============================================================
-- ADIM 6: xp_cmdshell'i kapat (güvenlik)
-- ============================================================
EXEC sp_configure 'xp_cmdshell',           0; RECONFIGURE;
EXEC sp_configure 'show advanced options',  0; RECONFIGURE;
GO

-- ============================================================
-- FINAL: Northwind doğrulama
-- ============================================================
USE Northwind;
GO

PRINT '';
PRINT '======================================================';
PRINT '  SIFIRLAMA TAMAMLANDI — NORTHWIND DURUMU';
PRINT '======================================================';

SELECT
    'Customers'     AS [Tablo], COUNT(*) AS [Satir],
    CASE WHEN COUNT(*) = 91   THEN 'TEMIZ' ELSE 'KONTROL ET' END AS [Durum]
FROM Customers
UNION ALL
SELECT 'Orders',        COUNT(*),
    CASE WHEN COUNT(*) = 830  THEN 'TEMIZ' ELSE 'KONTROL ET' END
FROM Orders
UNION ALL
SELECT 'Products',      COUNT(*),
    CASE WHEN COUNT(*) = 77   THEN 'TEMIZ' ELSE 'KONTROL ET' END
FROM Products
UNION ALL
SELECT 'Order Details', COUNT(*),
    CASE WHEN COUNT(*) = 2155 THEN 'TEMIZ' ELSE 'KONTROL ET' END
FROM [Order Details];
GO

PRINT '';
PRINT 'Bir sonraki demo icin:';
PRINT '  1. 03_set_recovery_model.sql';
PRINT '  2. 04_full_backup.sql';
PRINT '  3. 05_differential_backup.sql';
PRINT '  4. 05b_log_backup.sql';
PRINT '  5. 06_simulate_disaster.sql';
PRINT '  6. 07 veya 08 restore';
PRINT '  7. 09_validation_queries.sql';
GO
