-- ============================================================
-- DOSYA   : 10_reset_project.sql
-- AMAÇ    : ETL pipeline'ının oluşturduğu tüm nesneleri
--           temizler; Northwind temel tabloları dokunulmadan
--           kalır. Demo bitince çalıştır; bir sonraki demo
--           için 01_northwind_kurulum.sql'i tekrar çalıştırmana
--           gerek kalmaz.
--
-- YAPILAN İŞLEMLER:
--   1. CLEAN tabloları sil  (CLEAN_Products, CLEAN_Orders, CLEAN_Customers)
--   2. STG  tabloları sil   (STG_Products,   STG_Orders,   STG_Customers)
--   3. RAW  tabloları sil   (RAW_Products,   RAW_Orders,   RAW_Customers)
--   4. Denetim tablolarını sil (ETL_Log, DQ_IssueLog)
--   5. fn_ProperCase skalâr fonksiyonunu sil
--   6. Categories'teki CategoryID=0 sentinel satırını temizle
--   7. Northwind temel tablolarını doğrula
--
-- ÇALIŞTIR: Tüm pipeline adımları tamamlandıktan sonra.
-- ============================================================

USE Northwind;
GO

PRINT '======================================================';
PRINT '  PROJE SIFIRLAMA BASLADI';
PRINT '======================================================';
GO

-- ============================================================
-- ADIM 1: CLEAN tabloları sil
-- ============================================================
PRINT 'Adim 1: CLEAN tablolari siliniyor...';

IF OBJECT_ID('dbo.CLEAN_Products',  'U') IS NOT NULL DROP TABLE dbo.CLEAN_Products;
IF OBJECT_ID('dbo.CLEAN_Orders',    'U') IS NOT NULL DROP TABLE dbo.CLEAN_Orders;
IF OBJECT_ID('dbo.CLEAN_Customers', 'U') IS NOT NULL DROP TABLE dbo.CLEAN_Customers;

PRINT 'Adim 1: CLEAN tablolari silindi.';
GO

-- ============================================================
-- ADIM 2: STG tabloları sil
-- ============================================================
PRINT 'Adim 2: STG tablolari siliniyor...';

IF OBJECT_ID('dbo.STG_Products',  'U') IS NOT NULL DROP TABLE dbo.STG_Products;
IF OBJECT_ID('dbo.STG_Orders',    'U') IS NOT NULL DROP TABLE dbo.STG_Orders;
IF OBJECT_ID('dbo.STG_Customers', 'U') IS NOT NULL DROP TABLE dbo.STG_Customers;

PRINT 'Adim 2: STG tablolari silindi.';
GO

-- ============================================================
-- ADIM 3: RAW tabloları sil
-- ============================================================
PRINT 'Adim 3: RAW tablolari siliniyor...';

IF OBJECT_ID('dbo.RAW_Products',  'U') IS NOT NULL DROP TABLE dbo.RAW_Products;
IF OBJECT_ID('dbo.RAW_Orders',    'U') IS NOT NULL DROP TABLE dbo.RAW_Orders;
IF OBJECT_ID('dbo.RAW_Customers', 'U') IS NOT NULL DROP TABLE dbo.RAW_Customers;

PRINT 'Adim 3: RAW tablolari silindi.';
GO

-- ============================================================
-- ADIM 4: Denetim tablolarını sil (ETL_Log, DQ_IssueLog)
-- ============================================================
PRINT 'Adim 4: Denetim tablolari siliniyor...';

IF OBJECT_ID('dbo.DQ_IssueLog', 'U') IS NOT NULL DROP TABLE dbo.DQ_IssueLog;
IF OBJECT_ID('dbo.ETL_Log',     'U') IS NOT NULL DROP TABLE dbo.ETL_Log;

PRINT 'Adim 4: Denetim tablolari silindi.';
GO

-- ============================================================
-- ADIM 5: fn_ProperCase fonksiyonunu sil
-- ============================================================
PRINT 'Adim 5: fn_ProperCase fonksiyonu siliniyor...';

IF OBJECT_ID('dbo.fn_ProperCase', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_ProperCase;

PRINT 'Adim 5: fn_ProperCase silindi.';
GO

-- ============================================================
-- ADIM 6: Categories'teki CategoryID=0 sentinel satırını kaldır
--         (01_create_raw_tables.sql tarafından eklenmişti)
-- ============================================================
PRINT 'Adim 6: Categories sentinel satiri (CategoryID=0) siliniyor...';

IF EXISTS (SELECT 1 FROM dbo.Categories WHERE CategoryID = 0)
BEGIN
    SET IDENTITY_INSERT dbo.Categories ON;
    DELETE FROM dbo.Categories WHERE CategoryID = 0;
    SET IDENTITY_INSERT dbo.Categories OFF;
    PRINT 'Adim 6: CategoryID=0 satiri silindi.';
END
ELSE
    PRINT 'Adim 6: CategoryID=0 satiri zaten mevcut degil, atlandi.';
GO

-- ============================================================
-- ADIM 7: Northwind temel tabloları doğrula
--         (pipeline dokunsaydı yanlış sayı döner)
-- ============================================================
PRINT '';
PRINT '======================================================';
PRINT '  SIFIRLAMA TAMAMLANDI — NORTHWIND TEMEL TABLO DURUMU';
PRINT '======================================================';

SELECT
    'Customers'     AS [Tablo], COUNT(*) AS [Satir],
    CASE WHEN COUNT(*) = 91   THEN 'TEMIZ' ELSE 'KONTROL ET' END AS [Durum]
FROM dbo.Customers
UNION ALL
SELECT 'Orders',        COUNT(*),
    CASE WHEN COUNT(*) = 830  THEN 'TEMIZ' ELSE 'KONTROL ET' END
FROM dbo.Orders
UNION ALL
SELECT 'Products',      COUNT(*),
    CASE WHEN COUNT(*) = 77   THEN 'TEMIZ' ELSE 'KONTROL ET' END
FROM dbo.Products
UNION ALL
SELECT 'Order Details', COUNT(*),
    CASE WHEN COUNT(*) = 2155 THEN 'TEMIZ' ELSE 'KONTROL ET' END
FROM dbo.[Order Details]
UNION ALL
SELECT 'Categories (sentinel yok)', COUNT(*),
    CASE WHEN COUNT(*) = 8    THEN 'TEMIZ' ELSE 'KONTROL ET' END
FROM dbo.Categories;
GO

-- Pipeline tablolarının gerçekten silindiğini teyit et
PRINT '';
PRINT '-- Pipeline nesneleri (asagidaki liste BOS olmali) --';
SELECT name AS [Kalan_Nesne], type_desc
FROM sys.objects
WHERE name IN (
    'RAW_Customers','RAW_Orders','RAW_Products',
    'STG_Customers','STG_Orders','STG_Products',
    'CLEAN_Customers','CLEAN_Orders','CLEAN_Products',
    'ETL_Log','DQ_IssueLog','fn_ProperCase'
)
ORDER BY name;
GO

PRINT '';
PRINT 'Bir sonraki demo icin calistirma sirasi:';
PRINT '  1. 01_create_raw_tables.sql';
PRINT '  2. 02_insert_dirty_sample_data.sql';
PRINT '  3. 03_create_staging_tables.sql';
PRINT '  4. 04_data_cleaning.sql';
PRINT '  5. 05_data_transformation.sql';
PRINT '  6. 06_load_final_tables.sql';
PRINT '  7. 07_data_quality_checks.sql';
PRINT '  8. 08_validation_queries.sql';
GO
