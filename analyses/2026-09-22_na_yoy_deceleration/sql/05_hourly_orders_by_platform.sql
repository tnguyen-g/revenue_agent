-- Hourly NA orders by platform family, D-1 vs D, TY vs LY. Used to test
-- incident windows (JPROD-969 Orders Index API 404s, 2026-09-22 11:42-15:10
-- UTC) and platform-specific checkout issues (JPROD-955 reCAPTCHA).
-- operational_view_timestamp is UTC; the operational day looks UTC-based
-- (order trough at 07-10 UTC = US night).
-- 2026-09-22 read: app/touch TY Tue/Mon -9% to -17% through all US daytime
-- hours (12-23 UTC), web flat; the JPROD-969 window is only ~1.4pp worse than
-- the hours after it -> not the main driver.

WITH b AS (
  SELECT
    CASE operational_view_date
      WHEN DATE_SUB(DATE '2026-09-22', INTERVAL 1 DAY) THEN 'ty_d1'
      WHEN DATE_SUB(DATE '2026-09-22', INTERVAL 365 DAY) THEN 'ly_d1'
      WHEN DATE '2026-09-22' THEN 'ty_d'
      WHEN DATE_SUB(DATE '2026-09-22', INTERVAL 364 DAY) THEN 'ly_d'
    END AS k,
    EXTRACT(HOUR FROM operational_view_timestamp) AS hour_utc,
    REGEXP_REPLACE(IFNULL(platform, '(null)'), r'-mbnxt$', '') AS platform_family,
    IF(event_type IN ('capture', 'authorize') AND IFNULL(last_status, '') <> 'cancel', order_id, NULL) AS oid,
    gross_bookings_operational AS gb
  FROM `kbc-grpn-35.out_c_ue_location_and_ownership.unit_economics`
  WHERE operational_view_date IN (
      DATE '2026-09-22',
      DATE_SUB(DATE '2026-09-22', INTERVAL 1 DAY),
      DATE_SUB(DATE '2026-09-22', INTERVAL 364 DAY),
      DATE_SUB(DATE '2026-09-22', INTERVAL 365 DAY))
    AND economic_area = 'NA'
)

SELECT platform_family, hour_utc,
  COUNT(DISTINCT IF(k = 'ty_d1', oid, NULL)) AS ord_ty_d1,
  COUNT(DISTINCT IF(k = 'ly_d1', oid, NULL)) AS ord_ly_d1,
  COUNT(DISTINCT IF(k = 'ty_d', oid, NULL)) AS ord_ty_d,
  COUNT(DISTINCT IF(k = 'ly_d', oid, NULL)) AS ord_ly_d,
  ROUND(SUM(IF(k = 'ty_d1', gb, 0))) AS gb_ty_d1,
  ROUND(SUM(IF(k = 'ly_d1', gb, 0))) AS gb_ly_d1,
  ROUND(SUM(IF(k = 'ty_d', gb, 0))) AS gb_ty_d,
  ROUND(SUM(IF(k = 'ly_d', gb, 0))) AS gb_ly_d
FROM b
GROUP BY platform_family, hour_utc
ORDER BY platform_family, hour_utc
