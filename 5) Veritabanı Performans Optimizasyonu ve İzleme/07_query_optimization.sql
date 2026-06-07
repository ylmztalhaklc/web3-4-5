-- ============================================================
-- 07_query_optimization.sql
-- Amaç : Yavaş sorgulardan optimized versiyonlarını çalıştır.
--        Anlamlı performans kazancı görülecektir.
--
-- ÖNEMLİ: Bu sorguları 06_create_indexes.sql'den sonra
--         çalıştırın. Index'ler hazır olmalıdır.
--         Yine SET STATISTICS ON ile ölçüm yapılacaktır.
-- ============================================================

USE Northwind;
GO

PRINT '========================================================';
PRINT '  SORGU OPTİMİZASYONU — IYILEŞTIRILMIŞ VERSIYONLAR';
PRINT '  Tarih: ' + CONVERT(varchar, GETDATE(), 120);
PRINT '========================================================';
PRINT '';
PRINT 'NOT: 06_create_indexes.sql çalıştırıldığını varsayıyor.';
PRINT '     Bu sorgular yeni indexleri kullanacaktır.';
PRINT '';

-- ============================================================
-- OPTİMİZED Q1: SARGABLE TARIH FİLTRESİ
-- ============================================================
-- PROBLEM: YEAR(OrderDate) = 1997 → non-sargable
-- ÇÖZÜM:   OrderDate >= '1997-01-01' AND OrderDate < '1998-01-01'
--          → sargable (Index Seek mümkün)
--
-- BEKLENEN:
--   • Index Scan → Index Seek
--   • Logical Reads: ~1400 → ~12
--   • Execution Plan: sada "Seek" görülecek
-- ============================================================
PRINT '--- OPTİMİZED Q1: Sargable Tarih Filtresi ---';
PRINT 'Beklenen: Index Seek on IX_Orders_OrderDate_Covering';
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
WHERE  o.OrderDate >= '1997-01-01'              -- ← SARGABLE!
  AND  o.OrderDate <  '1997-07-01'              -- ← SARGABLE!
GROUP BY o.OrderID, c.CompanyName, c.Country, o.OrderDate
ORDER BY o.OrderDate;

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

-- ============================================================
-- OPTİMİZED Q2: CTE İLE CORRELATED SUBQUERY'Yİ DEĞIŞTIR
-- ============================================================
-- PROBLEM: SELECT listesindeki 2 correlated subquery,
--          her müşteri için ayrı ayrı çalışır (91x2 = 182 geçiş)
-- ÇÖZÜM:   CTE ile müşteri başına agregasyon 1 geçişte yap.
--          Sonra Customers'a JOIN et.
--
-- BEKLENEN:
--   • CPU time: dramatik düşüş (nested loops → hash match)
--   • Logical Reads: [Order Details] üzerinde 91x → 1x
--   • Execution Plan: paralel hash aggregate vs sequential loops
-- ============================================================
PRINT '';
PRINT '--- OPTİMİZED Q2: CTE ile Correlated Subquery Değiştir ---';
PRINT 'Beklenen: Hash Match, çok daha düşük CPU';
PRINT '';

SET STATISTICS TIME ON;
SET STATISTICS IO ON;

-- Adım 1: Müşteri bazında agregasyon (CTE)
WITH MusteriGelir AS
(
    SELECT
        o.CustomerID,
        SUM(od.UnitPrice * od.Quantity * (1.0 - od.Discount))
                                        AS ToplamGelir,
        COUNT(DISTINCT o.OrderID)       AS SiparisSayisi
    FROM   Orders o
    JOIN   [Order Details] od ON od.OrderID = o.OrderID
    GROUP BY o.CustomerID
)
-- Adım 2: Müşteri tablosu ile join ve filtreleme
SELECT
    c.CompanyName,
    c.Country,
    mg.ToplamGelir,
    mg.SiparisSayisi
FROM   Customers c
JOIN   MusteriGelir mg ON mg.CustomerID = c.CustomerID
WHERE  c.Country IN ('Germany', 'UK', 'France', 'USA')
ORDER BY mg.ToplamGelir DESC;

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

-- ============================================================
-- OPTİMİZED Q3: ÜRÜN PERFORMANSI (Index Faydası)
-- ============================================================
-- SORGU METNI: Baseline Q3 ile aynı
-- ANCAK: Yeni IX_OrderDetails_ProductID_Covering index
--        [Order Details] taramasını Index Seek'e çevirir.
--
-- BEKLENEN:
--   • [Order Details] üzerinde: Scan → Seek
--   • Logical Reads: ~280 → ~15
--   • Execution Plan: Index Seek visible
-- ============================================================
PRINT '';
PRINT '--- OPTİMİZED Q3: Ürün Raporları (Index Kullanımı) ---';
PRINT 'Beklenen: IX_OrderDetails_ProductID_Covering Index Seek';
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
-- OPTİMİZED Q4: MÜŞTERI SİPARİŞ GEÇMIŞI (Covering Index)
-- ============================================================
-- SORGU METNI: Baseline Q4 ile aynı
-- ANCAK: IX_Orders_CustomerID_OrderDate covering index
--        (CustomerID, OrderDate) ve INCLUDE (Freight, ShipVia)
--        Key Lookup'ı ortadan kaldırır.
--
-- BEKLENEN:
--   • Execution Plan: "Key Lookup" operatörü kaybolur
--   • Logical Reads: ~40-60% azalış
--   • Index Seek + Compute Scalar + Stream Aggregate → hepsi index'ten
-- ============================================================
PRINT '';
PRINT '--- OPTİMİZED Q4: Müşteri Sipariş Geçmişi (Covering Index) ---';
PRINT 'Beklenen: Key Lookup kaybolacak, sadece Index Seek görülecek';
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
PRINT '  SORGU OPTİMİZASYONU TAMAMLANDI';
PRINT '========================================================';
PRINT '';
PRINT 'ÖNEMLİ: Messages sekmesindeki yeni değerleri kaydedin!';
PRINT '        Baseline değerler ile karşılaştırmak için';
PRINT '        08_before_after_comparison.sql çalıştırın.';
PRINT '';
