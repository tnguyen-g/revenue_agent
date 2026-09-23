# NA YoY deceleration, Tue 2026-09-22: investigation plan

**Question.** NA YoY stepped down from Mon 9/21 to Tue 9/22. What drove that
day-to-day (DtD) deceleration? Is it a real TY problem or an LY base effect,
and what are the outcomes and follow-ups?

**Status.** As of 2026-09-23 06:30 UTC, the first-pass bridge is done on
unit economics (UE) and UNAGI (section 1). The 10:00 CEST stand-up reviews
9/22 today. The open items are in [FOLLOWUPS.md](FOLLOWUPS.md).

**Conventions.**
- D = Tue 2026-09-22 and D-1 = Mon 2026-09-21.
- LY is date − 364, so the LY days are Tue 2025-09-23 and Mon 2025-09-22.
- DtD is YoY(D) − YoY(D-1), in bps, as in the Daily Monitoring doc.

---

## 1. First-pass read (validate before the stand-up)

| NA metric | YoY Mon 9/21 | YoY Tue 9/22 | DtD |
|---|---:|---:|---:|
| M1VFM (UE, M1 + VFM) | +5.5% | −2.6% | **−806 bps** |
| Gross bookings (UE) | +13.0% | +1.9% | **−1,110 bps** |
| Orders (UE) | +1.5% | −13.2% | −1,467 bps |
| UDVs (UNAGI) | −2.6% | −9.1% | −645 bps |
| GB (Finance Tracker, cross-check) | +11.5% | +3.6% | −787 bps |

The UE figures for 9/21 match the Daily Monitoring doc: M1VFM +5.5% here vs
+5.4% in the doc, and GB +13.0% vs +13%. UNAGI ties to UE within about 0.6%
on GB and M1VFM.

### 1a. Base effect vs TY: the headline answer

Split of each metric's DtD. "Normal" is the median Tue/Mon change of the four
previous clean Mon/Tue pairs, excluding the Labor Day weeks.

| Metric (UNAGI) | TY Tue/Mon | TY normal | LY Tue/Mon | LY normal | LY base effect | TY weaker than normal | Seasonality |
|---|---:|---:|---:|---:|---:|---:|---:|
| GB | +0.1% | −0.6% | **+11.1%** | −1.2% | **−12.7pp** | +0.8pp | +0.7pp |
| M1VFM | −3.5% | −1.4% | +4.5% | −0.8% | **−5.3pp** | **−2.1pp** | −0.7pp |
| Orders | −6.5% | −1.6% | +9.1% | −2.0% | **−10.0pp** | **−4.8pp** | +0.3pp |

**The LY base effect.** Both years ran an ILS-stack Monday followed by an
order-discount Tuesday. LY's Tuesday discount push was about 2.2× bigger than
TY's:
- **LY Tue 2025-09-23:** ~$1.07M GB and ~12.9K orders across four OD campaigns.
  - NA_Open_OD_25PCT_HBW_Sep11: $443K
  - NA_Open_OD_20PCT_Local_bcookie_SEM: $301K
  - NA_BAU_LegacyCX_HBW_ODday: $189K
  - NA_BAU_LegacyCX_…ODday_July5_25Pct_Local: $140K
- **TY Tue 2026-09-22:** ~$0.49M GB across three OD campaigns.
  - Travel EOQ 10% OD: $204K
  - Local 20% OD SEM Q3: $198K
  - Paid OD MinMargin10: $86K

*Source: sql/06_promo_campaigns.sql.*

**The TY part is real but smaller.** It is about −2.1pp of M1VFM (≈ −$15K
M1VFM on the day) and −4.8pp of orders (≈ −1.9K orders). Travel's big
tickets hide it in GB.

### 1b. Driver bridge (UNAGI, NA)

| Driver | YoY D-1 → D | Share of GB DtD | Share of M1VFM DtD |
|---|---|---:|---:|
| Traffic (UDV) | −2.6% → −9.1% | −737 bps | −697 bps |
| CVR (orders / UDV) | +4.1% → −4.4% | −916 bps | −866 bps |
| AOV (GB / order) | +11.7% → +17.4% | +538 bps | +508 bps |
| Margin (M1VFM / GB) | −6.6% → −4.4% | – | +242 bps |

### 1c. Where it sits

GB DtD by segment comes from the UNAGI segment bridge (sql/02). The TY
columns compare Tue/Mon with that segment's own normal (sql/03).

| Segment | GB DtD | M1VFM DtD | TY orders Tue/Mon (normal) | LY GB Tue/Mon (normal) | Read |
|---|---:|---:|---:|---:|---|
| Core Local | −1,023 bps | −599 bps | −5.6% (+1.7%) | +17.5% (+0.4%) | LY OD day plus TY softer |
| – HBW (L2) | −697 bps | −398 bps | +1.0% (+3.9%) | +21.8% (+1.2%) | mostly LY OD day (25% HBW OD) |
| – TTD Leisure (L2) | −594 bps | −351 bps | **−18.9% (−4.8%)** | +8.8% (−1.9%) | **TY-specific drop** plus LY |
| National / Enterprise | −411 bps | −274 bps | −10.3% (−6.1%) | +3.1% (−4.6%) | mostly LY |
| Travel | **+311 bps** | +46 bps | +28.4% (+0.8%) | −9.4% (+4.0%) | TY EOQ Travel OD |
| app | −807 bps | −578 bps | −5.9% (−2.7%) | +14.5% (−1.7%) | mostly LY |
| touch (mobile web) | −352 bps | −267 bps | **−12.1% (−2.6%)** | +8.0% (−1.8%) | **TY-specific drop** |
| web | +44 bps | +32 bps | −0.1% (−0.9%) | +4.3% (+1.3%) | TY better than normal |
| Direct | −423 bps | −224 bps | −8.1% (−4.0%) | +10.4% (−0.7%) | mostly LY |
| Non-Brand SEM | −327 bps | −218 bps | **−9.3% (−3.6%)** | +6.6% (−1.4%) | **TY-specific drop** plus LY |
| Email | −97 bps | −102 bps | +2.8% (−5.4%) | +20.4% (+1.6%) | LY only (TY better) |
| Affiliate | −92 bps | −118 bps | −7.2% (−1.8%) | +16.7% (+1.8%) | mostly LY |
| SEO | −68 bps | – | −6.6% (+0.1%) | +11.4% (+2.6%) | TY softer, attribution issue open |

- **Deals.** The move is broad-based: no single deal exceeds ±$9.4K of the
  −$314K GB swing. This comes from the UE deal cut; sql/04 is the UNAGI
  version.
  - Worst TY-side deals: Chuck E. Cheese, Galveston Pleasure Pier, Catalina
    Flyer, Nickelodeon Universe, Georgia Aquarium. All are TTD Leisure.
- **Hours.** In US daytime (12–23 UTC), app and touch orders ran −9% to −17%
  Tue/Mon while web was flat (sql/05).
  - The JPROD-969 window (Orders Index API 404s, 11:42–15:10 UTC) is only
    about 1.4pp worse than the hours after it. It is **not** the main driver.
  - The pattern points to a mobile-specific issue lasting all day. Check the
    reCAPTCHA change (JPROD-955, "change is live" 9/22 04:01 UTC) and PayPal
    auth.

### 1d. Draft stand-up line (house format)

> **NORTH AMERICA:** M1VFM −2.6% YoY, −806 bps I GB +1.9% YoY, −1,110 bps
> - Mostly an LY base effect. LY Tue 9/23 was an OD day (~$1.07M GB on OD
>   campaigns vs ~$0.49M TY). TY GB was flat DtD.
> - TY softness is in orders (−6.5% DtD vs −1.6% normal), about −210 bps of
>   M1VFM.
> - Where: touch and app daytime (check reCAPTCHA JPROD-955), TTD Leisure,
>   NB SEM.
> - Categories: Core Local −1,023 bps (HBW −697, TTD Leisure −594), National
>   −411. Travel +311 on the EOQ Travel OD.
> - Channels: Direct −423, NB SEM −327, Email −97, Affiliate −92.
> - Incidents: JPROD-969 had marginal impact.

---

## 2. Data we have in FoundryAI

The BigQuery connector bills to `prj-grp-foundryai-dev-7c37`. **The dataview
views deny query access to this connector**, although their metadata is
readable. UE and UNAGI were therefore queried on their source tables in
`kbc-grpn-35`, which the connector can read. Confirm this path is acceptable,
or get dataview access (FOLLOWUPS F10).

| Tier | Source | Used for | Access |
|---|---|---|---|
| **Must** | UE `kbc-grpn-35.out_c_ue_location_and_ownership.unit_economics` (view `finance_unit_economics.unit_economics`) | M1VFM, GB, GR, OD+ILS, orders; campaign, customer and category cuts; hourly | ✅ source table |
| **Must** | UNAGI `kbc-grpn-35.out_c_unagi.unagi` (view `supply_unagi.unagi`) | Deal × platform × channel: UDVs, orders, GB, M1VFM | ✅ source table |
| **Must** | UNAGI `daily_deal_traffic` + `deal_traffic_mapping`, `active_deals_daily`, `deal_datamart_agg` | Deal views and visitors, live and sold-out deals | ✅ source (`kbc-grpn-35`), not yet queried |
| **Must** | Superfunnel `marketing.gbl_traffic_superfunnel_deal` / `_superfunnel` (source `kbc-grpn-14`) | Buy-button clicks, confirm and receipt views, sessions, bounce | ⛔ denied |
| Support | Finance Tracker `out_daily_tracker_bq_new` (`_cy` / `_ly`), `rm_tracker`, `order_economics` | Tie-out to the official numbers | ✅ source |
| Support | `checkoutfunnel.checkout_conversion`, `product_analytics.S3_session_funnel_summary` / `groupon_version_funnel_daily_agg` | Checkout, auth and fraud by platform (H2) | ⛔ denied |
| Support | `marketing.roi_datamart_v2`, `adspend`, `adspend_hourly`, `marketing_traffic.roi_datamart_sem` | SEM spend, clicks, CPC (H4) | ⛔ denied |
| Support | `managed_channels.emailing_datamart`, `push_datamart`; `pricing_and_promotions.promo_datamart` | CRM sends, promo spend | ⛔ denied |
| Qualitative | Drive doc "Daily Monitoring - Q3/2026"; Gemini, read.ai and Fireflies stand-up notes; WBRs; Weekly Sync | House format, hypotheses, existing action items | ✅ |
| Qualitative | Jira JPROD-955/957/961/962/969/970, GPROD-567175; GChat space for JPROD-955 (via Gmail) | Incidents and owners | ✅ |
| Qualitative | Asana "[OPS] Automated Checkout&Payments Daily Checks" (NA Elastic check, PayPal auth) | Checkout and payments signals | ✅ |

Not usable:
- `ingestion_circleback` excludes internal-only meetings.
- `realtime_analytics.finance_agg_metrics` is stale (2024).
- `sys_calendar` has no holiday flag.

---

## 3. Method: the YoY bridge

All three views are exact: their components sum to the DtD. They are
implemented in `tools/yoy_bridge.py`.

1. **Segment bridge (bps).**
   - A segment's contribution on day t is `c_i,t = (TY_i,t − LY_i,t) / LY_total,t`.
   - Its DtD is `c_i,D − c_i,D-1`.
   - That DtD splits into a **rate** effect (the segment's own YoY moved) and
     an **LY-mix** effect (its share of the LY base moved).
2. **Driver bridge.** `M1VFM = UDV × CVR × AOV × margin`, with a log
   decomposition. Each driver's DtD is its change in log-ratio, allocated pro
   rata.
3. **Base-effect split.** `ln(TY Tue/Mon) − ln(LY Tue/Mon)` splits into three
   parts, each measured against the normal Tue/Mon change:
   - TY abnormal
   - LY abnormal (the base effect)
   - normal seasonality

Data rules:
- Use `*_operational` UE columns and `economic_area = 'NA'`.
- Strip the `-mbnxt` suffix from platform names.
- Convert UNAGI money with `fx_rate_loc_to_usd_fxn`.
- Leave the Labor Day pairs (08-31/09-01, 09-07/08) out of the baseline.
- Both sources are T+1: UE lands about 04:10 UTC, UNAGI about 06:25 UTC.
- Re-run D once pending authorizations settle ($36K GB on 9/22, ±1.1pp).
- UNAGI orders double-count multi-deal orders. Reconcile totals to UE.

Rerun for another day:
- Replace `2026-09-22` in `sql/*.sql`.
- Export the results as CSV.
- Run `python3 tools/yoy_bridge.py segments out.csv --metric m1vfm` and
  `… drivers out.csv --traffic udv --orders ord --gb gb --value m1vfm`.

---

## 4. Work plan

### Phase 0: validate (before 10:00 CEST)

Run `sql/00_freshness.sql`, which checks:
- D is complete in UE and UNAGI.
- Pending authorizations.
- The Finance Tracker tie-out.

Also note these risks to the numbers:
- Gmail shows failed scheduled refreshes of the NA YoY sheets on 9/22–23.
- Keboola RM Tracker ran long.
- JPROD-970 (Tableau stale).
- The CoreBI weekly summary showed MVR/GP as $0.

**Exit:** the numbers in section 1 hold, or they are restated.

### Phase 1: size and locate (done, first pass)

Queries sql/01–06 plus the bridge tool produced section 1.

**Exit:** the stand-up line is agreed.

### Phase 2: explain the TY-specific part

| # | Hypothesis | Evidence so far | Test | Data | Meeting / owner |
|---|---|---|---|---|---|
| H1 | LY promo calendar: bigger OD Tuesday LY | Confirmed: ~$1.07M vs ~$0.49M OD GB | Campaign bridge (done). Pre-compute the next days' LY promo calendar | sql/06 | Jakub (F1) |
| H2 | Mobile checkout friction (reCAPTCHA JPROD-955, PayPal auth after the 9/15 cutover, NA Breakdown errors −75% WoW) | touch orders −12% vs −3% normal; app and touch weak all US daytime; web flat | Checkout UV → complete → authorized by platform and hour, 9/21 vs 9/22; 403 RECAPTCHA rate; NA Elastic check for 9/22 | checkout_conversion (⛔), OPS Asana check, JPROD-955 | 11:30 CEST RevMan + Checkout & Payments; Ernesto Martin, Giovanni Lagasio (F2) |
| H3 | JPROD-969 Orders Index API 404s (11:42–15:10 UTC) | Window only ~1.4pp worse than the hours after it | Quantify orders lost in the window; read the incident review | sql/05, JPROD-969 | Jakub (F5) |
| H4 | Non-Brand SEM: bidding or campaign migration (9/22 decision to move the remaining 25% to the new system) | NB SEM orders −9.3% vs −3.6% normal | Spend, clicks, CPC and conversions by campaign, 9/21 vs 9/22 and hourly; migration go-live time | adspend(_hourly), roi_datamart_sem (⛔) | Jakub + SEM team (F3) |
| H5 | TTD Leisure / Core Local: promo roll-off, end of summer, supply | TTD Leisure orders −18.9% vs −4.8%; worst deals are all attractions | Deal list with live and sold-out status; campaign cover of those deals; seasonality vs 2024 | sql/04, active_deals_daily, deal_datamart_agg | 16:30 CEST RevMan + Top Supply (F4) |
| H6 | Email sends issue (GPROD-567175, check_email_sends 9/22 failed) | TY email GB Tue/Mon +2.5% vs −2.5% normal, so a business impact is unlikely | Sends 9/21 vs 9/22 | emailing_datamart (⛔) | Managed Channels (F6) |
| H7 | Data and attribution artefacts (SEO over-attribution since 6/15, push attribution, pending auths) | SEO orders −6.6% vs +0.1% | Re-run D on 9/24; check the attribution fix timeline | sql/00, BI | BI (F7) |

**Exit:** every TY-abnormal bps is attributed or marked "unexplained".

### Phase 3: impact and outlook

- Put the TY-abnormal part into dollars:
  - M1VFM ≈ −$15K on 9/22.
  - Orders ≈ −1.9K.
- Recovery watch: Wed 9/23 vs LY Wed 9/24/2025, then 9/24 and 9/25 (F8).
  Check the LY promo calendar for those days first (F1).
- Quarter-end: per Ernesto Martin, the quarter can't be moved after 9/22.
  Relevance is to the **October exit rate**, where a tweak is proposed for
  early next week.

### Phase 4: outcomes and follow-ups

Classify each explained piece. The class decides what "done" means.

| Outcome class | 9/22 piece | Standard action | Done when |
|---|---|---|---|
| **Base effect** | LY OD-day spike (−12.7pp GB, −5.3pp M1VFM) | Annotate in the Daily Monitoring doc; no business action. Add an LY promo-calendar overlay to the daily bridge | Annotated; overlay live |
| **Decision** | TY OD Tuesday about half LY's size (margin discipline?) | RevMan / promo owners confirm it was intended; quantify the GB vs M1VFM trade-off | Decision recorded with owner |
| **Incident / tech** | Mobile checkout (H2), JPROD-969 (H3) | Jira ticket with owner; RevMan impact comment in JPROD; quantify $ | Ticket fixed; impact posted; metric back to normal |
| **Channel** | NB SEM (H4) | SEM team review; hold the 50% migration step if the new system is implicated | Root cause stated; spend and CVR normal |
| **Supply / category** | TTD Leisure, Core Local (H5) | Supply review of the losing deals | Deal actions logged |
| **Data** | Pending auths, refresh failures, SEO attribution (H7) | Re-run; BI tickets | Numbers stable; tickets closed |

**Follow-up hygiene.** The last time follow-ups were tracked in Asana (to
June), 84% of action items never closed, half had no due date, and owners
were concentrated on one person. From here:
- **One register.** Use [FOLLOWUPS.md](FOLLOWUPS.md) or Asana
  1208559068387418, which is a team decision (F9). Each item needs an owner,
  a real due date, a "done when" test and an evidence link.
- **Review daily at the stand-up.** Anything past due is escalated or
  re-dated with a reason.
- **One source of action items.** Take them from one note tool, not three
  conflicting ones.
- **Asana fields.** The REV project already has Type, Market, Platform,
  LOB/L2, Traffic Channel, Priority and REV Owner. Use them and add action
  items to the project itself.

---

## 5. Today (CEST)

| Time | What |
|---|---|
| 08:30 | Phase 0 checks; post the section-1 read to the team |
| 10:00 | Daily Revenue Stand-up: present 1d; confirm owners for F1–F10 |
| 10:30 | Jakub / Michal Hromek, "Rev Man automatic solution": scope automating this bridge |
| 11:30 | RevMan + Checkout & Payments: H2 with platform/hour evidence |
| 16:30 | RevMan + Top Supply & Supply Health: H5 deal list |
| EOD | Update FOLLOWUPS.md statuses; re-run for 9/23 once UE and UNAGI land (~06:30 UTC 9/24) |
