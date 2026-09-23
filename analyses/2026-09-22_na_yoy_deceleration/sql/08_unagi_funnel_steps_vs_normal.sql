-- Funnel steps vs normal, per platform and platform x traffic source (UNAGI).
--
-- For each cell and funnel step
--   impressions -> UDV/impressions (CTR) -> orders/UDV (CVR) -> GB/order (AOV)
--   -> M1VFM/GB (margin)
-- this compares the Tue/Mon change of D (2026-09-22 vs 09-21) with its normal,
-- the median of the four previous clean Mon/Tue pairs (Labor Day weeks
-- excluded). It does this for TY and for LY (date - 364).
--
-- Per step it returns, in log points (x100 ~ %):
--   ty_act, ty_norm, ly_act, ly_norm
-- and in bps of the NA M1VFM day-to-day YoY change:
--   ty_abn_bps  TY weaker (-) or stronger (+) than its normal
--   ly_abn_bps  LY base effect (-) = LY spiked more than normal
--   seas_bps    normal DOW drift (TY normal - LY normal)
-- Per cell, all steps and parts sum to the cell's log change in M1VFM YoY.
-- The bps use a linear scale (cell M1VFM on D / NA LY M1VFM on D), so they
-- are approximate; dc_bps_exact is the cell's exact change in contribution.
--
-- Source: kbc-grpn-35.out_c_unagi.unagi. ~3 GB scan.

WITH d AS (
  SELECT
    IF(event_date >= '2026-01-01', 'TY', 'LY') AS yr,
    IF(event_date >= '2026-01-01', event_date, DATE_ADD(event_date, INTERVAL 364 DAY)) AS ty_date,
    REGEXP_REPLACE(IFNULL(platform, '(null)'), r'-mbnxt$', '') AS pf,
    IF(traffic_source IN ('Direct', 'Non Brand SEM', 'Brand SEM', 'SEO', 'Email',
                          'Push Notification', 'Affiliate', 'Display'),
       traffic_source, 'Other') AS ts,
    total_impressions AS imp, udvs AS udv, orders AS ord,
    gross_bookings * fx_rate_loc_to_usd_fxn AS gb,
    margin1_vfm * fx_rate_loc_to_usd_fxn AS m1
  FROM `kbc-grpn-35.out_c_unagi.unagi`
  WHERE event_date IN (
      '2026-08-10', '2026-08-11', '2026-08-17', '2026-08-18', '2026-08-24', '2026-08-25',
      '2026-09-14', '2026-09-15', '2026-09-21', '2026-09-22',
      '2025-08-11', '2025-08-12', '2025-08-18', '2025-08-19', '2025-08-25', '2025-08-26',
      '2025-09-15', '2025-09-16', '2025-09-22', '2025-09-23')
    AND country IN ('US', 'CA', 'QC')
    AND REGEXP_REPLACE(IFNULL(platform, '(null)'), r'-mbnxt$', '') IN ('app', 'touch', 'web')
),

daily AS (
  SELECT yr, ty_date, IFNULL(pf, 'ALL') AS seg_pf, IFNULL(ts, 'ALL') AS seg_ts,
    SUM(imp) AS imp, SUM(udv) AS udv, SUM(ord) AS ord, SUM(gb) AS gb, SUM(m1) AS m1
  FROM d
  GROUP BY GROUPING SETS ((yr, ty_date), (yr, ty_date, pf), (yr, ty_date, pf, ts))
),

-- Tue/Mon log ratio of each funnel step, per cell, year and pair.
pairs AS (
  SELECT t.seg_pf, t.seg_ts, t.yr, m.ty_date AS mon,
    SAFE.LN(SAFE_DIVIDE(t.imp, m.imp)) AS l_imp,
    SAFE.LN(SAFE_DIVIDE(SAFE_DIVIDE(t.udv, t.imp), SAFE_DIVIDE(m.udv, m.imp))) AS l_ctr,
    SAFE.LN(SAFE_DIVIDE(SAFE_DIVIDE(t.ord, t.udv), SAFE_DIVIDE(m.ord, m.udv))) AS l_cvr,
    SAFE.LN(SAFE_DIVIDE(SAFE_DIVIDE(t.gb, t.ord), SAFE_DIVIDE(m.gb, m.ord))) AS l_aov,
    SAFE.LN(SAFE_DIVIDE(SAFE_DIVIDE(t.m1, t.gb), SAFE_DIVIDE(m.m1, m.gb))) AS l_mrg,
    m.m1 AS m1_mon, t.m1 AS m1_tue
  FROM daily AS t
  JOIN daily AS m
    ON m.seg_pf = t.seg_pf AND m.seg_ts = t.seg_ts AND m.yr = t.yr
   AND m.ty_date = DATE_SUB(t.ty_date, INTERVAL 1 DAY)
  WHERE FORMAT_DATE('%a', t.ty_date) = 'Tue'
),

long AS (
  SELECT seg_pf, seg_ts, yr, mon, s.step, s.l, m1_mon, m1_tue
  FROM pairs, UNNEST([
    STRUCT('1 impressions' AS step, l_imp AS l),
    STRUCT('2 UDV/imp (CTR)', l_ctr),
    STRUCT('3 orders/UDV (CVR)', l_cvr),
    STRUCT('4 GB/order (AOV)', l_aov),
    STRUCT('5 M1VFM/GB (margin)', l_mrg)
  ]) AS s
),

stats AS (
  SELECT seg_pf, seg_ts, step,
    MAX(IF(yr = 'TY' AND mon = '2026-09-21', l, NULL)) AS ty_act,
    MAX(IF(yr = 'LY' AND mon = '2026-09-21', l, NULL)) AS ly_act,
    ARRAY_AGG(IF(yr = 'TY' AND mon <> '2026-09-21', l, NULL) IGNORE NULLS ORDER BY l) AS ty_hist,
    ARRAY_AGG(IF(yr = 'LY' AND mon <> '2026-09-21', l, NULL) IGNORE NULLS ORDER BY l) AS ly_hist,
    -- M1VFM levels on D-1 (Mon) and D (Tue) for TY and LY
    MAX(IF(yr = 'TY' AND mon = '2026-09-21', m1_mon, NULL)) AS ty_d1,
    MAX(IF(yr = 'TY' AND mon = '2026-09-21', m1_tue, NULL)) AS ty_d,
    MAX(IF(yr = 'LY' AND mon = '2026-09-21', m1_mon, NULL)) AS ly_d1,
    MAX(IF(yr = 'LY' AND mon = '2026-09-21', m1_tue, NULL)) AS ly_d
  FROM long
  GROUP BY seg_pf, seg_ts, step
),

med AS (
  SELECT *,
    (ty_hist[SAFE_OFFSET(DIV(ARRAY_LENGTH(ty_hist) - 1, 2))]
      + ty_hist[SAFE_OFFSET(DIV(ARRAY_LENGTH(ty_hist), 2))]) / 2 AS ty_norm,
    (ly_hist[SAFE_OFFSET(DIV(ARRAY_LENGTH(ly_hist) - 1, 2))]
      + ly_hist[SAFE_OFFSET(DIV(ARRAY_LENGTH(ly_hist), 2))]) / 2 AS ly_norm
  FROM stats
),

na AS (
  SELECT ly_d1 AS na_ly_d1, ly_d AS na_ly_d
  FROM stats WHERE seg_pf = 'ALL' AND seg_ts = 'ALL' AND step = '1 impressions'
)

SELECT
  seg_pf, seg_ts, step,
  ROUND(100 * ty_act, 1) AS ty_act, ROUND(100 * ty_norm, 1) AS ty_norm,
  ROUND(100 * ly_act, 1) AS ly_act, ROUND(100 * ly_norm, 1) AS ly_norm,
  -- linear scale: d(contribution on D) / d(log TY_D) = TY_D / NA LY_D, and
  -- -LY_D / NA LY_D for log LY_D
  ROUND(1e4 * (ty_act - ty_norm) * ty_d / na_ly_d) AS ty_abn_bps,
  ROUND(1e4 * -(ly_act - ly_norm) * ly_d / na_ly_d) AS ly_abn_bps,
  ROUND(1e4 * (ty_norm * ty_d - ly_norm * ly_d) / na_ly_d) AS seas_bps,
  ROUND(1e4 * ((ty_d - ly_d) / na_ly_d - (ty_d1 - ly_d1) / na_ly_d1)) AS dc_bps_exact
FROM med CROSS JOIN na
ORDER BY seg_pf = 'ALL' DESC, seg_ts = 'ALL' DESC, seg_pf, seg_ts, step
