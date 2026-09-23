-- Unit economics: NA GB, GR, M1VFM, OD+ILS and orders by dimension for the
-- D-1 -> D YoY bridge. This is the finance source of truth for the bridge;
-- UNAGI (02) adds traffic.
--
-- D = 2026-09-22 (Tue), D-1 = 2026-09-21 (Mon), LY = date - 364. To rerun for
-- another day replace every 2026-09-22 below.
--
-- Source: kbc-grpn-35.out_c_ue_location_and_ownership.unit_economics, the
-- table behind prj-grp-dataview-prod-1ff9.finance_unit_economics.unit_economics
-- (the view denies query access to the FoundryAI connector). Partitioned on
-- operational_view_date; ~60 MB for four days.
--
-- Rules (validated against order_economics, and M1VFM for 2026-09-21 matches
-- the Daily Monitoring doc, +5.5% vs +5.4%):
--   * *_operational columns (booking-date view), local currency; NA is ~USD
--     (CA is ~$2K/day). Use fx_rate_loc_to_usd_fxn if exact USD is needed.
--   * GB/GR/M1/VFM: sum over all event types (cancel rows net out cancelled
--     authorizations; refund rows carry 0 GB).
--   * Orders: distinct order_id where event_type in (capture, authorize) and
--     last_status <> 'cancel'.
--   * M1VFM = margin_1_operational + vfm_operational.
--   * Platform names gained a -mbnxt suffix this year; group into families.
--
-- Output: dimension, dim_value, {gb,gr,m1vfm,disc,ord}_{ty_d1,ly_d1,ty_d,ly_d}
-- Feed to: python tools/yoy_bridge.py segments out.csv --metric m1vfm

WITH base AS (
  SELECT
    CASE operational_view_date
      WHEN DATE_SUB(DATE '2026-09-22', INTERVAL 1 DAY) THEN 'ty_d1'
      WHEN DATE_SUB(DATE '2026-09-22', INTERVAL 365 DAY) THEN 'ly_d1'
      WHEN DATE '2026-09-22' THEN 'ty_d'
      WHEN DATE_SUB(DATE '2026-09-22', INTERVAL 364 DAY) THEN 'ly_d'
    END AS k,
    IF(event_type IN ('capture', 'authorize') AND IFNULL(last_status, '') <> 'cancel', order_id, NULL) AS oid,
    gross_bookings_operational AS gb,
    gross_revenue_operational AS gr,
    IFNULL(margin_1_operational, 0) + IFNULL(vfm_operational, 0) AS m1vfm,
    IFNULL(order_discount_operational, 0) + IFNULL(item_level_sale_operational, 0) AS disc,
    feature_country,
    LOB_category,
    grt_l1_cat_name,
    grt_l2_cat_name,
    REGEXP_REPLACE(IFNULL(platform, '(null)'), r'-mbnxt$', '') AS platform_family,
    traffic_source,
    CASE WHEN is_activation THEN 'new (activation)' WHEN is_reactivation THEN 'reactivation'
         ELSE 'existing' END AS customer_type,
    IF(incentive_id IS NOT NULL, 'promo', 'no promo') AS promo_flag
  FROM `kbc-grpn-35.out_c_ue_location_and_ownership.unit_economics`
  WHERE operational_view_date IN (
      DATE '2026-09-22',
      DATE_SUB(DATE '2026-09-22', INTERVAL 1 DAY),
      DATE_SUB(DATE '2026-09-22', INTERVAL 364 DAY),
      DATE_SUB(DATE '2026-09-22', INTERVAL 365 DAY))
    AND economic_area = 'NA'
),

long AS (
  SELECT k, s.dimension, IFNULL(s.dim_value, '(null)') AS dim_value, oid, gb, gr, m1vfm, disc
  FROM base, UNNEST([
    STRUCT('total' AS dimension, 'TOTAL' AS dim_value),
    STRUCT('country', feature_country),
    STRUCT('lob_category', LOB_category),
    STRUCT('grt_l1', grt_l1_cat_name),
    STRUCT('grt_l2', grt_l2_cat_name),
    STRUCT('platform', platform_family),
    STRUCT('traffic_source', traffic_source),
    STRUCT('customer_type', customer_type),
    STRUCT('promo_flag', promo_flag)
  ]) AS s
)

SELECT
  dimension, dim_value,
  SUM(IF(k = 'ty_d1', gb, 0)) AS gb_ty_d1, SUM(IF(k = 'ly_d1', gb, 0)) AS gb_ly_d1,
  SUM(IF(k = 'ty_d', gb, 0)) AS gb_ty_d, SUM(IF(k = 'ly_d', gb, 0)) AS gb_ly_d,
  SUM(IF(k = 'ty_d1', gr, 0)) AS gr_ty_d1, SUM(IF(k = 'ly_d1', gr, 0)) AS gr_ly_d1,
  SUM(IF(k = 'ty_d', gr, 0)) AS gr_ty_d, SUM(IF(k = 'ly_d', gr, 0)) AS gr_ly_d,
  SUM(IF(k = 'ty_d1', m1vfm, 0)) AS m1vfm_ty_d1, SUM(IF(k = 'ly_d1', m1vfm, 0)) AS m1vfm_ly_d1,
  SUM(IF(k = 'ty_d', m1vfm, 0)) AS m1vfm_ty_d, SUM(IF(k = 'ly_d', m1vfm, 0)) AS m1vfm_ly_d,
  SUM(IF(k = 'ty_d1', disc, 0)) AS disc_ty_d1, SUM(IF(k = 'ly_d1', disc, 0)) AS disc_ly_d1,
  SUM(IF(k = 'ty_d', disc, 0)) AS disc_ty_d, SUM(IF(k = 'ly_d', disc, 0)) AS disc_ly_d,
  COUNT(DISTINCT IF(k = 'ty_d1', oid, NULL)) AS ord_ty_d1, COUNT(DISTINCT IF(k = 'ly_d1', oid, NULL)) AS ord_ly_d1,
  COUNT(DISTINCT IF(k = 'ty_d', oid, NULL)) AS ord_ty_d, COUNT(DISTINCT IF(k = 'ly_d', oid, NULL)) AS ord_ly_d
FROM long
GROUP BY dimension, dim_value
ORDER BY dimension, gb_ly_d DESC
