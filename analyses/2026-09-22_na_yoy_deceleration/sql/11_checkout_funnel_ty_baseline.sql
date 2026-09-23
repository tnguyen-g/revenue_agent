-- TY checkout funnel per platform / OS for D-1 -> D and the four previous
-- clean Mon/Tue pairs, so each step's Tue/Mon change can be compared with
-- its normal:
--   UDV -> buy-button clicks -> checkout views -> Janus dealPurchase
--   -> UE orders (authorized, not cancelled)
-- LY is not available for the click/checkout steps (Janus retention starts
-- 2026-07-16), so this is a TY-vs-normal read only.
--
-- Sources:
--   kbc-grpn-28.in_c_tr_level_02_gpr_traffic_l1.agg_gbl_traffic_l1 (UDV; unpartitioned, ~0.6 GB)
--   kbc-grpn-28.janus_impressions.junoHourly (external; dry run shows 0 B, ~0.2 GB/day actual)
--   kbc-grpn-35.out_c_ue_location_and_ownership.unit_economics (orders)
-- Platform: app = Janus platform 'mobile' (iOS = iPhone/iPad, Android);
-- touch = clientPlatform 'Touch'; web = the rest. Bots excluded.

WITH days AS (
  SELECT d FROM UNNEST([
    DATE '2026-08-10', DATE '2026-08-11', DATE '2026-08-17', DATE '2026-08-18',
    DATE '2026-08-24', DATE '2026-08-25', DATE '2026-09-14', DATE '2026-09-15',
    DATE '2026-09-21', DATE '2026-09-22']) AS d
),

udv AS (
  SELECT t.report_date AS d,
    CASE WHEN STARTS_WITH(LOWER(t.platform), 'app') THEN
           CASE WHEN STARTS_WITH(LOWER(t.sub_platform), 'iphone') OR STARTS_WITH(LOWER(t.sub_platform), 'ipad') THEN 'app_iOS'
                WHEN STARTS_WITH(LOWER(t.sub_platform), 'android') THEN 'app_Android' ELSE 'app_other' END
         WHEN STARTS_WITH(LOWER(t.platform), 'touch') THEN 'touch'
         WHEN STARTS_WITH(LOWER(t.platform), 'web') THEN 'web' ELSE 'other' END AS seg,
    SUM(t.uniq_deal_views) AS udv
  FROM `kbc-grpn-28.in_c_tr_level_02_gpr_traffic_l1.agg_gbl_traffic_l1` AS t
  WHERE t.report_date IN ('2026-08-10', '2026-08-11', '2026-08-17', '2026-08-18', '2026-08-24',
                                   '2026-08-25', '2026-09-14', '2026-09-15', '2026-09-21', '2026-09-22')
    AND t.economic_area = 'NA'
  GROUP BY d, seg
),

jan AS (
  SELECT PARSE_DATE('%Y-%m-%d', j.eventDate) AS d,
    CASE WHEN j.platform = 'mobile' THEN
           CASE WHEN j.clientPlatform IN ('iPhone', 'iPad') THEN 'app_iOS'
                WHEN j.clientPlatform = 'Android' THEN 'app_Android' ELSE 'app_other' END
         WHEN j.clientPlatform = 'Touch' THEN 'touch' ELSE 'web' END AS seg,
    COUNTIF(j.event = 'buyButtonClick') AS bbc,
    COUNTIF(j.event = 'checkoutView') AS chkv,
    COUNTIF(j.event = 'dealPurchase') AS purch
  FROM `kbc-grpn-28.janus_impressions.junoHourly` AS j
  WHERE j.eventDate IN ('2026-08-10', '2026-08-11', '2026-08-17', '2026-08-18', '2026-08-24',
                        '2026-08-25', '2026-09-14', '2026-09-15', '2026-09-21', '2026-09-22')
    AND j.eventDestination = 'purchaseFunnel'
    AND j.platform IN ('web', 'mobile')
    AND j.event IN ('buyButtonClick', 'checkoutView', 'dealPurchase')
    AND j.country IN ('US', 'CA')
    AND IFNULL(j.isBot, 'false') <> 'true'
  GROUP BY d, seg
),

ord AS (
  SELECT u.operational_view_date AS d,
    CASE WHEN STARTS_WITH(LOWER(u.platform), 'app') THEN
           CASE WHEN STARTS_WITH(LOWER(u.sub_platform), 'iphone') OR STARTS_WITH(LOWER(u.sub_platform), 'ipad') THEN 'app_iOS'
                WHEN STARTS_WITH(LOWER(u.sub_platform), 'android') THEN 'app_Android' ELSE 'app_other' END
         WHEN STARTS_WITH(LOWER(u.platform), 'touch') THEN 'touch'
         WHEN STARTS_WITH(LOWER(u.platform), 'web') THEN 'web' ELSE 'other' END AS seg,
    COUNT(DISTINCT u.parent_order_uuid) AS orders
  FROM `kbc-grpn-35.out_c_ue_location_and_ownership.unit_economics` AS u
  -- literal dates, not a subquery, so partitions are pruned
  WHERE u.operational_view_date IN ('2026-08-10', '2026-08-11', '2026-08-17', '2026-08-18', '2026-08-24',
                                   '2026-08-25', '2026-09-14', '2026-09-15', '2026-09-21', '2026-09-22')
    AND u.economic_area = 'NA'
    AND u.event_type IN ('authorize', 'capture') AND IFNULL(u.last_status, '') <> 'cancel'
  GROUP BY d, seg
)

SELECT days.d, s.seg, udv.udv, jan.bbc, jan.chkv, jan.purch, ord.orders
FROM days
CROSS JOIN (SELECT seg FROM UNNEST(['app_iOS', 'app_Android', 'touch', 'web']) AS seg) AS s
LEFT JOIN udv ON udv.d = days.d AND udv.seg = s.seg
LEFT JOIN jan ON jan.d = days.d AND jan.seg = s.seg
LEFT JOIN ord ON ord.d = days.d AND ord.seg = s.seg
ORDER BY s.seg, days.d
