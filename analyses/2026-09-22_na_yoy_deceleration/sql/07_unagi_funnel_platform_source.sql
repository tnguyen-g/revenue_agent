-- UNAGI funnel per platform and platform x top traffic source, D-1 vs D,
-- TY vs LY: impressions -> UDV -> orders -> GB -> M1VFM (USD).
-- Feeds tools/yoy_bridge.py chain_bridge (impressions, udv, orders, gb, m1vfm)
-- and data/unagi_funnel_platform_source.csv. ~0.6 GB.
-- UV and buy-button / checkout steps are not in UNAGI; see PLAN.md section 6.

WITH src AS (
  SELECT
    CASE event_date
      WHEN DATE_SUB(DATE '2026-09-22', INTERVAL 1 DAY) THEN 'ty_d1'
      WHEN DATE_SUB(DATE '2026-09-22', INTERVAL 365 DAY) THEN 'ly_d1'
      WHEN DATE '2026-09-22' THEN 'ty_d'
      WHEN DATE_SUB(DATE '2026-09-22', INTERVAL 364 DAY) THEN 'ly_d'
    END AS bucket,
    REGEXP_REPLACE(IFNULL(platform, '(null)'), r'-mbnxt$', '') AS pf,
    IF(traffic_source IN ('Direct', 'Non Brand SEM', 'Brand SEM', 'SEO', 'Email',
                          'Push Notification', 'Affiliate', 'Display'),
       traffic_source, 'Other') AS ts,
    total_impressions AS imp, udvs, orders,
    gross_bookings * fx_rate_loc_to_usd_fxn AS gb,
    margin1_vfm * fx_rate_loc_to_usd_fxn AS m1vfm
  FROM `kbc-grpn-35.out_c_unagi.unagi`
  WHERE event_date IN (
      DATE '2026-09-22',
      DATE_SUB(DATE '2026-09-22', INTERVAL 1 DAY),
      DATE_SUB(DATE '2026-09-22', INTERVAL 364 DAY),
      DATE_SUB(DATE '2026-09-22', INTERVAL 365 DAY))
    AND country IN ('US', 'CA', 'QC')
)

SELECT
  IFNULL(pf, 'ALL') AS platform, IFNULL(ts, 'ALL') AS traffic_source, bucket,
  ROUND(SUM(imp)) AS impressions, ROUND(SUM(udvs)) AS udv, SUM(orders) AS orders,
  ROUND(SUM(gb)) AS gb_usd, ROUND(SUM(m1vfm)) AS m1vfm_usd
FROM src
WHERE pf IN ('app', 'touch', 'web')
GROUP BY GROUPING SETS ((bucket), (pf, bucket), (pf, ts, bucket))
ORDER BY platform, traffic_source, bucket
