-- Full NA funnel, D-1 vs D, TY vs LY, per platform (app iOS/Android, touch,
-- web) and platform x traffic bucket:
--   UV -> impressions -> UDV (and UDV visitors) -> buy-button clicks ->
--   checkout views / checkout UV -> orders
-- Sources (all queryable from FoundryAI; the dataview views are denied):
--   UV by platform x L1 traffic  kbc-grpn-28.out_c_additional_views_rm_sheet.additional_view_rm_sheet
--                                 (D can be partial until its next refresh; SEM not split)
--   UV by traffic, de-duplicated  kbc-grpn-28.out_c_rm_tracker.rm_tracker (no platform)
--   impressions / UDV / UDVV      kbc-grpn-28.in_c_tr_level_02_gpr_traffic_l1.agg_gbl_traffic_l1
--                                 (linked copy of kbc-grpn-14 agg_gbl_traffic_l1)
--   orders                        kbc-grpn-35 unit_economics (distinct parent orders)
--   buy clicks / checkout         kbc-grpn-28.janus_impressions.junoHourly (external table,
--                                 TY only: retention starts 2026-07-16), traffic source via
--                                 mvp_rt_traffic_metrics.daily_first_click_traffic_source_details
-- Cost: the dry run shows ~1.1 GB but the external Janus table plus the
-- bcookie/traffic join actually process ~6.7 GB. Drop chk_uv and the fc join
-- to cut the Janus part to ~0.4 GB.
-- Caveats: chk_uv and udvv are sums of distinct counts across groups
-- (approximate); Janus traffic attribution uses the real-time first-click
-- taxonomy (PLA falls into Non Brand SEM), so compare SEM at "SEM (all)".
-- Output: one CSV string, saved as data/na_full_funnel.csv.

WITH d AS (
  SELECT * FROM UNNEST([
    STRUCT(DATE '2026-09-21' AS dt, 'ty_d1' AS b),
    (DATE '2025-09-22', 'ly_d1'),
    (DATE '2026-09-22', 'ty_d'),
    (DATE '2025-09-23', 'ly_d')])
),
-- 1) UV: platform x L1 traffic source (SEM not split in this source)
uv_src AS (
  SELECT d.b,
    CASE WHEN STARTS_WITH(LOWER(s.platform),'app') THEN 'app' WHEN STARTS_WITH(LOWER(s.platform),'touch') THEN 'touch'
         WHEN STARTS_WITH(LOWER(s.platform),'web') THEN 'web' ELSE 'other' END AS plat,
    CAST(NULL AS STRING) AS os,
    CASE WHEN s.traffic_source = 'SEM' THEN 'SEM (all)'
         WHEN s.traffic_source IN ('Direct','SEO','Email','Push Notification','Affiliate','Display') THEN s.traffic_source
         ELSE 'Other' END AS tb,
    SUM(s.uvs) AS uv
  FROM `kbc-grpn-28.out_c_additional_views_rm_sheet.additional_view_rm_sheet` s
  JOIN d ON s.date = d.dt
  WHERE s.date IN ('2026-09-21','2025-09-22','2026-09-22','2025-09-23') AND s.economic_area = 'NA'
  GROUP BY 1,2,3,4
),
-- 1b) UV by traffic bucket (all platforms, de-duplicated) from RM tracker
rmt AS (
  SELECT d.b, 'ALLPLAT' AS plat, CAST(NULL AS STRING) AS os,
    CASE r.traffic_source_bucketing WHEN 'SEM Brand' THEN 'Brand SEM' WHEN 'SEM Non-Brand' THEN 'Non Brand SEM'
         WHEN 'SEM PLA' THEN 'SEM PLA' WHEN 'OnlineOther' THEN 'Other' ELSE r.traffic_source_bucketing END AS tb,
    SUM(r.uv) AS uv_rmt
  FROM `kbc-grpn-28.out_c_rm_tracker.rm_tracker` r
  JOIN d ON r.date_key = d.dt
  WHERE r.date_key IN ('2026-09-21','2025-09-22','2026-09-22','2025-09-23') AND r.region = 'NA'
  GROUP BY 1,2,3,4
),
-- 2) Impressions / UDV / UDVV: platform x sub_platform x traffic source x sub source
trf AS (
  SELECT d.b,
    CASE WHEN STARTS_WITH(LOWER(t.platform),'app') THEN 'app' WHEN STARTS_WITH(LOWER(t.platform),'touch') THEN 'touch'
         WHEN STARTS_WITH(LOWER(t.platform),'web') THEN 'web' ELSE 'other' END AS plat,
    CASE WHEN NOT STARTS_WITH(LOWER(t.platform),'app') THEN NULL
         WHEN STARTS_WITH(LOWER(t.sub_platform),'iphone') OR STARTS_WITH(LOWER(t.sub_platform),'ipad') THEN 'iOS'
         WHEN STARTS_WITH(LOWER(t.sub_platform),'android') THEN 'Android' ELSE 'unknown' END AS os,
    CASE WHEN t.traffic_source = 'SEM' AND t.traffic_sub_source = 'Brand' THEN 'Brand SEM'
         WHEN t.traffic_source = 'SEM' AND t.traffic_sub_source = 'Product Listings' THEN 'SEM PLA'
         WHEN t.traffic_source = 'SEM' THEN 'Non Brand SEM'
         WHEN t.traffic_source IN ('Direct','SEO','Email','Push Notification','Affiliate','Display') THEN t.traffic_source
         ELSE 'Other' END AS tb,
    SUM(t.uniq_deal_view_visitors) AS udvv, SUM(t.uniq_deal_views) AS udv, SUM(t.total_impressions) AS imp
  FROM `kbc-grpn-28.in_c_tr_level_02_gpr_traffic_l1.agg_gbl_traffic_l1` t
  JOIN d ON t.report_date = d.dt
  WHERE t.report_date IN ('2026-09-21','2025-09-22','2026-09-22','2025-09-23') AND t.economic_area = 'NA'
  GROUP BY 1,2,3,4
),
-- 3) Orders (authorized/captured, not cancelled; distinct parent orders)
ord AS (
  SELECT d.b,
    CASE WHEN STARTS_WITH(LOWER(u.platform),'app') THEN 'app' WHEN STARTS_WITH(LOWER(u.platform),'touch') THEN 'touch'
         WHEN STARTS_WITH(LOWER(u.platform),'web') THEN 'web' ELSE 'other' END AS plat,
    CASE WHEN NOT STARTS_WITH(LOWER(u.platform),'app') THEN NULL
         WHEN STARTS_WITH(LOWER(u.sub_platform),'iphone') OR STARTS_WITH(LOWER(u.sub_platform),'ipad') THEN 'iOS'
         WHEN STARTS_WITH(LOWER(u.sub_platform),'android') THEN 'Android' ELSE 'unknown' END AS os,
    CASE WHEN u.traffic_source = 'SEM' AND u.traffic_sub_source = 'Brand' THEN 'Brand SEM'
         WHEN u.traffic_source = 'SEM' AND u.traffic_sub_source = 'Product Listings' THEN 'SEM PLA'
         WHEN u.traffic_source = 'SEM' THEN 'Non Brand SEM'
         WHEN u.traffic_source IN ('Direct','SEO','Email','Push Notification','Affiliate','Display') THEN u.traffic_source
         ELSE 'Other' END AS tb,
    COUNT(DISTINCT u.parent_order_uuid) AS orders
  FROM `kbc-grpn-35.out_c_ue_location_and_ownership.unit_economics` u
  JOIN d ON u.operational_view_date = d.dt
  WHERE u.operational_view_date IN ('2026-09-21','2025-09-22','2026-09-22','2025-09-23')
    AND u.economic_area = 'NA' AND u.event_type IN ('authorize','capture') AND IFNULL(u.last_status,'') <> 'cancel'
  GROUP BY 1,2,3,4
),
-- 4) Buy-button clicks / checkout views / checkout UV (TY only: Janus retention starts 2026-07-16)
jan AS (
  SELECT j.eventDate AS ds, j.event, j.bcookie,
    CASE WHEN j.platform = 'mobile' THEN 'app' WHEN j.clientPlatform = 'Touch' THEN 'touch' ELSE 'web' END AS plat,
    CASE WHEN j.platform <> 'mobile' THEN NULL WHEN j.clientPlatform IN ('iPhone','iPad') THEN 'iOS'
         WHEN j.clientPlatform = 'Android' THEN 'Android' ELSE 'unknown' END AS os
  FROM `kbc-grpn-28.janus_impressions.junoHourly` j
  WHERE j.eventDate IN ('2026-09-21','2026-09-22') AND j.eventDestination = 'purchaseFunnel'
    AND j.platform IN ('web','mobile') AND j.event IN ('buyButtonClick','checkoutView')
    AND j.country IN ('US','CA') AND IFNULL(j.isBot,'false') <> 'true'
),
fc AS (
  SELECT event_date, bcookie, traffic_source, traffic_sub_source
  FROM `kbc-grpn-28.mvp_rt_traffic_metrics.daily_first_click_traffic_source_details`
  WHERE event_date IN ('2026-09-21','2026-09-22')
),
jagg AS (
  SELECT d.b, jan.plat, jan.os,
    CASE WHEN fc.traffic_source = 'SEM' AND fc.traffic_sub_source = 'Brand' THEN 'Brand SEM'
         WHEN fc.traffic_source = 'SEM' AND fc.traffic_sub_source = 'Product Listings' THEN 'SEM PLA'
         WHEN fc.traffic_source = 'SEM' THEN 'Non Brand SEM'
         WHEN fc.traffic_source IN ('Direct','SEO','Email','Push Notification','Affiliate','Display') THEN fc.traffic_source
         ELSE 'Other' END AS tb,
    COUNTIF(jan.event = 'buyButtonClick') AS bbc,
    COUNTIF(jan.event = 'checkoutView') AS chk_views,
    COUNT(DISTINCT IF(jan.event = 'checkoutView', jan.bcookie, NULL)) AS chk_uv
  FROM jan
  JOIN d ON jan.ds = CAST(d.dt AS STRING)
  LEFT JOIN fc ON fc.bcookie = jan.bcookie AND fc.event_date = d.dt
  GROUP BY 1,2,3,4
),
lng AS (
  SELECT b, plat, os, tb, uv, NULL AS uv_rmt, NULL AS udvv, NULL AS udv, NULL AS imp, NULL AS orders, NULL AS bbc, NULL AS chk_views, NULL AS chk_uv FROM uv_src
  UNION ALL SELECT b, plat, os, tb, NULL, uv_rmt, NULL, NULL, NULL, NULL, NULL, NULL, NULL FROM rmt
  UNION ALL SELECT b, plat, os, tb, NULL, NULL, udvv, udv, imp, NULL, NULL, NULL, NULL FROM trf
  UNION ALL SELECT b, plat, os, tb, NULL, NULL, NULL, NULL, NULL, orders, NULL, NULL, NULL FROM ord
  UNION ALL SELECT b, plat, os, tb, NULL, NULL, NULL, NULL, NULL, NULL, bbc, chk_views, chk_uv FROM jagg
),
fact AS (
  SELECT *, FALSE AS dup FROM lng
  UNION ALL
  SELECT b, plat, os, 'SEM (all)', uv, uv_rmt, udvv, udv, imp, orders, bbc, chk_views, chk_uv, TRUE
  FROM lng WHERE tb IN ('Brand SEM','Non Brand SEM','SEM PLA')
),
rw AS (
  SELECT plat AS platform, tb AS traffic, b, SUM(uv) uv, SUM(uv_rmt) uv_rmt, SUM(udvv) udvv, SUM(udv) udv, SUM(imp) imp,
         SUM(orders) orders, SUM(bbc) bbc, SUM(chk_views) chk_views, SUM(chk_uv) chk_uv
  FROM fact WHERE plat IN ('app','touch','web') GROUP BY 1,2,3
  UNION ALL
  SELECT plat, 'ALL', b, SUM(uv), SUM(uv_rmt), SUM(udvv), SUM(udv), SUM(imp), SUM(orders), SUM(bbc), SUM(chk_views), SUM(chk_uv)
  FROM fact WHERE NOT dup AND plat IN ('app','touch','web','other') GROUP BY 1,2,3
  UNION ALL
  SELECT CONCAT('app_', os), 'ALL', b, SUM(uv), SUM(uv_rmt), SUM(udvv), SUM(udv), SUM(imp), SUM(orders), SUM(bbc), SUM(chk_views), SUM(chk_uv)
  FROM fact WHERE NOT dup AND plat = 'app' AND os IS NOT NULL GROUP BY 1,2,3
  UNION ALL
  SELECT 'ALL', tb, b, SUM(uv), SUM(uv_rmt), SUM(udvv), SUM(udv), SUM(imp), SUM(orders), SUM(bbc), SUM(chk_views), SUM(chk_uv)
  FROM fact GROUP BY 1,2,3
  UNION ALL
  SELECT 'ALL', 'ALL', b, SUM(uv), SUM(uv_rmt), SUM(udvv), SUM(udv), SUM(imp), SUM(orders), SUM(bbc), SUM(chk_views), SUM(chk_uv)
  FROM fact WHERE NOT dup GROUP BY 1,2,3
),
piv AS (
  SELECT platform, traffic,
    SUM(IF(b='ty_d1',uv,NULL)) uv_ty_d1, SUM(IF(b='ly_d1',uv,NULL)) uv_ly_d1, SUM(IF(b='ty_d',uv,NULL)) uv_ty_d, SUM(IF(b='ly_d',uv,NULL)) uv_ly_d,
    SUM(IF(b='ty_d1',uv_rmt,NULL)) uvrmt_ty_d1, SUM(IF(b='ly_d1',uv_rmt,NULL)) uvrmt_ly_d1, SUM(IF(b='ty_d',uv_rmt,NULL)) uvrmt_ty_d, SUM(IF(b='ly_d',uv_rmt,NULL)) uvrmt_ly_d,
    SUM(IF(b='ty_d1',udvv,NULL)) udvv_ty_d1, SUM(IF(b='ly_d1',udvv,NULL)) udvv_ly_d1, SUM(IF(b='ty_d',udvv,NULL)) udvv_ty_d, SUM(IF(b='ly_d',udvv,NULL)) udvv_ly_d,
    SUM(IF(b='ty_d1',udv,NULL)) udv_ty_d1, SUM(IF(b='ly_d1',udv,NULL)) udv_ly_d1, SUM(IF(b='ty_d',udv,NULL)) udv_ty_d, SUM(IF(b='ly_d',udv,NULL)) udv_ly_d,
    SUM(IF(b='ty_d1',imp,NULL)) imp_ty_d1, SUM(IF(b='ly_d1',imp,NULL)) imp_ly_d1, SUM(IF(b='ty_d',imp,NULL)) imp_ty_d, SUM(IF(b='ly_d',imp,NULL)) imp_ly_d,
    SUM(IF(b='ty_d1',orders,NULL)) ord_ty_d1, SUM(IF(b='ly_d1',orders,NULL)) ord_ly_d1, SUM(IF(b='ty_d',orders,NULL)) ord_ty_d, SUM(IF(b='ly_d',orders,NULL)) ord_ly_d,
    SUM(IF(b='ty_d1',bbc,NULL)) bbc_ty_d1, SUM(IF(b='ty_d',bbc,NULL)) bbc_ty_d,
    SUM(IF(b='ty_d1',chk_views,NULL)) chkv_ty_d1, SUM(IF(b='ty_d',chk_views,NULL)) chkv_ty_d,
    SUM(IF(b='ty_d1',chk_uv,NULL)) chkuv_ty_d1, SUM(IF(b='ty_d',chk_uv,NULL)) chkuv_ty_d
  FROM rw GROUP BY 1,2
)
SELECT CONCAT(
  'platform,traffic,uv_ty_d1,uv_ly_d1,uv_ty_d,uv_ly_d,uvrmt_ty_d1,uvrmt_ly_d1,uvrmt_ty_d,uvrmt_ly_d,udvv_ty_d1,udvv_ly_d1,udvv_ty_d,udvv_ly_d,udv_ty_d1,udv_ly_d1,udv_ty_d,udv_ly_d,imp_ty_d1,imp_ly_d1,imp_ty_d,imp_ly_d,ord_ty_d1,ord_ly_d1,ord_ty_d,ord_ly_d,bbc_ty_d1,bbc_ty_d,chkv_ty_d1,chkv_ty_d,chkuv_ty_d1,chkuv_ty_d\n',
  STRING_AGG(ARRAY_TO_STRING([platform, traffic,
    IFNULL(CAST(uv_ty_d1 AS STRING),''), IFNULL(CAST(uv_ly_d1 AS STRING),''), IFNULL(CAST(uv_ty_d AS STRING),''), IFNULL(CAST(uv_ly_d AS STRING),''),
    IFNULL(CAST(CAST(uvrmt_ty_d1 AS INT64) AS STRING),''), IFNULL(CAST(CAST(uvrmt_ly_d1 AS INT64) AS STRING),''), IFNULL(CAST(CAST(uvrmt_ty_d AS INT64) AS STRING),''), IFNULL(CAST(CAST(uvrmt_ly_d AS INT64) AS STRING),''),
    IFNULL(CAST(udvv_ty_d1 AS STRING),''), IFNULL(CAST(udvv_ly_d1 AS STRING),''), IFNULL(CAST(udvv_ty_d AS STRING),''), IFNULL(CAST(udvv_ly_d AS STRING),''),
    IFNULL(CAST(CAST(udv_ty_d1 AS INT64) AS STRING),''), IFNULL(CAST(CAST(udv_ly_d1 AS INT64) AS STRING),''), IFNULL(CAST(CAST(udv_ty_d AS INT64) AS STRING),''), IFNULL(CAST(CAST(udv_ly_d AS INT64) AS STRING),''),
    IFNULL(CAST(imp_ty_d1 AS STRING),''), IFNULL(CAST(imp_ly_d1 AS STRING),''), IFNULL(CAST(imp_ty_d AS STRING),''), IFNULL(CAST(imp_ly_d AS STRING),''),
    IFNULL(CAST(ord_ty_d1 AS STRING),''), IFNULL(CAST(ord_ly_d1 AS STRING),''), IFNULL(CAST(ord_ty_d AS STRING),''), IFNULL(CAST(ord_ly_d AS STRING),''),
    IFNULL(CAST(bbc_ty_d1 AS STRING),''), IFNULL(CAST(bbc_ty_d AS STRING),''),
    IFNULL(CAST(chkv_ty_d1 AS STRING),''), IFNULL(CAST(chkv_ty_d AS STRING),''),
    IFNULL(CAST(chkuv_ty_d1 AS STRING),''), IFNULL(CAST(chkuv_ty_d AS STRING),'')], ','), '\n'
  ORDER BY
    CASE platform WHEN 'ALL' THEN 0 WHEN 'app' THEN 1 WHEN 'app_iOS' THEN 2 WHEN 'app_Android' THEN 3 WHEN 'app_unknown' THEN 4 WHEN 'touch' THEN 5 WHEN 'web' THEN 6 ELSE 7 END,
    CASE traffic WHEN 'ALL' THEN 0 WHEN 'Direct' THEN 1 WHEN 'Non Brand SEM' THEN 2 WHEN 'Brand SEM' THEN 3 WHEN 'SEM PLA' THEN 4 WHEN 'SEM (all)' THEN 5
      WHEN 'SEO' THEN 6 WHEN 'Email' THEN 7 WHEN 'Push Notification' THEN 8 WHEN 'Affiliate' THEN 9 WHEN 'Display' THEN 10 ELSE 11 END)
) AS csv
FROM piv
