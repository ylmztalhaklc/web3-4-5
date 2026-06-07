-- ============================================================
-- 05_index_analysis.sql
-- Amaç : Mevcut index yapısını detaylı analiz et.
--        Yinelenen (duplicate) indexleri tespit et.
--        Fragmantasyonu kontrol et.
--        Index tasarım kararlarını belge et.
-- ============================================================

USE Northwind;
GO

PRINT '========================================================';
PRINT '  INDEX ANALİZİ — MEVCUT DURUM';
PRINT '  Tarih: ' + CONVERT(varchar, GETDATE(), 120);
PRINT '========================================================';
PRINT '';

-- ============================================================
-- A1: TÜM INDEX'LERİN DETAYLI YAPISI
-- ============================================================
PRINT '--- A1: NORTHWIND — TÜM INDEXLER (DETAY) ---';
PRINT '';

SELECT
    OBJECT_NAME(i.object_id)            AS [Tablo],
    i.name                              AS [Index_Adi],
    i.type_desc                         AS [Tur],
    i.is_primary_key                    AS [PK_mi],
    i.is_unique                         AS [Unique_mi],
    STRING_AGG(
        CASE WHEN ic.is_included_column = 0
             THEN c.name
             ELSE NULL
        END, ',') 
        WITHIN GROUP (ORDER BY ic.key_ordinal)
                                        AS [Anahtar_Sutunlar],
    STRING_AGG(
        CASE WHEN ic.is_included_column = 1
             THEN c.name
             ELSE NULL
        END, ',') 
        WITHIN GROUP (ORDER BY ic.key_ordinal)
                                        AS [Include_Sutunlar],
    (SELECT SUM(page_count)
     FROM sys.dm_db_index_physical_stats(DB_ID('Northwind'),
                                         i.object_id,
                                         i.index_id, NULL, 'LIMITED'))
                                        AS [Toplam_Sayfa],
    (SELECT ROUND(AVG(avg_fragmentation_in_percent), 2)
     FROM sys.dm_db_index_physical_stats(DB_ID('Northwind'),
                                         i.object_id,
                                         i.index_id, NULL, 'LIMITED'))
                                        AS [Fragman_Yuzde]
FROM   sys.indexes i
JOIN   sys.index_columns ic ON i.object_id     = ic.object_id
                            AND i.index_id     = ic.index_id
JOIN   sys.columns c        ON ic.object_id    = c.object_id
                            AND ic.column_id   = c.column_id
JOIN   sys.objects o        ON i.object_id     = o.object_id
WHERE  o.type = 'U'
  AND  OBJECT_NAME(i.object_id) IN
       ('Orders', 'Order Details', 'Customers', 'Products')
  AND  i.type > 0
GROUP BY i.object_id, i.index_id, i.name, i.type_desc,
         i.is_primary_key, i.is_unique
ORDER BY OBJECT_NAME(i.object_id), i.is_primary_key DESC, i.index_id;
GO

-- ============================================================
-- A2: YİNELENEN (DUPLICATE) INDEX TESPİTİ
-- ============================================================
-- NORTHWIND ANTİ-PATTERN: Orders tablosunda
--   • CustomerID (index) vs CustomersOrders (index) → DUPLICATE!
--   • EmployeeID (index) vs EmployeesOrders (index) → DUPLICATE!
-- Her çift, yazma maliyeti artırır (update/insert sırasında
-- tüm indexler güncellenmeli) ancak sorgulara fayda sağlamaz.
-- ============================================================
PRINT '';
PRINT '--- A2: YİNELENEN INDEX TESPİTİ (ANTI-PATTERN) ---';
PRINT '';

;WITH IndexColumns AS
(
    SELECT
        i.object_id,
        i.index_id,
        i.name,
        STRING_AGG(c.name, '|') 
            WITHIN GROUP (ORDER BY ic.key_ordinal)
            AS KeyColumns,
        STRING_AGG(
            CASE WHEN ic.is_included_column = 1 THEN c.name ELSE NULL END, '|') 
            WITHIN GROUP (ORDER BY ic.key_ordinal)
            AS IncludedColumns
    FROM sys.indexes i
    JOIN sys.index_columns ic ON i.object_id = ic.object_id
                              AND i.index_id = ic.index_id
    JOIN sys.columns c ON ic.object_id = c.object_id
                      AND ic.column_id = c.column_id
    WHERE OBJECT_NAME(i.object_id) = 'Orders'
      AND i.type > 0
      AND i.is_primary_key = 0
    GROUP BY i.object_id, i.index_id, i.name
)
SELECT
    a.name AS [Index1],
    b.name AS [Index2],
    a.KeyColumns,
    a.IncludedColumns
FROM IndexColumns a
JOIN IndexColumns b ON a.object_id = b.object_id
                   AND a.index_id < b.index_id
                   AND a.KeyColumns = b.KeyColumns
WHERE a.KeyColumns IS NOT NULL;

PRINT '';
PRINT '→ Sonuç: Eğer boş ise yinelenen index yoktur.';
PRINT '  Eğer satır var ise bu indexler hemen silinmeli!';
GO

-- ============================================================
-- A3: [ORDER DETAILS] TABLO YAPISI VE INDEX SORUNU
-- ============================================================
-- [Order Details] Clustered PK: (OrderID, ProductID)
-- Problem: ProductID'ye göre arama yapıldığında,
--          bu sütun PK'nin ikinci pozisyonunda olmasına rağmen
--          leading key olmadığı için tarama gerekli.
--          Çözüm: ProductID'yi leading key yapan index oluştur.
-- ============================================================
PRINT '';
PRINT '--- A3: [ORDER DETAILS] — CLUSTERED PK YAPISININ SORUNU ---';
PRINT '';

SELECT
    'Clustered PK (OrderID, ProductID)' AS [Yapı],
    'OrderID ↓' AS [Soldan1_KEY],
    'ProductID ↓' AS [Soldan2_KEY],
    'PROBLEM: ProductID tabanlı sorgular full scan gerektirir.'
                                        AS [Konu]
UNION ALL
SELECT
    'Çözüm: Non-clustered index gerekli',
    'ProductID ↓ (Leading Key)',
    'Include(OrderID, UnitPrice, Quantity, Discount)',
    'Bu index ile ProductID arama = Index Seek'
;

PRINT '';
PRINT 'Mevcut index kontrol:';
SELECT
    i.name,
    i.type_desc,
    STRING_AGG(c.name, ', ') 
        WITHIN GROUP (ORDER BY ic.key_ordinal)
    AS Sutunlar
FROM sys.indexes i
JOIN sys.index_columns ic ON i.object_id = ic.object_id
                          AND i.index_id = ic.index_id
JOIN sys.columns c ON ic.object_id = c.object_id
                  AND ic.column_id = c.column_id
WHERE OBJECT_NAME(i.object_id) = 'Order Details'
GROUP BY i.object_id, i.index_id, i.name, i.type_desc
ORDER BY i.index_id;
GO

-- ============================================================
-- A4: İSTATİSTİK GÜNCELLIK KONTROLÜ
-- ============================================================
PRINT '';
PRINT '--- A4: İSTATİSTİK GÜNCELLIK DURUMU ---';
PRINT '';

SELECT
    OBJECT_NAME(s.object_id)            AS [Tablo],
    s.name                              AS [Istatistik],
    STATS_DATE(s.object_id, s.stats_id) AS [Son_Guncelleme],
    DATEDIFF(HOUR,
        STATS_DATE(s.object_id, s.stats_id),
        GETDATE())                      AS [Saat_Oncesi],
    s.auto_created                      AS [Otomatik],
    s.user_created                      AS [Kullanici]
FROM sys.stats s
JOIN sys.objects o ON s.object_id = o.object_id
WHERE o.type = 'U'
  AND OBJECT_NAME(s.object_id) IN ('Orders', 'Order Details')
ORDER BY STATS_DATE(s.object_id, s.stats_id) DESC;
GO

-- ============================================================
-- A5: ÖZET VE ÖNERİLER
-- ============================================================
PRINT '';
PRINT '========================================================';
PRINT '  INDEX ANALİZİ - ÖZET';
PRINT '========================================================';
PRINT '';
PRINT 'Bulunacak Problemler:';
PRINT '  1. Orders.CustomerID vs Orders.CustomersOrders (dup?)';
PRINT '  2. Orders.EmployeeID vs Orders.EmployeesOrders (dup?)';
PRINT '  3. [Order Details] ProductID index eksik';
PRINT '';
PRINT 'Çözüm Stratejisi:';
PRINT '  → A2 sonuçlarına bakın: duplicate varsa silinecek';
PRINT '  → A3 sorununa karşı ProductID index oluşturulacak';
PRINT '  → Yeni covering indexler OrderDate, CustomerID için';
PRINT '';
PRINT 'Sonraki adım: 06_create_indexes.sql';
PRINT '========================================================';
