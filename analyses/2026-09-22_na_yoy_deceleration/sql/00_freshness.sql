-- Freshness gate: run before any bridge. D must be complete in both sources.
-- UE lands ~04:10 UTC (T+1); UNAGI ~06:25 UTC (T+1). On 2026-09-23 at 05:51
-- UTC the UNAGI D partition was still partial (336K of ~1.7M rows), so do not
-- read D from UNAGI before ~06:30 UTC.
-- Healthy: D row counts in line with D-1 and the same weekday last week.
-- Also check pending authorizations: GB still in authorize status on D can
-- move D's YoY once it resolves (2026-09-22: $36K, ~1.1pp).

SELECT 'unit_economics' AS source, operational_view_date AS d, COUNT(*) AS n_rows,
  ROUND(SUM(gross_bookings_operational)) AS gb,
  ROUND(SUM(IF(event_type = 'authorize' AND IFNULL(last_status, '') <> 'cancel', gross_bookings_operational, 0))) AS gb_pending_auth,
  MAX(operational_view_timestamp) AS max_event_ts
FROM `kbc-grpn-35.out_c_ue_location_and_ownership.unit_economics`
WHERE operational_view_date BETWEEN DATE_SUB(DATE '2026-09-22', INTERVAL 7 DAY) AND DATE '2026-09-22'
  AND economic_area = 'NA'
GROUP BY d

UNION ALL

SELECT 'unagi', event_date, COUNT(*), ROUND(SUM(gross_bookings * fx_rate_loc_to_usd_fxn)), NULL, NULL
FROM `kbc-grpn-35.out_c_unagi.unagi`
WHERE event_date BETWEEN DATE_SUB(DATE '2026-09-22', INTERVAL 7 DAY) AND DATE '2026-09-22'
  AND country IN ('US', 'CA', 'QC')
GROUP BY event_date

ORDER BY source, d
