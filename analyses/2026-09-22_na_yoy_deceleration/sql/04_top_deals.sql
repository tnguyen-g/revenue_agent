-- Deal level: which deals moved the YoY gap most from D-1 to D, and which LY
-- D top sellers are missing TY (lapping / supply loss). UNAGI, NA, USD.
-- 2026-09-22: broad-based, no single deal above +/- $9.4K of the -$314K swing.
-- Swap the ORDER BY for ly_gb_d DESC to list the biggest LY D deals instead.

WITH d AS (
  SELECT
    deal_uuid,
    ANY_VALUE(deal_permalink) AS deal_permalink,
    ANY_VALUE(merchant_uuid) AS merchant_uuid,
    ANY_VALUE(lob_category) AS lob_category,
    ANY_VALUE(grt_l2_cat_name) AS grt_l2,
    SUM(IF(event_date = DATE_SUB(DATE '2026-09-22', INTERVAL 1 DAY), udvs, 0)) AS udv_ty_d1,
    SUM(IF(event_date = DATE_SUB(DATE '2026-09-22', INTERVAL 365 DAY), udvs, 0)) AS udv_ly_d1,
    SUM(IF(event_date = DATE '2026-09-22', udvs, 0)) AS udv_ty_d,
    SUM(IF(event_date = DATE_SUB(DATE '2026-09-22', INTERVAL 364 DAY), udvs, 0)) AS udv_ly_d,
    SUM(IF(event_date = DATE_SUB(DATE '2026-09-22', INTERVAL 1 DAY), orders, 0)) AS ord_ty_d1,
    SUM(IF(event_date = DATE_SUB(DATE '2026-09-22', INTERVAL 365 DAY), orders, 0)) AS ord_ly_d1,
    SUM(IF(event_date = DATE '2026-09-22', orders, 0)) AS ord_ty_d,
    SUM(IF(event_date = DATE_SUB(DATE '2026-09-22', INTERVAL 364 DAY), orders, 0)) AS ord_ly_d,
    SUM(IF(event_date = DATE_SUB(DATE '2026-09-22', INTERVAL 1 DAY), gross_bookings * fx_rate_loc_to_usd_fxn, 0)) AS gb_ty_d1,
    SUM(IF(event_date = DATE_SUB(DATE '2026-09-22', INTERVAL 365 DAY), gross_bookings * fx_rate_loc_to_usd_fxn, 0)) AS gb_ly_d1,
    SUM(IF(event_date = DATE '2026-09-22', gross_bookings * fx_rate_loc_to_usd_fxn, 0)) AS gb_ty_d,
    SUM(IF(event_date = DATE_SUB(DATE '2026-09-22', INTERVAL 364 DAY), gross_bookings * fx_rate_loc_to_usd_fxn, 0)) AS gb_ly_d
  FROM `kbc-grpn-35.out_c_unagi.unagi`
  WHERE event_date IN (
      DATE '2026-09-22',
      DATE_SUB(DATE '2026-09-22', INTERVAL 1 DAY),
      DATE_SUB(DATE '2026-09-22', INTERVAL 364 DAY),
      DATE_SUB(DATE '2026-09-22', INTERVAL 365 DAY))
    AND country IN ('US', 'CA', 'QC')
  GROUP BY deal_uuid
)

SELECT *,
  ROUND((gb_ty_d - gb_ly_d) - (gb_ty_d1 - gb_ly_d1)) AS chg_yoy_gb_gap,
  (udv_ty_d - udv_ly_d) - (udv_ty_d1 - udv_ly_d1) AS chg_yoy_udv_gap,
  (ord_ty_d - ord_ly_d) - (ord_ty_d1 - ord_ly_d1) AS chg_yoy_ord_gap
FROM d
ORDER BY ABS((gb_ty_d - gb_ly_d) - (gb_ty_d1 - gb_ly_d1)) DESC
LIMIT 50
