-- UNAGI (superfunnel deal datamart): NA traffic, orders, GB and M1VFM by
-- dimension for the D-1 -> D YoY bridge.
--
-- D = 2026-09-22 (Tue), D-1 = 2026-09-21 (Mon), LY = date - 364 (DOW aligned):
-- LY D-1 = 2025-09-22, LY D = 2025-09-23. To rerun for another day replace
-- every 2026-09-22 below; the other three dates are derived from it.
--
-- Source: kbc-grpn-35.out_c_unagi.unagi, the table behind the dataview view
-- prj-grp-dataview-prod-1ff9.supply_unagi.unagi (that view currently denies
-- query access to the FoundryAI BigQuery connector). Partitioned on
-- event_date; ~0.5 GB for four days. Money is local currency -> USD via
-- fx_rate_loc_to_usd_fxn.
--
-- Output columns: dimension, dim_value, {udv,ord,gb,m1vfm}_{ty_d1,ly_d1,ty_d,ly_d}
-- Feed to: python tools/yoy_bridge.py segments out.csv --metric gb
--          python tools/yoy_bridge.py drivers out.csv --traffic udv --orders ord --gb gb --value m1vfm
--
-- Caveat: orders are summed at deal x platform x channel grain, so a parent
-- order spanning several deals counts more than once; reconcile totals to
-- 01_ue_bridge_by_dimension.sql.

WITH src AS (
  SELECT
    CASE event_date
      WHEN DATE_SUB(DATE '2026-09-22', INTERVAL 1 DAY) THEN 'ty_d1'
      WHEN DATE_SUB(DATE '2026-09-22', INTERVAL 365 DAY) THEN 'ly_d1'
      WHEN DATE '2026-09-22' THEN 'ty_d'
      WHEN DATE_SUB(DATE '2026-09-22', INTERVAL 364 DAY) THEN 'ly_d'
    END AS bucket,
    country,
    REGEXP_REPLACE(IFNULL(platform, '(null)'), r'-mbnxt$', '') AS platform_family,
    IFNULL(traffic_source, '(null)') AS traffic_source,
    IFNULL(lob_category, '(null)') AS lob_category,
    IFNULL(grt_l1_cat_name, '(null)') AS grt_l1,
    IFNULL(grt_l2_cat_name, '(null)') AS grt_l2,
    udvs,
    orders,
    gross_bookings * fx_rate_loc_to_usd_fxn AS gb,
    margin1_vfm * fx_rate_loc_to_usd_fxn AS m1vfm
  FROM `kbc-grpn-35.out_c_unagi.unagi`
  WHERE event_date IN (
      DATE '2026-09-22',
      DATE_SUB(DATE '2026-09-22', INTERVAL 1 DAY),
      DATE_SUB(DATE '2026-09-22', INTERVAL 364 DAY),
      DATE_SUB(DATE '2026-09-22', INTERVAL 365 DAY))
    AND country IN ('US', 'CA', 'QC')
),

long AS (
  SELECT bucket, d.dimension, d.dim_value, udvs, orders, gb, m1vfm
  FROM src, UNNEST([
    STRUCT('total' AS dimension, 'TOTAL' AS dim_value),
    STRUCT('country', country),
    STRUCT('platform', platform_family),
    STRUCT('traffic_source', traffic_source),
    STRUCT('lob_category', lob_category),
    STRUCT('grt_l1', grt_l1),
    STRUCT('grt_l2', grt_l2)
  ]) AS d
)

SELECT *
FROM (
  SELECT bucket, dimension, dim_value,
    SUM(udvs) AS udv, SUM(orders) AS ord, SUM(gb) AS gb, SUM(m1vfm) AS m1vfm
  FROM long
  GROUP BY bucket, dimension, dim_value
)
PIVOT (SUM(udv) AS udv, SUM(ord) AS ord, SUM(gb) AS gb, SUM(m1vfm) AS m1vfm
       FOR bucket IN ('ty_d1', 'ly_d1', 'ty_d', 'ly_d'))
ORDER BY dimension, gb_ly_d DESC
