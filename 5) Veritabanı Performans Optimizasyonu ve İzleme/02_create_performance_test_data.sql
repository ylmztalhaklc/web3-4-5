-- ============================================================
-- 02_create_performance_test_data.sql
-- Amaç : Orders tablosunu ~50.000 satıra, [Order Details]
--        tablosunu orantılı biçimde genişlet.
--        Performans ölçümlerinin anlamlı olması için gerekli.
--
-- UYARI : Çalışma süresi 3-7 dakika olabilir. İptal etmeyin.
-- İDEMPOTENCY: Bu script tekrar çalıştırılsa bile güvenlidir.
--         Mevcut Orders >= 40.000 satır ise hiçbir değişiklik
--         yapmaz ve sonlanır. Tekrar çalıştırmak istiyorsanız
--         00_northwind_kurulum.sql ile sıfırla.
-- ============================================================

USE Northwind;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

PRINT '========================================================';
PRINT '  TEST VERİSİ OLUŞTURULUYOR...';
PRINT '  Başlangıç: ' + CONVERT(varchar, GETDATE(), 120);
PRINT '========================================================';

-- ── Mevcut Satır Sayısını Kontrol Et ────────────────────────
-- NOT: RETURN sonraki batch'leri durdurmaz. Bu batch'te
--      guard + tüm veri ekleme mantığı tek seferde çalışır.
DECLARE @mevcutSiparis int = (SELECT COUNT(*) FROM Orders);
PRINT 'Mevcut Orders satır sayısı: ' + CAST(@mevcutSiparis AS varchar);

IF @mevcutSiparis >= 40000
BEGIN
    PRINT 'Veri zaten genişletilmiş (>= 40.000 satır). Script sonlandırıldı.';
    RETURN;
END;

-- Temp tables varsa temizle (script tekrar çalıştırıldıysa)
IF OBJECT_ID('tempdb..#MusteriListesi') IS NOT NULL DROP TABLE #MusteriListesi;
IF OBJECT_ID('tempdb..#KaynakDetaylar') IS NOT NULL DROP TABLE #KaynakDetaylar;
IF OBJECT_ID('tempdb..#KaynakOrders') IS NOT NULL DROP TABLE #KaynakOrders;
IF OBJECT_ID('tempdb..#EslestirmeTablosu') IS NOT NULL DROP TABLE #EslestirmeTablosu;

-- ── 1. Yardımcı Tablolar ─────────────────────────────────────

-- Müşteri döngüsel seçimi için numaralı liste
SELECT
    ROW_NUMBER() OVER (ORDER BY CustomerID) AS Sira,
    CustomerID
INTO #MusteriListesi
FROM Customers;

DECLARE @musteriSayisi int = (SELECT COUNT(*) FROM #MusteriListesi);

IF @musteriSayisi = 0
BEGIN
    PRINT 'HATA: Customers tablosu boş!';
    RETURN;
END;

PRINT 'Müşteri listesi hazırlandı: ' + CAST(@musteriSayisi AS varchar) + ' müşteri';

-- Kaynak sipariş detayları (template)
SELECT OrderID AS TemplateOrderID, ProductID, UnitPrice, Quantity, Discount
INTO #KaynakDetaylar
FROM [Order Details]
WHERE OrderID BETWEEN 1 AND 830;

-- Kaynak sipariş başlıkları: sabit kopyalanacak alan + sıra no
SELECT
    OrderID, OrderDate, RequiredDate, ShippedDate,
    ShipVia, Freight, ShipName, ShipAddress, ShipCity,
    ShipRegion, ShipPostalCode, ShipCountry,
    ROW_NUMBER() OVER (ORDER BY OrderID) AS Sira
INTO #KaynakOrders
FROM Orders
WHERE OrderID BETWEEN 1 AND 830;

DECLARE @kaynakSayisi int = (SELECT COUNT(*) FROM #KaynakOrders);
DECLARE @detaySayisi int = (SELECT COUNT(*) FROM #KaynakDetaylar);

PRINT 'Müşteri sayısı  : ' + CAST(@musteriSayisi AS varchar);
PRINT 'Kaynak sipariş  : ' + CAST(@kaynakSayisi  AS varchar);
PRINT 'Kaynak detay    : ' + CAST(@detaySayisi AS varchar);
PRINT '';
PRINT 'Döngüsel veri ekleme başlıyor. Hedef: 50.000 sipariş...';

-- ── 2. Ana Döngü ─────────────────────────────────────────────
DECLARE
    @turNo          int = 0,
    @offsetAy       int,
    @minYeniID      int,
    @maxYeniID      int,
    @eklenen        int,
    @toplamOrders   int;

-- Yeni ↔ Eski OrderID eşleştirme tablosu
CREATE TABLE #EslestirmeTablosu
(
    YeniOrderID     int NOT NULL,
    EskiOrderID     int NOT NULL
);

WHILE 1 = 1
BEGIN
    SELECT @toplamOrders = COUNT(*) FROM Orders;
    
    IF @toplamOrders >= 50000
    BEGIN
        PRINT 'Hedef ulaşıldı: ' + CAST(@toplamOrders AS varchar) + ' sipariş. Döngü sonlanıyor.';
        BREAK;
    END;
    
    SET @turNo    = @turNo + 1;
    SET @offsetAy = @turNo * 24;

    -- Orders insert
    INSERT INTO Orders
    (
        CustomerID, EmployeeID, OrderDate, RequiredDate,
        ShippedDate, ShipVia, Freight,
        ShipName, ShipAddress, ShipCity,
        ShipRegion, ShipPostalCode, ShipCountry
    )
    SELECT
        ml.CustomerID,
        ((ko.Sira - 1) % 9) + 1                             AS EmployeeID,
        DATEADD(MONTH, @offsetAy, ko.OrderDate)             AS OrderDate,
        DATEADD(MONTH, @offsetAy, ko.RequiredDate)          AS RequiredDate,
        CASE WHEN ko.ShippedDate IS NOT NULL
             THEN DATEADD(MONTH, @offsetAy, ko.ShippedDate)
             ELSE NULL END                                   AS ShippedDate,
        ko.ShipVia,
        ko.Freight,
        ko.ShipName, ko.ShipAddress, ko.ShipCity,
        ko.ShipRegion, ko.ShipPostalCode, ko.ShipCountry
    FROM #KaynakOrders ko
    CROSS JOIN (SELECT TOP (@musteriSayisi) Sira, CustomerID FROM #MusteriListesi ORDER BY Sira) ml
    WHERE ml.Sira = ((ko.Sira - 1) % @musteriSayisi) + 1;

    SET @eklenen   = @@ROWCOUNT;
    
    IF @eklenen = 0
    BEGIN
        PRINT 'HATA (Tur ' + CAST(@turNo AS varchar) + '): INSERT satır eklenmedi! Sorguyu kontrol edin.';
        BREAK;
    END;

    SET @maxYeniID = IDENT_CURRENT('Orders');
    SET @minYeniID = @maxYeniID - @eklenen + 1;

    -- Yeni ID'leri kaynak sırayla eşleştir
    TRUNCATE TABLE #EslestirmeTablosu;

    ;WITH YeniSira AS (
        SELECT OrderID AS YeniOrderID,
               ROW_NUMBER() OVER (ORDER BY OrderID) AS Sira
        FROM Orders
        WHERE OrderID BETWEEN @minYeniID AND @maxYeniID
    )
    INSERT INTO #EslestirmeTablosu (YeniOrderID, EskiOrderID)
    SELECT ys.YeniOrderID, ko.OrderID
    FROM YeniSira ys
    JOIN #KaynakOrders ko ON ko.Sira = ys.Sira;

    -- [Order Details] kopyala
    INSERT INTO [Order Details] (OrderID, ProductID, UnitPrice, Quantity, Discount)
    SELECT
        et.YeniOrderID,
        kd.ProductID,
        kd.UnitPrice,
        kd.Quantity,
        kd.Discount
    FROM #EslestirmeTablosu et
    JOIN #KaynakDetaylar kd ON kd.TemplateOrderID = et.EskiOrderID;

    -- Her 5 turda bir ilerleme raporu
    IF @turNo % 5 = 0
        PRINT '  Tur: ' + CAST(@turNo AS varchar)
              + '  |  Toplam Orders: '
              + CAST(@toplamOrders AS varchar)
              + '  |  ' + CONVERT(varchar, GETDATE(), 108);
END;

-- ── 3. Temizlik ──────────────────────────────────────────────
DROP TABLE #MusteriListesi;
DROP TABLE #KaynakDetaylar;
DROP TABLE #KaynakOrders;
DROP TABLE #EslestirmeTablosu;
GO

-- ── 4. İstatistikleri Güncelle ───────────────────────────────
PRINT '';
PRINT 'İstatistikler güncelleniyor (FULLSCAN)...';
UPDATE STATISTICS Orders         WITH FULLSCAN;
UPDATE STATISTICS [Order Details] WITH FULLSCAN;
PRINT 'Güncelleme tamamlandı.';
GO

-- ── 5. Sonuç Doğrulama ───────────────────────────────────────
PRINT '';
PRINT '--- SONUÇ: TABLO BOYUTLARI ---';
SELECT
    OBJECT_NAME(p.object_id)    AS [Tablo],
    SUM(p.rows)                 AS [Satir_Sayisi]
FROM sys.partitions p
JOIN sys.objects o ON p.object_id = o.object_id
WHERE o.type = 'U'
  AND p.index_id IN (0, 1)
  AND OBJECT_NAME(p.object_id) IN ('Orders','Order Details')
GROUP BY p.object_id
ORDER BY SUM(p.rows) DESC;

SELECT
    MIN(OrderDate) AS [En_Eski_Siparis],
    MAX(OrderDate) AS [En_Yeni_Siparis],
    COUNT(*)       AS [Toplam_Siparis]
FROM Orders;
GO

PRINT '';
PRINT '========================================================';
PRINT '  TEST VERİSİ OLUŞTURMA TAMAMLANDI';
PRINT '  Bitiş: ' + CONVERT(varchar, GETDATE(), 120);
PRINT '  Sonraki adım: 03_baseline_queries.sql';
PRINT '========================================================';
