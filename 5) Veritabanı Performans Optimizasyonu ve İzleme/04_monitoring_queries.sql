-- ============================================================
-- 04_monitoring_queries.sql
-- Amaç : SQL Server'ın kendi izleme mekanizmalarını kullanarak
--        performans sorunlarını tespit et ve belgele.
--
-- Araçlar: DMV (Dynamic Management Views)
--   • sys.dm_db_missing_index_*   → Eksik index önerileri
--   • sys.dm_exec_query_stats     → Plan cache'teki pahalı sorgular
--   • sys.dm_db_index_usage_stats → Index kullanım istatistikleri
--   • sys.dm_db_index_physical_stats → Fragmantasyon analizi
--   • sys.dm_os_wait_stats         → SQL Server bekleme istatistikleri
--
-- NOT: DMV verileri sunucu yeniden başlatılana kadar birikir.
--      Bu veritabanı sürümü (Express) için tüm DMV'ler desteklenir.
-- ============================================================

USE Northwind;
GO

PRINT '========================================================';
PRINT '  PERFORMANS IZLEME - DMV ANALIZI';
PRINT '  Tarih: ' + CONVERT(varchar, GETDATE(), 120);
PRINT '========================================================';
PRINT '';

-- ============================================================
-- M1: EKSİK INDEX ÖNERİLERİ
-- SQL Server'ın query optimizer'ı, bir sorgu planı oluştururken
-- yararlı olabilecek ama mevcut olmayan indexleri kayıt altına alır.
-- Bu DMV, motoru dinleyerek "kendi kendine" öneride bulunur.
-- ============================================================
PRINT '--- M1: SQL SERVER EKSIK INDEX ONERILERI ---';
PRINT 'Avg_User_Impact: Bu index olsaydi sorgu maliyeti';
PRINT 'ortalama bu kadar % azalirdi.';
PRINT '';

SELECT TOP 20
    DB_NAME(d.database_id)              AS [Veritabani],
    OBJECT_NAME(d.object_id, d.database_id)
                                        AS [Tablo],
    d.equality_columns                  AS [Esitlik_Sutunlari],
    d.inequality_columns                AS [Esitsizlik_Sutunlari],
    d.included_columns                  AS [Include_Sutunlar],
    s.unique_compiles                   AS [Benzersiz_Derleme],
    s.user_seeks                        AS [Kullanici_Arama],
    s.user_scans                        AS [Kullanici_Tarama],
    ROUND(s.avg_total_user_cost, 2)     AS [Ort_Maliyet],
    ROUND(s.avg_user_impact, 2)         AS [Ort_Etki_Yuzde],
    -- Tahmini "fayda skoru"
    ROUND(s.user_seeks * s.avg_user_impact / 100.0, 1)
                                        AS [Faydа_Skoru]
FROM   sys.dm_db_missing_index_details  d
JOIN   sys.dm_db_missing_index_groups   g  ON d.index_handle  = g.index_handle
JOIN   sys.dm_db_missing_index_group_stats s ON g.index_group_handle = s.group_handle
WHERE  d.database_id = DB_ID('Northwind')
ORDER BY [Faydа_Skoru] DESC;
GO

-- ============================================================
-- M2: PLAN CACHE'TEKİ EN PAHALI SORGULAR
-- SQL Server son çalıştırılan sorguların planlarını bellekte tutar.
-- Bu sorgu, en fazla logical read yapan sorguları listeler —
-- bunlar optimizasyon için öncelikli adaylardır.
-- ============================================================
PRINT '';
PRINT '--- M2: PLAN CACHE - EN PAHALI SORGULAR (Logical Read) ---';
PRINT '';

SELECT TOP 10
    qs.total_logical_reads              AS [Toplam_Mantiksal_Okuma],
    qs.execution_count                  AS [Calisma_Sayisi],
    CAST(qs.total_logical_reads * 1.0
         / qs.execution_count AS decimal(18,1))
                                        AS [Ortalama_Mantiksal_Okuma],
    qs.total_worker_time / 1000         AS [Toplam_CPU_ms],
    CAST(qs.total_worker_time * 1.0
         / qs.execution_count / 1000 AS decimal(18,1))
                                        AS [Ort_CPU_ms],
    qs.total_elapsed_time / 1000        AS [Toplam_Sure_ms],
    -- İlk 150 karakter (tüm metin için CROSS APPLY kullanın)
    SUBSTRING(st.text, 1, 150)          AS [Sorgu_Metni_Kisaltilmis]
FROM   sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
WHERE  st.dbid = DB_ID('Northwind')
   OR  st.text LIKE '%Northwind%'
ORDER BY qs.total_logical_reads DESC;
GO

-- ============================================================
-- M3: INDEX KULLANIM İSTATİSTİKLERİ
-- Hangi indexler aranıyor (seek), taranıyor (scan), lookup
-- yapılıyor ve ne sıklıkla güncelleniyor?
-- Yüksek scan + sıfır seek → index verimsiz veya gereksiz.
-- ============================================================
PRINT '';
PRINT '--- M3: INDEX KULLANIM ISTATISTIKLERI ---';
PRINT 'Sifir_Seek + Yuksek_Scan: Incelenecek index';
PRINT '';

SELECT
    OBJECT_NAME(i.object_id)            AS [Tablo],
    i.name                              AS [Index_Adi],
    i.type_desc                         AS [Tip],
    ISNULL(u.user_seeks,  0)            AS [Arama_Seek],
    ISNULL(u.user_scans,  0)            AS [Tarama_Scan],
    ISNULL(u.user_lookups, 0)           AS [Lookup],
    ISNULL(u.user_updates, 0)           AS [Guncelleme],
    ISNULL(u.last_user_seek,  NULL)     AS [Son_Seek],
    ISNULL(u.last_user_scan,  NULL)     AS [Son_Scan]
FROM   sys.indexes i
LEFT  JOIN sys.dm_db_index_usage_stats u
       ON u.object_id    = i.object_id
      AND u.index_id     = i.index_id
      AND u.database_id  = DB_ID('Northwind')
JOIN   sys.objects o ON i.object_id = o.object_id
WHERE  o.type = 'U'
  AND  OBJECT_NAME(i.object_id) IN
       ('Orders','Order Details','Customers','Products')
  AND  i.type > 0
ORDER BY OBJECT_NAME(i.object_id), i.index_id;
GO

-- ============================================================
-- M4: INDEX FRAGMANTASYONU
-- Veri eklendikten sonra index sayfaları parçalanmış olabilir.
-- avg_fragmentation_in_percent > 30 → REBUILD önerilir.
-- avg_fragmentation_in_percent 10-30 → REORGANIZE yeterli.
-- ============================================================
PRINT '';
PRINT '--- M4: INDEX FRAGMANTASYON ANALIZI ---';
PRINT '>30% fragmantasyon: REBUILD gerekli';
PRINT '10-30%           : REORGANIZE yeterli';
PRINT '';

SELECT
    OBJECT_NAME(ips.object_id)          AS [Tablo],
    i.name                              AS [Index_Adi],
    ips.index_type_desc                 AS [Tip],
    ips.page_count                      AS [Sayfa_Sayisi],
    ROUND(ips.avg_fragmentation_in_percent, 2)
                                        AS [Fragmantasyon_Yuzde],
    CASE
        WHEN ips.avg_fragmentation_in_percent > 30 THEN 'REBUILD gerekli'
        WHEN ips.avg_fragmentation_in_percent > 10 THEN 'REORGANIZE yeterli'
        ELSE 'Normal'
    END                                 AS [Öneri]
FROM   sys.dm_db_index_physical_stats(
           DB_ID('Northwind'), NULL, NULL, NULL, 'LIMITED') ips
JOIN   sys.indexes i
       ON  ips.object_id = i.object_id
       AND ips.index_id  = i.index_id
WHERE  ips.page_count > 10   -- küçük indexleri filtrele
ORDER BY ips.avg_fragmentation_in_percent DESC;
GO

-- ============================================================
-- M5: WAIT İSTATİSTİKLERİ (Anlık Snapshot)
-- SQL Server'ın ne üzerinde beklediğini gösterir.
-- Bir akademik demoda bu çıktı "sistem genel sağlık durumu"
-- bölümüne konabilir.
-- ============================================================
PRINT '';
PRINT '--- M5: WAIT ISTATISTIKLERI (TOP 15) ---';
PRINT 'Bilinen bosta bekleme turleri filtrelenmiş.';
PRINT '';

SELECT TOP 15
    wait_type                           AS [Bekleme_Turu],
    waiting_tasks_count                 AS [Bekleyen_Gorev],
    wait_time_ms                        AS [Toplam_Bekleme_ms],
    max_wait_time_ms                    AS [Maks_Bekleme_ms],
    signal_wait_time_ms                 AS [Sinyal_Bekleme_ms]
FROM   sys.dm_os_wait_stats
WHERE  wait_type NOT IN (
    'SLEEP_TASK','SLEEP_SYSTEMTASK','SLEEP_DBSTARTUP',
    'SLEEP_DCOMSTARTUP','SLEEP_MASTERDBREADY',
    'SLEEP_MASTERMDREADY','SLEEP_MASTERUPGRADED',
    'SLEEP_MSDBSTARTUP','SLEEP_TEMPDBSTARTUP',
    'SLEEP_MASTERSTARTED','WAITFOR','LAZYWRITER_SLEEP',
    'SQLTRACE_BUFFER_FLUSH','CLR_AUTO_EVENT','CLR_MANUAL_EVENT',
    'DISPATCHER_QUEUE_SEMAPHORE','XE_DISPATCHER_WAIT',
    'XE_TIMER_EVENT','BROKER_TO_FLUSH','BROKER_TASK_STOP',
    'CHECKPOINT_QUEUE','DBMIRROR_EVENTS_QUEUE',
    'SQLTRACE_INCREMENTAL_FLUSH_SLEEP','ONDEMAND_TASK_QUEUE',
    'REQUEST_FOR_DEADLOCK_SEARCH','RESOURCE_QUEUE',
    'SERVER_IDLE_CHECK','HADR_WORK_QUEUE',
    'SNI_HTTP_ACCEPT','SP_SERVER_DIAGNOSTICS_SLEEP',
    'WAIT_XTP_OFFLINE_CKPT_NEW_LOG','FT_IFTS_SCHEDULER_IDLE_WAIT'
)
ORDER BY wait_time_ms DESC;
GO

-- ============================================================
-- M6: İSTATİSTİK GÜNCELLIK KONTROLÜ
-- Optimizer'ın kullandığı istatistikler güncel değilse
-- kötü execution plan üretilebilir.
-- ============================================================
PRINT '';
PRINT '--- M6: ISTATISTIK GUNCELLIK KONTROLU ---';
PRINT '';

SELECT
    OBJECT_NAME(s.object_id)            AS [Tablo],
    s.name                              AS [Istatistik_Adi],
    STATS_DATE(s.object_id, s.stats_id) AS [Son_Guncelleme],
    DATEDIFF(DAY,
        STATS_DATE(s.object_id, s.stats_id),
        GETDATE())                      AS [Gun_Oncesi],
    s.auto_created                      AS [Otomatik_mi],
    s.user_created                      AS [Kullanici_mi]
FROM   sys.stats s
JOIN   sys.objects o ON s.object_id = o.object_id
WHERE  o.type = 'U'
  AND  OBJECT_NAME(s.object_id) IN
       ('Orders','Order Details','Customers','Products')
ORDER BY STATS_DATE(s.object_id, s.stats_id) ASC;
GO

PRINT '';
PRINT '========================================================';
PRINT '  IZLEME ANALIZI TAMAMLANDI';
PRINT '  M1 ciktisina bakin: SQL Server onerdi indexler';
PRINT '  06_create_indexes.sql ile uygulanacak.';
PRINT '  Sonraki adim: 05_index_analysis.sql';
PRINT '========================================================';
