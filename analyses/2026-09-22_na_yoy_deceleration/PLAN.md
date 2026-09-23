# NA YoY deceleration, Tue 2026-09-22: investigation plan

**Question.** NA YoY stepped down from Mon 9/21 to Tue 9/22. What drove that
day-to-day (DtD) deceleration? Is it a real TY problem or an LY base effect,
and what are the outcomes and follow-ups?

**Status.**
- **First-pass bridge:** done on unit economics (UE) and UNAGI as of
  2026-09-23 06:30 UTC (section 1).
- **Funnel deep-dive:** done at 07:30 UTC, covering UV → deal view → buy-button
  click → checkout → order by platform and traffic source (section 1e).
- **Report:** a shareable HTML version is at
  [report/na_yoy_bridge_2026-09-22.html](report/na_yoy_bridge_2026-09-22.html).
  It is built by `build_report.py` from `data/` and is ready to upload to IQ.
- **Stand-up:** the 10:00 CEST stand-up reviews 9/22 today.
- **Open items:** see [FOLLOWUPS.md](FOLLOWUPS.md).

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
| Orders (UE) | +1.5% | −13.2% | −1,468 bps |
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

*Updated by 1e.* The "TY-specific drop" readings compare Tue/Mon with normal.
The touch reading especially reflects a strong TY Monday: touch orders were
+16.9% against the previous Monday but +5.6% on Tuesday.

- **Deals.** The move is broad-based: no single deal exceeds ±$9.4K of the
  −$314K GB swing. This comes from the UE deal cut; sql/04 is the UNAGI
  version.
  - Worst TY-side deals: Chuck E. Cheese, Galveston Pleasure Pier, Catalina
    Flyer, Nickelodeon Universe, Georgia Aquarium. All are TTD Leisure.
- **Hours.** In US daytime (12–23 UTC), app and touch orders ran −9% to −17%
  Tue/Mon while web was flat (sql/05).
  - The JPROD-969 window (Orders Index API 404s, 11:42–15:10 UTC) is only
    about 1.4pp worse than the hours after it. It is **not** the main driver.
  - The funnel deep-dive (1e) puts this in checkout completion. Most of it is
    Monday running unusually strong, not a Tuesday failure. The browser
    checkout gap against August is the longer-running issue.

### 1e. Funnel deep-dive: TY Tuesday was not weak; Monday and LY were the outliers

**Week-over-week check** (UE, same weekday a week earlier; sql/09):

| NA | TY Mon 9/21 vs 9/14 | TY Tue 9/22 vs 9/15 | LY Mon vs prior Mon | LY Tue vs prior Tue |
|---|---:|---:|---:|---:|
| Orders | +6.3% | **+1.5%** | **−7.1%** | +4.7% |
| M1VFM | +2.8% | **+1.0%** | −0.3% | **+7.9%** |

- TY Tuesday grew slightly against the previous Tuesday on every platform.
- The YoY swing therefore sits in LY: a weak Monday comp, then a strong
  order-discount Tuesday.
- Part of the "TY weaker than normal" in 1a is a strong TY Monday: touch
  orders were +16.9% against the previous Monday.

**Full funnel** (sql/10, sql/11; data/na_full_funnel.csv, data/checkout_funnel_ty_baseline.csv):

- **Upper funnel was normal.** UV, deal viewers, UDV and buy-button clicks per
  UDV all moved in line.
  - UV YoY went from −7.5% to −9.4%, which is −190 bps, mostly LY-driven.
- **The Tue/Mon conversion drop sits entirely in checkout completion.**
  Purchases per buy-click, Tue vs Mon:

  | Platform | Tue vs Mon | Normal |
  |---|---:|---:|
  | iOS app | −6.1% | −2.5% |
  | Android app | −4.1% | +0.6% |
  | touch | −7.3% | +0.3% |
  | web | −7.0% | −0.1% |

- **Monday was the abnormal day, not Tuesday.** Completion on Mon 9/21
  against Mon 9/14 was touch +17.5%, web +5.4%, iOS +4.8% and Android +5.4%.
  Tue 9/22 against Tue 9/15 was touch +9.5%, iOS +0.2%, Android +1.5% and web
  −2.0%.
- **The bigger, ongoing issue is browser checkout.** Purchases per buy-click:

  | Platform | Early August | 9/14–15 (reCAPTCHA blocks) | 9/22 |
  |---|---:|---:|---:|
  | touch | 28–29% | 22.8–22.9% | 24.9% |
  | web | 35–36% | 30.8% | 30.2% |

  - The apps held steady or improved over the same period.
  - At August completion rates that is roughly 1–2K purchases a day on touch
    plus web. This still needs checking for deal-mix and seasonality effects
    (F13).
- **Web anomaly on 9/22:** checkout views per buy-click were +12% against the
  previous Tuesday while web orders were flat (+0.5%). This is consistent with
  checkout reloads; check it against the JPROD-969 window (F15).
- **Channels** (UNAGI funnel steps vs normal, sql/08):
  - **Non-Brand SEM:** impressions fell about 8% Tue/Mon on app and touch. The
    same drop happened on 8/24 and 9/14, so it looks like a weekday delivery
    pattern rather than a 9/22 event (F3).
  - **App push:** impressions −9.7% Tue/Mon against a normal +1% (F16).
  - **App Direct:** conversion was the largest single TY-abnormal cell
    (−127 bps). It is part of the checkout-completion pattern above.

### 1d. Draft stand-up line (house format)

> **NORTH AMERICA:** M1VFM −2.6% YoY, −806 bps I GB +1.9% YoY, −1,110 bps
> - Mostly an LY base effect. LY Tue 9/23 was an OD day (~$1.07M GB on OD
>   campaigns vs ~$0.49M TY). TY GB was flat DtD.
> - TY Tuesday was not weak against last week: M1VFM +1.0% and orders +1.5% vs
>   Tue 9/15.
> - The Tue/Mon softness (about −210 bps M1VFM) is checkout completion
>   falling back from an unusually strong Monday 9/21 on every platform.
> - Ongoing risk: browser (touch and web) checkout completion is 3–6 points
>   below August levels.
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
| **Must** | UV: `kbc-grpn-28.out_c_rm_tracker.rm_tracker` (by traffic, de-duplicated) and `kbc-grpn-28.out_c_additional_views_rm_sheet.additional_view_rm_sheet` (by platform; D can be partial) | UV | ✅ |
| **Must** | `kbc-grpn-28.in_c_tr_level_02_gpr_traffic_l1.agg_gbl_traffic_l1` (linked copy of `marketing.agg_gbl_traffic_l1`) | Impressions, UDV, deal viewers by platform, iOS/Android and traffic sub-source | ✅ |
| **Must** | Janus `kbc-grpn-28.janus_impressions.junoHourly` plus `mvp_rt_traffic_metrics.daily_first_click_traffic_source_details` | Buy-button clicks, checkout views, checkout UV, purchases | ✅ TY only (retention from 2026-07-16) |
| **Must** | Superfunnel `marketing.gbl_traffic_superfunnel(_deal)` (source `kbc-grpn-14`) and its linked copy `kbc-grpn-28.in_c_shr_web_traffic.*` | Sessions, bounce, and LY buy-clicks and checkout | ⛔ view denied; the copy is queryable but 3.4 TB and unpartitioned (120–620 GB per query) |
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
| H2 | Checkout friction (reCAPTCHA JPROD-955, PayPal auth after the 9/15 cutover, NA Breakdown errors −75% WoW) | **Partly explained.** The Tue/Mon drop is in purchases per buy-click on every platform, but Tue matched or beat the previous Tue; Mon 9/21 spiked (H9). Browser completion has been 3–6 points below August since late August (H8) | 403 RECAPTCHA rate and PayPal/3DS auth by platform and hour for 9/14–9/22; NA Elastic check for 9/22 | sql/11, OPS Asana check, JPROD-955 | 11:30 CEST RevMan + Checkout & Payments; Ernesto Martin, Giovanni Lagasio (F2) |
| H3 | JPROD-969 Orders Index API 404s (11:42–15:10 UTC) | Window only ~1.4pp worse than the hours after it | Quantify orders lost in the window; read the incident review | sql/05, JPROD-969 | Jakub (F5) |
| H4 | Non-Brand SEM: bidding or campaign migration (9/22 decision to move the remaining 25% to the new system) | NB SEM orders −9.3% vs −3.6% normal. Impressions fell about 8% Tue/Mon on app and touch, as they also did on 8/24 and 9/14, which points to a weekday delivery pattern | Spend, clicks, CPC and conversions by campaign and weekday since August; migration go-live time | adspend(_hourly), roi_datamart_sem (⛔) | Jakub + SEM team (F3) |
| H5 | TTD Leisure / Core Local: promo roll-off, end of summer, supply | TTD Leisure orders −18.9% vs −4.8%; worst deals are all attractions | Deal list with live and sold-out status; campaign cover of those deals; seasonality vs 2024 | sql/04, active_deals_daily, deal_datamart_agg | 16:30 CEST RevMan + Top Supply (F4) |
| H6 | Email sends issue (GPROD-567175, check_email_sends 9/22 failed) | TY email GB Tue/Mon +2.5% vs −2.5% normal, so a business impact is unlikely | Sends 9/21 vs 9/22 | emailing_datamart (⛔) | Managed Channels (F6) |
| H7 | Data and attribution artefacts (SEO over-attribution since 6/15, push attribution, pending auths) | SEO orders −6.6% vs +0.1% | Re-run D on 9/24; check the attribution fix timeline | sql/00, BI | BI (F7) |
| H8 | Browser checkout completion is structurally down (touch and web) | touch 28–29% → 24.9% and web 35–36% → 30.2% of buy-clicks since early August; apps flat or up | Completion by browser, OS and payment method since 8/1; overlay reCAPTCHA threshold changes, the PayPal cutover and 3DS | sql/11 extended; Checkout & Payments | Checkout & Payments (F13) |
| H9 | Monday 9/21 checkout spike | Completion +5% to +17% vs the previous Monday on every platform | Cause: iOS reCAPTCHA threshold live 9/20 17:28? Monday checkout promos? | sql/06, sql/11, JPROD-955 | Jakub (F14) |
| H10 | Web checkout reloads on 9/22 | Checkout views per buy-click +12% WoW; web orders flat | Hourly checkout views vs purchases on web, JPROD-969 window | junoHourly by hour | Jakub (F15) |
| H11 | App push volume on 9/22 | App push impressions −9.7% Tue/Mon vs +1% normal | Push sends 9/21 vs 9/22 | push_datamart (⛔) | Managed Channels (F16) |

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
| **Incident / tech** | Checkout friction (H2), JPROD-969 (H3), web reloads (H10) | Jira ticket with owner; RevMan impact comment in JPROD; quantify $ | Ticket fixed; impact posted; metric back to normal |
| **Structural** | Browser checkout completion 3–6 points below August (H8) | Checkout & Payments owns a recovery plan with a target completion rate by platform, with the gap in purchases/day tracked daily | Completion back to its August level, or the gap explained by mix |
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
| 11:30 | RevMan + Checkout & Payments: H2/H8/H10 with the checkout-completion chart (report section 4) |
| 16:30 | RevMan + Top Supply & Supply Health: H5 deal list |
| EOD | Update FOLLOWUPS.md statuses; re-run for 9/23 once UE and UNAGI land (~06:30 UTC 9/24) |
