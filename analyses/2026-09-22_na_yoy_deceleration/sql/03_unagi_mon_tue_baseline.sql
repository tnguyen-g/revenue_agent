-- UNAGI: is a Mon -> Tue step normal? TY and LY day-over-day (Tue / Mon) for
-- recent clean Mon/Tue pairs, total and by segment.
--
-- Pairs (TY Mon, TY Tue): 08-10/11, 08-17/18, 08-24/25, 09-14/15, 09-21/22.
-- 08-31/09-01 and 09-07/08 are excluded: Labor Day is LY Mon 2025-09-01 and
-- TY Mon 2026-09-07. LY = date - 364.
--
-- Read: if TY DoD on 09-21/22 is in line with earlier TY pairs, the YoY step
-- comes from the LY base; if TY DoD is well below its own history, TY got
-- weaker.
--
-- Source: kbc-grpn-35.out_c_unagi.unagi (see 02_unagi_bridge_by_dimension.sql).

WITH d AS (
  SELECT
    event_date,
    IF(event_date >= '2026-01-01', 'TY', 'LY') AS yr,
    IF(event_date >= '2026-01-01', event_date, DATE_ADD(event_date, INTERVAL 364 DAY)) AS ty_date,
    IFNULL(lob_category, '(null)') AS lob_category,
    IFNULL(grt_l2_cat_name, '(null)') AS grt_l2,
    REGEXP_REPLACE(IFNULL(platform, '(null)'), r'-mbnxt$', '') AS platform_family,
    IFNULL(traffic_source, '(null)') AS traffic_source,
    udvs, orders,
    gross_bookings * fx_rate_loc_to_usd_fxn AS gb,
    margin1_vfm * fx_rate_loc_to_usd_fxn AS m1vfm
  FROM `kbc-grpn-35.out_c_unagi.unagi`
  WHERE event_date IN (
      '2026-08-10', '2026-08-11', '2026-08-17', '2026-08-18', '2026-08-24', '2026-08-25',
      '2026-09-14', '2026-09-15', '2026-09-21', '2026-09-22',
      '2025-08-11', '2025-08-12', '2025-08-18', '2025-08-19', '2025-08-25', '2025-08-26',
      '2025-09-15', '2025-09-16', '2025-09-22', '2025-09-23')
    AND country IN ('US', 'CA', 'QC')
),

long AS (
  SELECT yr, ty_date, s.dimension, s.dim_value, udvs, orders, gb, m1vfm
  FROM d, UNNEST([
    STRUCT('total' AS dimension, 'TOTAL' AS dim_value),
    STRUCT('lob_category', lob_category),
    STRUCT('grt_l2', grt_l2),
    STRUCT('platform', platform_family),
    STRUCT('traffic_source', traffic_source)
  ]) AS s
),

daily AS (
  SELECT yr, ty_date, dimension, dim_value,
    SUM(udvs) AS udv, SUM(orders) AS ord, SUM(gb) AS gb, SUM(m1vfm) AS m1vfm
  FROM long
  GROUP BY yr, ty_date, dimension, dim_value
)

SELECT
  tue.dimension, tue.dim_value, mon.ty_date AS ty_monday, tue.yr,
  ROUND(SAFE_DIVIDE(tue.udv, mon.udv) - 1, 4) AS udv_dod,
  ROUND(SAFE_DIVIDE(tue.ord, mon.ord) - 1, 4) AS ord_dod,
  ROUND(SAFE_DIVIDE(tue.gb, mon.gb) - 1, 4) AS gb_dod,
  ROUND(SAFE_DIVIDE(tue.m1vfm, mon.m1vfm) - 1, 4) AS m1vfm_dod,
  ROUND(mon.gb) AS gb_mon, ROUND(tue.gb) AS gb_tue
FROM daily AS tue
JOIN daily AS mon
  ON mon.yr = tue.yr AND mon.dimension = tue.dimension AND mon.dim_value = tue.dim_value
 AND mon.ty_date = DATE_SUB(tue.ty_date, INTERVAL 1 DAY)
WHERE FORMAT_DATE('%a', tue.ty_date) = 'Tue'
ORDER BY dimension, dim_value, yr DESC, ty_monday
