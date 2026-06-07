-- ============================================================
-- 03_baseline_queries.sql
-- Amaç : Optimizasyon öncesi 4 yavaş sorguyu ölçümle çalıştır.
--        SET STATISTICS TIME/IO çıktısını "Messages" sekmesinde
--        kaydedin — bu değerler raporun "öncesi" verisidir.
--
-- SSMS İPUCU: Her sorguyu çalıştırmadan önce Ctrl+M ile
--             "Actual Execution Plan" aktif edin.
-- ============================================================

USE Northwind;
GO

PRINT '========================================================';
PRINT '  BASELINE ÖLÇÜMLER — OPTİMİZASYON ÖNCESİ';
PRINT '  Tarih: ' + CONVERT(varchar, GETDATE(), 120);
PRINT '========================================================';
PRINT 'SSMS → Messages sekmesindeki Logical Reads ve';
PRINT 'Elapsed Time değerlerini not alın!';
PRINT '';

-- ============================================================
-- BASELINE Q1: Non-Sargable Tarih Filtresi
-- ============================================================
-- NEDEN YAVAŞ: YEAR() ve MONTH() fonksiyonları sütunu sarmalıyor.
-- SQL Server, OrderDate indexini bir RANGE SEEK için kullanamaz;
-- tüm tabloya INDEX SCAN yapmak zorunda kalır.
-- 50.000+ satırın tamamı okunur, yalnızca küçük bir kısmı döner.
-- ============================================================
PRINT '--- BASELINE Q1: Non-Sargable Tarih Filtresi ---';
PRINT 'Beklenen: Index Scan, yüksek Logical Reads';
PRINT '';

SET STATISTICS TIME ON;
SET STATISTICS IO ON;

SELECT
    o.OrderID,
    c.CompanyName,
    c.Country                           AS MusteriUlke,
    o.OrderDate,
    SUM(od.UnitPrice * od.Quantity * (1.0 - od.Discount))
                                        AS SiparisTutari
FROM   Orders o
JOIN   Customers c    ON c.CustomerID = o.CustomerID
JOIN   [Order Details] od ON od.OrderID = o.OrderID
WHERE  YEAR(o.OrderDate)  = 1997          -- ← FONKSİYON: index kullanamaz
  AND  MONTH(o.OrderDate) BETWEEN 1 AND 6  -- ← FONKSİYON: index kullanamaz
GROUP BY o.OrderID, c.CompanyName, c.Country, o.OrderDate
ORDER BY o.OrderDate;

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

-- ============================================================
-- BASELINE Q2: İlişkili Alt Sorgu (Correlated Subquery)
-- ============================================================
-- NEDEN YAVAŞ: SELECT listesindeki her alt sorgu, Customers'daki
-- her satır için ayrı ayrı çalışır. 91 müşteri → 91 ayrı
-- aggregation geçişi + 91 ayrı COUNT(*) geçişi = 182 ilave tarama.
-- Veri genişledikçe maliyet doğrusal artar.
-- ============================================================
PRINT '';
PRINT '--- BASELINE Q2: İlişkili Alt Sorgu Raporu ---';
PRINT 'Beklenen: Nested Loops, her müşteri için ayrı tarama';
PRINT '';

SET STATISTICS TIME ON;
SET STATISTICS IO ON;

SELECT
    c.CompanyName,
    c.Country,
    (
        SELECT SUM(od.UnitPrice * od.Quantity * (1.0 - od.Discount))
        FROM   Orders o
        JOIN   [Order Details] od ON od.OrderID = o.OrderID
        WHERE  o.CustomerID = c.CustomerID
    )                                   AS ToplamGelir,
    (
        SELECT COUNT(*)
        FROM   Orders o2
        WHERE  o2.CustomerID = c.CustomerID
    )                                   AS SiparisSayisi
FROM   Customers c
WHERE  c.Country IN ('Germany', 'UK', 'France', 'USA')
ORDER BY ToplamGelir DESC;

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

-- ============================================================
-- BASELINE Q3: Ürün Bazlı Performans Raporu
-- ============================================================
-- NEDEN YAVAŞ: [Order Details] tablosunun clustered PK'sı
-- (OrderID, ProductID) şeklindedir. ProductID'ye göre arama
-- yapıldığında bu index'i leading key olarak kullanamaz;
-- tüm clustered index taranır.
-- ============================================================
PRINT '';
PRINT '--- BASELINE Q3: Ürün Performans Raporu ---';
PRINT 'Beklenen: [Order Details] üzerinde Clustered Index Scan';
PRINT '';

SET STATISTICS TIME ON;
SET STATISTICS IO ON;

SELECT
    p.ProductName,
    cat.CategoryName,
    COUNT(DISTINCT od.OrderID)          AS KacSiparisteSatildi,
    SUM(od.Quantity)                    AS ToplamAdet,
    SUM(od.UnitPrice * od.Quantity * (1.0 - od.Discount))
                                        AS ToplamGelir,
    AVG(od.UnitPrice)                   AS OrtFiyat
FROM   [Order Details] od
JOIN   Products p    ON p.ProductID     = od.ProductID
JOIN   Categories cat ON cat.CategoryID = p.CategoryID
JOIN   Orders o      ON o.OrderID       = od.OrderID
WHERE  o.OrderDate >= '1996-01-01'
GROUP BY p.ProductName, cat.CategoryName
ORDER BY ToplamGelir DESC;

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

-- ============================================================
-- BASELINE Q4: Tek Müşteri Sipariş Geçmişi (Key Lookup)
-- ============================================================
-- NEDEN YAVAŞ: Mevcut CustomerID index'i yalnızca
-- CustomerID sütununu içerir. Freight ve ShipVia gibi
-- sütunlar için SQL Server clustered index'e KEY LOOKUP
-- yapar. Müşteri sipariş sayısı arttıkça lookup maliyeti
-- de artar.
-- ============================================================
PRINT '';
PRINT '--- BASELINE Q4: Müşteri Sipariş Geçmişi ---';
PRINT 'Beklenen: Index Seek + Key Lookup + Nested Loops';
PRINT '';

SET STATISTICS TIME ON;
SET STATISTICS IO ON;

SELECT
    o.OrderID,
    o.OrderDate,
    o.ShippedDate,
    o.Freight,
    o.ShipVia,
    COUNT(od.ProductID)                 AS KalemSayisi,
    SUM(od.UnitPrice * od.Quantity)     AS AraToplamı
FROM   Orders o
JOIN   [Order Details] od ON od.OrderID = o.OrderID
WHERE  o.CustomerID = 'ALFKI'
GROUP BY o.OrderID, o.OrderDate, o.ShippedDate, o.Freight, o.ShipVia
ORDER BY o.OrderDate DESC;

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

PRINT '';
PRINT '========================================================';
PRINT '  BASELINE ÖLÇÜMLER TAMAMLANDI';
PRINT '  → Messages sekmesinden değerleri kaydedin';
PRINT '  → 08_before_after_comparison.sql ile karşılaştırın';
PRINT '  Sonraki adım: 04_monitoring_queries.sql';
PRINT '========================================================';
