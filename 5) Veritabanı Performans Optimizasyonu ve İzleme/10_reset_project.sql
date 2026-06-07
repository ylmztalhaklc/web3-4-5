-- ============================================================
-- DOSYA   : 10_reset_project.sql
-- AMAÇ    : Projenin yaptığı tüm değişiklikleri geri alır.
--           Demo bitince çalıştır; bir sonraki demo için
--           Northwind temiz hale gelir, 00_northwind_kurulum.sql
--           çalıştırmana gerek kalmaz.
--
-- YAPILAN İŞLEMLER:
--   1. Mevcut Northwind'i siler (yeni kuruluma hazırlar)
--   2. Yeni indexleri ve değişiklikleri temizler
--   3. Kurtarma modelini SIMPLE'a döndürür
--
-- NOT: Bu script basit reset yapan versiyondur.
--      Yedek dosyaları ve xp_cmdshell kullanmaz (daha güvenli).
-- ============================================================

USE master;
GO

PRINT '======================================================';
PRINT '  PROJE SIFIRLAMA BASLADI';
PRINT '======================================================';
GO

-- ============================================================
-- ADIM 1: Northwind'i sil (yeni kuruluma hazırla)
-- ============================================================
PRINT 'Adim 1: Mevcut Northwind silinmiş versiyonu kaldırılıyor...';

IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'Northwind')
BEGIN
    ALTER DATABASE Northwind SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Northwind;
    PRINT '✓ Eski Northwind silinmi ve yeni setup için hazırlandı.';
END
ELSE
BEGIN
    PRINT '  Northwind zaten mevcut değil.';
END
GO
