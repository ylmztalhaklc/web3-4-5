-- ============================================================
-- 06_create_indexes.sql
-- Amaç : Yeni optimized indexleri oluştur.
--        Yinelenen (duplicate) indexleri kaldır.
--        İstatistikleri güncelle.
--
-- UYARI : Bu script idempotent DEGILDIR.
--         Duplicate drop'lar "IF EXISTS" ile korunur.
--         Index oluşturma "IF NOT EXISTS" ile korunur.
--         Tekrar çalıştırılabilir ama sonuç aynıdır.
-- ============================================================

USE Northwind;
GO

PRINT '========================================================';
PRINT '  INDEX OPTIMIZASYONU BASLANIYOR';
PRINT '  Tarih: ' + CONVERT(varchar, GETDATE(), 120);
PRINT '========================================================';
PRINT '';

-- ============================================================
-- ADIM 1: YINELENEN INDEX'LERİ SİL
-- Orders tablosundaki "CustomersOrders" ve "EmployeesOrders"
-- indexleri, "CustomerID" ve "EmployeeID" indexleriyle
-- tamamen aynı. Yazma maliyeti oluşturmak için silinir.
-- ============================================================
PRINT '--- ADIM 1: Yinelenen Indexleri Kaldir ---';
PRINT '';

IF EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'CustomersOrders'
      AND object_id = OBJECT_ID('Orders')
)
BEGIN
    DROP INDEX CustomersOrders ON Orders;
    PRINT '✓ CustomersOrders index silindi (Orders tablosu)';
END
ELSE
BEGIN
    PRINT '  CustomersOrders zaten mevcut değil.';
END;

IF EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'EmployeesOrders'
      AND object_id = OBJECT_ID('Orders')
)
BEGIN
    DROP INDEX EmployeesOrders ON Orders;
    PRINT '✓ EmployeesOrders index silindi (Orders tablosu)';
END
ELSE
BEGIN
    PRINT '  EmployeesOrders zaten mevcut değil.';
END;

PRINT '';

-- ============================================================
-- ADIM 2: YENİ COVERING INDEX — Orders (OrderDate)
-- ============================================================
-- Amaç: Tarih aralığı sorgularını hızlandır
--       ve key lookup'ları ortadan kaldır.
-- Sargable predicate (WHERE OrderDate >= ... AND OrderDate < ...)
-- bu index'i Index Seek olarak kullanabilir.
-- INCLUDE sütunları, clustered index'e lookup yapmadan
-- sorguyu tamamlamayı sağlar (index-covered query).
-- ============================================================
PRINT '--- ADIM 2: Yeni Covering Index - OrderDate ---';

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'IX_Orders_OrderDate_Covering'
      AND object_id = OBJECT_ID('Orders')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_Orders_OrderDate_Covering
    ON Orders (OrderDate)
    INCLUDE (CustomerID, EmployeeID, Freight, ShipCountry)
    WITH (FILLFACTOR = 90);
    
    PRINT '✓ IX_Orders_OrderDate_Covering olusturuldu';
END
ELSE
BEGIN
    PRINT '  IX_Orders_OrderDate_Covering zaten var.';
END;

PRINT '';

-- ============================================================
-- ADIM 3: YENİ COMPOSITE INDEX — Orders (CustomerID, OrderDate)
-- ============================================================
-- Amaç: Müşteri + tarih bazlı sorgular (rapor) hızlandır.
-- Key sütun sırası önemli: CustomerID önce (WHERE CustomerID = ...
-- filtresi) sonra OrderDate (range scan için).
-- INCLUDE sütunları key lookup'ları ortadan kaldırır.
-- ============================================================
PRINT '--- ADIM 3: Yeni Composite Index - (CustomerID, OrderDate) ---';

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'IX_Orders_CustomerID_OrderDate'
      AND object_id = OBJECT_ID('Orders')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_Orders_CustomerID_OrderDate
    ON Orders (CustomerID, OrderDate)
    INCLUDE (Freight, ShipVia, ShipCountry)
    WITH (FILLFACTOR = 90);
    
    PRINT '✓ IX_Orders_CustomerID_OrderDate olusturuldu';
END
ELSE
BEGIN
    PRINT '  IX_Orders_CustomerID_OrderDate zaten var.';
END;

PRINT '';

-- ============================================================
-- ADIM 4: YENİ INDEX — [Order Details] (ProductID)
-- ============================================================
-- Amaç: Ürün bazlı sorgular (ProductID WHERE filtresi)
--       Index Seek yapmak için.
-- Clustered PK (OrderID, ProductID) → ProductID leading değil.
-- Bu index, ProductID leading key olarak hizmet eder.
-- INCLUDE sütunları, [Order Details] sorguları için
-- clustered index'e lookup yapmayı ortadan kaldırır.
-- ============================================================
PRINT '--- ADIM 4: Yeni Index - [Order Details] (ProductID) ---';

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'IX_OrderDetails_ProductID_Covering'
      AND object_id = OBJECT_ID('[Order Details]')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_OrderDetails_ProductID_Covering
    ON [Order Details] (ProductID)
    INCLUDE (OrderID, UnitPrice, Quantity, Discount)
    WITH (FILLFACTOR = 90);
    
    PRINT '✓ IX_OrderDetails_ProductID_Covering olusturuldu';
END
ELSE
BEGIN
    PRINT '  IX_OrderDetails_ProductID_Covering zaten var.';
END;

PRINT '';

-- ============================================================
-- ADIM 5: İSTATİSTİKLERİ GÜNCELLE
-- ============================================================
-- Optimizer, istatistikleri kullanarak en iyi execution
-- plan'ı seçer. Yeni indexleri ekledikten sonra istatistik
-- güncellemesi gereklidir (özellikle FULLSCAN).
-- ============================================================
PRINT '--- ADIM 5: Istatistikleri Guncelle ---';
PRINT '';
PRINT '  UPDATE STATISTICS Orders ... çalışıyor';

UPDATE STATISTICS Orders WITH FULLSCAN;
PRINT '  ✓ Orders istatistikleri guncellestirildi';

PRINT '  UPDATE STATISTICS [Order Details] ... çalışıyor';
UPDATE STATISTICS [Order Details] WITH FULLSCAN;
PRINT '  ✓ [Order Details] istatistikleri guncellestirildi';

PRINT '';

-- ============================================================
-- ADIM 6: YENİ INDEX YAPISINI DOĞRULA
-- ============================================================
PRINT '--- ADIM 6: Olusturulan Index Yapilari ---';
PRINT '';

SELECT
    OBJECT_NAME(i.object_id)            AS [Tablo],
    i.name                              AS [Index],
    i.type_desc                         AS [Tip],
    STRING_AGG(
        CASE WHEN ic.is_included_column = 0 THEN c.name ELSE NULL END, ', ')
        WITHIN GROUP (ORDER BY ic.key_ordinal)
                                        AS [Key_Sutunlar],
    STRING_AGG(
        CASE WHEN ic.is_included_column = 1 THEN c.name ELSE NULL END, ', ')
        WITHIN GROUP (ORDER BY ic.key_ordinal)
                                        AS [Include_Sutunlar]
FROM sys.indexes i
LEFT JOIN sys.index_columns ic ON i.object_id = ic.object_id
                               AND i.index_id = ic.index_id
LEFT JOIN sys.columns c ON ic.object_id = c.object_id
                        AND ic.column_id = c.column_id
WHERE OBJECT_NAME(i.object_id) IN ('Orders', 'Order Details')
  AND i.name LIKE 'IX_%'
  AND i.type > 0
GROUP BY i.object_id, i.index_id, i.name, i.type_desc
ORDER BY OBJECT_NAME(i.object_id), i.name;
GO

PRINT '';
PRINT '========================================================';
PRINT '  INDEX OPTIMIZASYONU TAMAMLANDI';
PRINT '========================================================';
PRINT '';
PRINT 'Sonraki adım: 07_query_optimization.sql';
PRINT '  (Sorguları yeniden yazarak performansı artıracağız)';
PRINT '';
