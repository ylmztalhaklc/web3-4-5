-- ============================================================
-- 08_before_after_comparison.sql
-- Amaç : Baseline ölçümler ile optimized ölçümleri
--        sistematik biçimde karşılaştır.
--        Geçici tablolar oluşturarak her sorgu için
--        "öncesi" ve "sonrası" value'ları yakala ve raporla.
--
-- WORKFLOW:
--   1. Baseline Q1-Q4'ü çalıştır (SET STATISTICS ON)
--   2. Optimize indexleri oluştur
--   3. Optimized Q1-Q4'ü çalıştır (SET STATISTICS ON)
--   4. Ölçüm verilerini geçici tabloya kes-yapıştır
--   5. Side-by-side karşılaştırma yap
-- ============================================================

USE Northwind;
GO

PRINT '========================================================';
PRINT '  BEFORE/AFTER KARSILASTIRMASI';
PRINT '  Tarih: ' + CONVERT(varchar, GETDATE(), 120);
PRINT '========================================================';
PRINT '';

-- ============================================================
-- Karsilastirma icin gecici veri tablosu
-- ============================================================
-- MANUEL ADIM: Asagidaki degerleri su sekilde doldurun:
-- 1. 03_baseline_queries.sql calistir → Messages sekmesinden oku
-- 2. 06_create_indexes.sql ve 07_query_optimization.sql calistir
-- 3. Yeni Messages sekmesi degerlerini oku ve buraya gir

DROP TABLE IF EXISTS #KarsilastirmaVerisi;

CREATE TABLE #KarsilastirmaVerisi
(
    SiraNo              int PRIMARY KEY,
    SorguAdi            nvarchar(100),
    Asaması             nvarchar(20),   -- 'BEFORE' | 'AFTER'
    MantikselOkuma      bigint,
    ElapsedMS           int,
    CPUMS               int
);

PRINT 'Karsilastirma Tablosu Olusturuldu.';
PRINT '';
PRINT '============================================================';
PRINT '  MANUEL GIRIS GEREKLI (Messages sekmesinden kopyala)';
PRINT '============================================================';
PRINT '';
PRINT 'BASELINE (03_baseline_queries.sql ciktisinden):';
PRINT '  Q1 Logical Reads: [BURAYA GIR]';
PRINT '  Q1 Elapsed Time : [BURAYA GIR]';
PRINT '  Q1 CPU Time     : [BURAYA GIR]';
PRINT '  ... aynı sekilde Q2, Q3, Q4 icin de';
PRINT '';
PRINT 'OPTIMIZED (07_query_optimization.sql ciktisinden):';
PRINT '  Q1 Logical Reads: [BURAYA GIR]';
PRINT '  Q1 Elapsed Time : [BURAYA GIR]';
PRINT '  ... aynı sekilde devam et';
PRINT '';
PRINT '=> Alternatif: Tabloya INSERT kullanarak otomatik yapin.';
PRINT '   Asagida ornek veriler (gercek degerler ile degistirin):';
PRINT '';

-- ============================================================
-- ORNEK VERI (Gercek olcum degerleri ile degistirin)
-- ============================================================
-- NOT: Bu veriler tutoriyal ornegi. Gercek sistemde:
--   1. 03_baseline_queries.sql calistirin
--   2. Messages sekmesinden (Table | CPU | Elapsed) sayilarini alin
--   3. Asagiya INSERT et
--   4. 06_create_indexes.sql ve 07_query_optimization.sql calistirin
--   5. Yeni degerleri elde edin
--   6. Asagiya ikinci batch INSERT yapin

-- Baseline degerleri (ORNEK - Kendi degerleriniz ile degistirin)
INSERT INTO #KarsilastirmaVerisi VALUES
(1, 'Q1: Non-Sargable Date',   'BEFORE', 1400, 250, 200),
(2, 'Q2: Correlated Subquery', 'BEFORE', 8500, 1200, 950),
(3, 'Q3: Product Report',      'BEFORE', 280,  180, 140),
(4, 'Q4: Customer History',    'BEFORE', 450,  120, 90);

-- Optimized degerleri (ORNEK - Kendi degerleriniz ile degistirin)
INSERT INTO #KarsilastirmaVerisi VALUES
(5, 'Q1: Non-Sargable Date',   'AFTER',  12,   15,  8),
(6, 'Q2: Correlated Subquery', 'AFTER',  890,  200, 150),
(7, 'Q3: Product Report',      'AFTER',  15,   25,  18),
(8, 'Q4: Customer History',    'AFTER',  290,  65,  50);

PRINT 'Ornek veriler eklenmistir. Gercek degerler ile degistirin!';
PRINT '';

-- ============================================================
-- KARSILASTIRMA RAPORU
-- ============================================================
PRINT '--- SONUCLAR: BEFORE vs AFTER ---';
PRINT '';

;WITH BeforeAfter AS
(
    SELECT
        b.SorguAdi,
        b.MantikselOkuma       AS LogicalReads_Before,
        a.MantikselOkuma       AS LogicalReads_After,
        CAST(100.0 * (b.MantikselOkuma - a.MantikselOkuma)
             / b.MantikselOkuma AS decimal(5,1))
                               AS LogicalReads_PercImprovement,
        b.ElapsedMS            AS ElapsedMS_Before,
        a.ElapsedMS            AS ElapsedMS_After,
        CAST(100.0 * (b.ElapsedMS - a.ElapsedMS)
             / b.ElapsedMS AS decimal(5,1))
                               AS ElapsedMS_PercImprovement,
        b.CPUMS                AS CPUMS_Before,
        a.CPUMS                AS CPUMS_After,
        CAST(100.0 * (b.CPUMS - a.CPUMS)
             / b.CPUMS AS decimal(5,1))
                               AS CPUMS_PercImprovement
    FROM #KarsilastirmaVerisi b
    JOIN #KarsilastirmaVerisi a
        ON b.SorguAdi = a.SorguAdi
       AND b.Asaması  = 'BEFORE'
       AND a.Asaması  = 'AFTER'
)
SELECT
    SorguAdi,
    LogicalReads_Before,
    LogicalReads_After,
    CAST(LogicalReads_PercImprovement AS varchar(5)) + ' %' AS [LR_Iyilestirme_Pct],
    '-----',
    ElapsedMS_Before,
    ElapsedMS_After,
    CAST(ElapsedMS_PercImprovement AS varchar(5)) + ' %' AS [Elapsed_Iyilestirme_Pct],
    '-----',
    CPUMS_Before,
    CPUMS_After,
    CAST(CPUMS_PercImprovement AS varchar(5)) + ' %' AS [CPU_Iyilestirme_Pct]
FROM BeforeAfter;

GO

-- ============================================================
-- ÖZETLEYİCİ STATİSTİKLER
-- ============================================================
PRINT '';
PRINT '--- OZET ISTATISTIKLER ---';
PRINT '';

;WITH BeforeAfter AS
(
    SELECT
        b.SorguAdi,
        b.MantikselOkuma       AS LR_Before,
        a.MantikselOkuma       AS LR_After,
        b.ElapsedMS            AS El_Before,
        a.ElapsedMS            AS El_After,
        b.CPUMS                AS CPU_Before,
        a.CPUMS                AS CPU_After
    FROM #KarsilastirmaVerisi b
    JOIN #KarsilastirmaVerisi a
        ON b.SorguAdi = a.SorguAdi
       AND b.Asaması  = 'BEFORE'
       AND a.Asaması  = 'AFTER'
)
SELECT
    'Toplam Mantiksal Okuma Azaltma'
                                    AS [Metrik],
    (SELECT SUM(LR_Before) FROM BeforeAfter)
                                    AS [Before_Toplam],
    (SELECT SUM(LR_After) FROM BeforeAfter)
                                    AS [After_Toplam],
    CAST(100.0 * (
        (SELECT SUM(LR_Before) FROM BeforeAfter) -
        (SELECT SUM(LR_After) FROM BeforeAfter)
    ) / (SELECT SUM(LR_Before) FROM BeforeAfter)
    AS decimal(5,1))                AS [Genel_İyileşme_Yuzde]
UNION ALL
SELECT
    'Toplam Elapsed Time Azaltma',
    (SELECT SUM(El_Before) FROM BeforeAfter),
    (SELECT SUM(El_After) FROM BeforeAfter),
    CAST(100.0 * (
        (SELECT SUM(El_Before) FROM BeforeAfter) -
        (SELECT SUM(El_After) FROM BeforeAfter)
    ) / (SELECT SUM(El_Before) FROM BeforeAfter)
    AS decimal(5,1))
UNION ALL
SELECT
    'Toplam CPU Time Azaltma',
    (SELECT SUM(CPU_Before) FROM BeforeAfter),
    (SELECT SUM(CPU_After) FROM BeforeAfter),
    CAST(100.0 * (
        (SELECT SUM(CPU_Before) FROM BeforeAfter) -
        (SELECT SUM(CPU_After) FROM BeforeAfter)
    ) / (SELECT SUM(CPU_Before) FROM BeforeAfter)
    AS decimal(5,1))
;

PRINT '';
PRINT '========================================================';
PRINT '  KARSILASTIRMA TAMAMLANDI';
PRINT '========================================================';
PRINT '';
PRINT 'KULLANMA TALIMATLARI:';
PRINT '  1. Gercek olcum degerlerini #KarsilastirmaVerisi tablosuna girin';
PRINT '  2. Script yeniden calistirin';
PRINT '  3. Sonuc tablolari rapor icin kopyalayin';
PRINT '';
PRINT 'Sonraki adim: 09_validation_queries.sql';
PRINT '========================================================';

DROP TABLE #KarsilastirmaVerisi;
