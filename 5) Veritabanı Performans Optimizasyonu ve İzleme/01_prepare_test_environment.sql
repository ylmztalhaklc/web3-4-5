-- ============================================================
-- 01_prepare_test_environment.sql
-- Amaç : Northwind veritabanının varlığını doğrula, mevcut
--        tablo boyutlarını ve index yapısını belgele.
--        
-- ÖNEMİ: Bu script, 00_northwind_kurulum.sql'den 
--         SONRA çalıştırılmalıdır! Northwind veritabanı
--         önceden var olmalıdır.
--
-- Ortam : Microsoft SQL Server 2022 Express + SSMS
-- ============================================================

USE Northwind;
GO

PRINT '========================================================';
PRINT '  NORTHWIND PERFORMANS PROJESİ - ORTAM HAZIRLAMA';
PRINT '  Tarih : ' + CONVERT(varchar, GETDATE(), 120);
PRINT '========================================================';
PRINT '';

-- ── 1. SQL Server Sürüm Bilgisi ─────────────────────────────
PRINT '--- 1. SQL SERVER SÜRÜM BİLGİSİ ---';
SELECT @@VERSION AS [SQL_Server_Surumu];
GO

-- ── 2. Veritabanı Durum ve Uyumluluk Düzeyi ─────────────────
PRINT '';
PRINT '--- 2. VERİTABANI DURUM BİLGİSİ ---';
SELECT
    name                    AS [Veritabani],
    state_desc              AS [Durum],
    compatibility_level     AS [Uyumluluk_Duzeyi],
    recovery_model_desc     AS [Kurtarma_Modeli],
    CAST(
        (SELECT SUM(size * 8.0 / 1024)
         FROM sys.master_files mf
         WHERE mf.database_id = d.database_id)
    AS decimal(10,2))       AS [Toplam_Boyut_MB]
FROM sys.databases d
WHERE name = 'Northwind';
GO

-- ── 3. Tablo Satır Sayıları (Baseline) ──────────────────────
PRINT '';
PRINT '--- 3. TABLO SATIR SAYILARI (BASELINE) ---';
SELECT
    OBJECT_NAME(p.object_id)    AS [Tablo],
    SUM(p.rows)                 AS [Satir_Sayisi]
FROM sys.partitions p
JOIN sys.objects o ON p.object_id = o.object_id
WHERE o.type = 'U'
  AND p.index_id IN (0, 1)   -- heap veya clustered index
  AND o.schema_id = SCHEMA_ID('dbo')
GROUP BY p.object_id
ORDER BY SUM(p.rows) DESC;
GO

-- ── 4. Mevcut Indexlerin Tam Listesi ────────────────────────
PRINT '';
PRINT '--- 4. MEVCUT INDEX YAPISI ---';
SELECT
    o.name                          AS [Tablo],
    i.name                          AS [Index_Adi],
    i.type_desc                     AS [Tip],
    i.is_primary_key                AS [PK_mi],
    i.is_unique                     AS [Unique_mi],
    STRING_AGG(
        CASE ic.is_included_column
            WHEN 0 THEN c.name
            ELSE NULL
        END, ', ')
        WITHIN GROUP (ORDER BY ic.key_ordinal)
                                    AS [Anahtar_Sutunlar],
    STRING_AGG(
        CASE ic.is_included_column
            WHEN 1 THEN c.name
            ELSE NULL
        END, ', ')
        WITHIN GROUP (ORDER BY ic.key_ordinal)
                                    AS [Include_Sutunlar]
FROM sys.indexes i
JOIN sys.objects o ON i.object_id = o.object_id
JOIN sys.index_columns ic ON i.object_id = ic.object_id
                          AND i.index_id = ic.index_id
JOIN sys.columns c ON ic.object_id = c.object_id
                   AND ic.column_id = c.column_id
WHERE o.type = 'U'
  AND o.name IN ('Orders','Order Details','Customers',
                 'Products','Categories','Employees')
  AND i.type > 0   -- heap değil
GROUP BY o.name, i.name, i.type_desc,
         i.is_primary_key, i.is_unique
ORDER BY o.name, i.is_primary_key DESC, i.name;
GO

-- ── 5. Orders Tablosundaki Yinelenen Indexlerin Tespiti ─────
PRINT '';
PRINT '--- 5. YİNELENEN INDEX TESPİTİ (ANTI-PATTERN) ---';
PRINT 'Northwind varsayılan kurulumunda Orders tablosunda';
PRINT 'CustomerID ve EmployeeID sütunları için ikişer';
PRINT 'ayrı index bulunmaktadır. Bu gereksiz yazma maliyeti';
PRINT 'oluşturur ve 06_create_indexes.sql ile temizlenecektir.';
PRINT '';
SELECT
    o.name                  AS [Tablo],
    i.name                  AS [Index_Adi],
    c.name                  AS [Sutun],
    i.type_desc             AS [Tip]
FROM sys.indexes i
JOIN sys.objects o      ON i.object_id = o.object_id
JOIN sys.index_columns ic ON i.object_id = ic.object_id
                          AND i.index_id = ic.index_id
JOIN sys.columns c      ON ic.object_id = c.object_id
                       AND ic.column_id = c.column_id
WHERE o.name = 'Orders'
  AND i.is_primary_key = 0
  AND i.type > 0
ORDER BY c.name, i.name;
GO

-- ── 6. Orders Tablosu Tarih Aralığı ─────────────────────────
PRINT '';
PRINT '--- 6. ORDERS TARIH ARALIGI ---';
SELECT
    MIN(OrderDate) AS [En_Eski_Siparis],
    MAX(OrderDate) AS [En_Yeni_Siparis],
    COUNT(*)       AS [Toplam_Siparis]
FROM Orders;
GO

-- ── 7. Yabancı Anahtar (FK) İlişkileri ──────────────────────
PRINT '';
PRINT '--- 7. İLGİLİ TABLOLAR ARASI FK İLİŞKİLERİ ---';
SELECT
    fk.name             AS [FK_Adi],
    tp.name             AS [Ebeveyn_Tablo],
    cp.name             AS [Ebeveyn_Sutun],
    tr.name             AS [Referans_Tablo],
    cr.name             AS [Referans_Sutun]
FROM sys.foreign_keys fk
JOIN sys.foreign_key_columns fkc ON fk.object_id = fkc.constraint_object_id
JOIN sys.tables tp  ON fkc.parent_object_id = tp.object_id
JOIN sys.columns cp ON fkc.parent_object_id = cp.object_id
                    AND fkc.parent_column_id = cp.column_id
JOIN sys.tables tr  ON fkc.referenced_object_id = tr.object_id
JOIN sys.columns cr ON fkc.referenced_object_id = cr.object_id
                    AND fkc.referenced_column_id = cr.column_id
WHERE tp.name IN ('Orders','Order Details','Products','Customers')
ORDER BY tp.name, fk.name;
GO

PRINT '';
PRINT '========================================================';
PRINT '  ORTAM HAZIRLAMA TAMAMLANDI';
PRINT '  Sonraki adım: 02_create_performance_test_data.sql';
PRINT '========================================================';
