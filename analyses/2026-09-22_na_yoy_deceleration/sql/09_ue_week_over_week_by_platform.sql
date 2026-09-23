-- Unit economics, NA: daily orders, GB and M1VFM by platform family for the
-- D-8..D window TY and the aligned LY window. Separates "TY Tuesday weak"
-- from "TY Monday hot" and "LY comp strong" with week-over-week reads
-- (Tue D vs Tue D-7, Mon D-1 vs Mon D-8), TY and LY.
-- 2026-09-22 read: TY Tue +1.5% orders / +1.0% M1VFM WoW (not weak); LY Mon
-- -7.1% orders WoW (weak comp) and LY Tue +7.9% M1VFM WoW (OD day).
-- Output feeds data/ue_daily_by_platform.csv. ~160 MB.

WITH b AS (
  SELECT
    operational_view_date AS d,
    IF(REGEXP_REPLACE(IFNULL(platform, '(null)'), r'-mbnxt$', '') IN ('app', 'touch', 'web'),
       REGEXP_REPLACE(platform, r'-mbnxt$', ''), 'other') AS pf,
    IF(event_type IN ('capture', 'authorize') AND IFNULL(last_status, '') <> 'cancel', order_id, NULL) AS oid,
    gross_bookings_operational AS gb,
    IFNULL(margin_1_operational, 0) + IFNULL(vfm_operational, 0) AS m1vfm
  FROM `kbc-grpn-35.out_c_ue_location_and_ownership.unit_economics`
  WHERE (operational_view_date BETWEEN DATE_SUB(DATE '2026-09-22', INTERVAL 8 DAY) AND DATE '2026-09-22'
      OR operational_view_date BETWEEN DATE_SUB(DATE '2026-09-22', INTERVAL 372 DAY)
                                   AND DATE_SUB(DATE '2026-09-22', INTERVAL 364 DAY))
    AND economic_area = 'NA'
)

SELECT * FROM (
  -- ALL includes the "other" platforms; only their own row is dropped
  SELECT IFNULL(pf, 'ALL') AS platform, d AS date,
    COUNT(DISTINCT oid) AS orders, ROUND(SUM(gb)) AS gb, ROUND(SUM(m1vfm)) AS m1vfm
  FROM b
  GROUP BY GROUPING SETS ((d), (d, pf))
)
WHERE platform <> 'other'
ORDER BY platform, date
