-- Promo calendar check: GB, order discount and orders by incentive campaign,
-- D-1 vs D, TY vs LY. This is how the LY base effect is confirmed.
-- 2026-09-22 read: LY Tue 2025-09-23 was an order-discount day (four NA
-- campaigns ran that day only: ~$1.07M GB, ~12.9K orders), e.g.
-- NA_Open_OD_25PCT_HBW_Sep11_bcookie, NA_Open_OD_20PCT_Local_bcookie_SEM,
-- NA_BAU_LegacyCX_HBW_ODday_bcookie,
-- NA_BAU_LegacyCX_baseline_bcookie_ODday_July5_25Pct_Local.

WITH b AS (
  SELECT
    CASE operational_view_date
      WHEN DATE_SUB(DATE '2026-09-22', INTERVAL 1 DAY) THEN 'ty_d1'
      WHEN DATE_SUB(DATE '2026-09-22', INTERVAL 365 DAY) THEN 'ly_d1'
      WHEN DATE '2026-09-22' THEN 'ty_d'
      WHEN DATE_SUB(DATE '2026-09-22', INTERVAL 364 DAY) THEN 'ly_d'
    END AS k,
    IFNULL(incentive_campaign_name, '(no incentive)') AS campaign,
    IF(event_type IN ('capture', 'authorize') AND IFNULL(last_status, '') <> 'cancel', order_id, NULL) AS oid,
    gross_bookings_operational AS gb,
    IFNULL(order_discount_operational, 0) + IFNULL(item_level_sale_operational, 0) AS disc
  FROM `kbc-grpn-35.out_c_ue_location_and_ownership.unit_economics`
  WHERE operational_view_date IN (
      DATE '2026-09-22',
      DATE_SUB(DATE '2026-09-22', INTERVAL 1 DAY),
      DATE_SUB(DATE '2026-09-22', INTERVAL 364 DAY),
      DATE_SUB(DATE '2026-09-22', INTERVAL 365 DAY))
    AND economic_area = 'NA'
)

SELECT campaign,
  ROUND(SUM(IF(k = 'ty_d1', gb, 0))) AS gb_ty_d1, ROUND(SUM(IF(k = 'ly_d1', gb, 0))) AS gb_ly_d1,
  ROUND(SUM(IF(k = 'ty_d', gb, 0))) AS gb_ty_d, ROUND(SUM(IF(k = 'ly_d', gb, 0))) AS gb_ly_d,
  ROUND(SUM(IF(k = 'ty_d1', disc, 0))) AS disc_ty_d1, ROUND(SUM(IF(k = 'ly_d1', disc, 0))) AS disc_ly_d1,
  ROUND(SUM(IF(k = 'ty_d', disc, 0))) AS disc_ty_d, ROUND(SUM(IF(k = 'ly_d', disc, 0))) AS disc_ly_d,
  COUNT(DISTINCT IF(k = 'ty_d1', oid, NULL)) AS ord_ty_d1, COUNT(DISTINCT IF(k = 'ly_d1', oid, NULL)) AS ord_ly_d1,
  COUNT(DISTINCT IF(k = 'ty_d', oid, NULL)) AS ord_ty_d, COUNT(DISTINCT IF(k = 'ly_d', oid, NULL)) AS ord_ly_d
FROM b
GROUP BY campaign
ORDER BY GREATEST(ABS(SUM(IF(k = 'ty_d', gb, 0))), ABS(SUM(IF(k = 'ly_d', gb, 0))),
                  ABS(SUM(IF(k = 'ty_d1', gb, 0))), ABS(SUM(IF(k = 'ly_d1', gb, 0)))) DESC
LIMIT 40
