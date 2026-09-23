# Follow-up register: NA YoY deceleration, 2026-09-22

One list for this deterioration. It covers the new items from
[PLAN.md](PLAN.md) and the open items already raised in the 9/21–9/22
meetings, Jira and the OPS checks.

- **Owners.** Owners marked *(proposed)* need confirming at the 9/23 stand-up.
- **Due dates.** These are real deadlines, not the meeting day.
- **Updates.** Update the status at each stand-up until the item is closed.

**Status values:** Open, In progress, Blocked, Done, Dropped (with reason).

## A. New follow-ups from this plan

| ID | Follow-up | Outcome class | Owner | Due | Done when | Evidence | Status |
|---|---|---|---|---|---|---|---|
| F1 | Annotate the 9/22 read in "Daily Monitoring - Q3/2026" as mostly an LY base effect (LY Tue 9/23/25 OD day). Pre-compute the LY promo calendar for 9/23–9/30 so LY spikes are flagged before they show up as deterioration | Base effect | Jakub Nguyen *(proposed)* | 9/23 stand-up; calendar by 9/24 | Doc annotated; LY OD/ILS days for the next 7 days listed in the daily check | sql/06 | Open |
| F2 | Mobile checkout: explain app/touch orders −9% to −17% Tue/Mon in US daytime, with web flat. Pull checkout UV → complete → authorized by platform and hour for 9/21 vs 9/22. Check the 403 RECAPTCHA rate after the 9/22 JPROD-955 change and the PayPal auth rate | Incident / tech | Ernesto Martin + Giovanni Lagasio; Checkout & Payments | 9/23 11:30 CEST meeting | Root cause named (or ruled out) and lost orders/M1VFM quantified in JPROD-955 | sql/05; JPROD-955; OPS NA Elastic check | Open |
| F3 | Non-Brand SEM orders −9.3% Tue/Mon vs −3.6% normal. Check whether the "remaining 25% to the new system" migration (9/22 RevMan + SEM decision) went live on 9/22. Compare spend, clicks, CPC and CVR by campaign, 9/21 vs 9/22 | Channel | Jakub Nguyen + SEM team *(proposed)* | 9/24 | Driver stated; go/no-go on the 50% step recorded | adspend / roi_datamart_sem (needs access, F10) | Open |
| F4 | TTD Leisure orders −18.9% Tue/Mon vs −4.8% normal, and Core Local softer. Review the losing deals (Chuck E. Cheese, Galveston Pleasure Pier, Catalina Flyer, Nickelodeon Universe, Georgia Aquarium, …): live and sold-out status, promo cover, seasonality | Supply / category | Supply owners, via the 16:30 CEST RevMan + Top Supply meeting *(proposed)* | 9/23 16:30 CEST | Per-deal action or "seasonal, no action" logged | sql/04; active_deals_daily | Open |
| F5 | JPROD-969 (Orders Index API 404s, 11:42–15:10 UTC 9/22): post the RevMan impact comment. The first pass shows the window only ~1.4pp worse than the hours after it | Incident / tech | Jakub Nguyen *(proposed)* | 9/24 | Impact in $ posted on JPROD-969 | sql/05; JPROD-969 incident review | Open |
| F6 | Email: confirm whether GPROD-567175 (check_email_sends 2026-09-22 failed) was a real send gap or only a failed check. TY email GB Tue/Mon was +2.5% vs −2.5% normal, so an impact is unlikely | Data | Managed Channels *(proposed)* | 9/24 | Sends 9/22 vs 9/21 confirmed; GPROD closed | emailing_datamart; GPROD-567175 | Open |
| F7 | Re-run the 9/22 bridge on 9/24, after the $36K of pending authorizations settle (±1.1pp) and the NA YoY sheet refreshes that failed on 9/22–23 recover. Restate if YoY moves by more than 50 bps | Data | Jakub Nguyen *(proposed)* | 9/24 | Numbers confirmed or restated in the doc | sql/00; Gmail refresh-failure alerts | Open |
| F8 | Recovery watch: run the bridge for 9/23, 9/24 and 9/25. "Recovered" means TY Tue/Mon-style DoD is back within ±2pp of normal in orders and M1VFM for app, touch, TTD Leisure and NB SEM | Monitoring | Jakub Nguyen *(proposed)* | Daily to 9/25 | Three days within the band, or escalated | sql/01–05 | Open |
| F9 | Decide where follow-ups live: this register or Asana REV project 1208559068387418. If Asana, use its existing fields (Type, Market, Platform, LOB/L2, Traffic Channel, Priority, REV Owner) and add action items to the project, not only as subtasks | Process | Team, at the 9/23 stand-up | 9/23 | Decision recorded; open items migrated | – | Open |
| F10 | Data access: the FoundryAI BigQuery connector cannot query the dataview views (supply_unagi, finance_unit_economics, marketing incl. superfunnel, checkoutfunnel, product_analytics, managed_channels, pricing_and_promotions). Either confirm that the `kbc-grpn-35` source-table path is acceptable, or request BigQuery Data Viewer / authorized-view access for the connector principal, or use the Ask Data MCP | Data | Jakub Nguyen → data platform / dataset owners | 9/25 | Superfunnel, checkout and adspend queryable | PLAN.md §2 | Open |
| F11 | Decision: TY's Tuesday OD push was about half of LY's (~$0.49M vs ~$1.07M GB on OD campaigns). Confirm it was intended (margin discipline, e.g. the MinMargin10 variants) and put numbers on the GB vs M1VFM trade-off for the October exit-rate discussion | Decision | RevMan / promo owners; Ernesto Martin *(proposed)* | Before the early-next-week exit-rate tweak | Decision and rationale recorded | sql/06 | Open |
| F12 | Automate this bridge (base-effect split, driver bridge, segment bridge) in the daily check, with LY promo-calendar overlay | Process | Jakub Nguyen + Michal Hromek ("Rev Man automatic solution", 9/23 10:30 CEST) *(proposed)* | Scope by 9/30 | Bridge runs daily without manual steps | tools/yoy_bridge.py; sql/ | Open |

## B. Existing open items that bear on this deterioration

Collected from meeting notes, Jira and the OPS checks on 2026-09-23. Owners
are as stated in those sources.

| Source | Item | Owner | Due | Status | Link to plan |
|---|---|---|---|---|---|
| JPROD-955 (SEV-2) + GChat space | reCAPTCHA thresholds: iOS 0.3 live since 9/20 17:28; Android 0.3 proposed; exemptions for Apple Pay, Google Pay 3DS, Klarna, CashApp (need code change). "Monitor every 10' since change is live" (9/22 04:01 UTC) | Indresh Srivastava, David Lorenzo (Eng); Jakub Nguyen (RevMan monitoring) | – | In progress | H2 / F2 |
| 9/21 stand-up | reCAPTCHA and Android rejections (~10K daily failed transactions, $5–10K/day) | Ernesto Martin + Giovanni Lagasio | – | Open | H2 / F2 |
| OPS NA Elastic check 9/22 (Asana 1218729451701666) | NA Breakdown Errors request volume −75% WoW since 9/18: "flag to Engineering" | **No owner or ticket** | – | Open | H2 / F2: needs an owner |
| OPS "(HIGH) - Paypal OrdAuth/Ord" (Asana 1218683962045093) | PayPal auth 75.17% vs 78.47% after the 9/15 REST cutover; "will monitor next few days" | Prarthana | 9/22 (past due) | Open | H2 / F2 |
| JPROD-969 | Orders Index API 404 spike, 9/22 11:42–15:10 UTC; incident review doc in comments | Eng | – | Done (incident); impact pending | H3 / F5 |
| JPROD-942 | VIS mass 503s (NA sitewide, 9/17): incident review | Chetanya Gupta | 9/24 | Open | context |
| JPROD-737 | iOS/Android 3DS auth-rate issue (~$500K GMV/month) | Eng | – | In progress | H2 |
| GPROD-567175 | Global_Email_Revenue check_email_sends 2026-09-22 failed | – | – | To do | H6 / F6 |
| JPROD-970 | Account Portfolio v3 Tableau stale since 9/18 | Eng/BI | – | In progress | F7 |
| Weekly Sync 9/21 | SEO over-attribution fix (since ~6/15; retrospective fix with BI and Michal Charvat) | BI; Jakub Nguyen | This week | Open | H7 |
| Weekly Sync 9/21 | iPhone checkout errors; SEM non-brand; NA merchant winners/losers report for Adi | Jakub Nguyen | – | Open | H2, H4, H5 |
| 9/22 stand-up | Review paid-channel changes and report in chat | Ernesto Martin | – | Open | H4 / F3 |
| 9/22 stand-up | Favour campaigns that generate more gross bookings | Jakub Nguyen + SEM team | – | Open | H4 / F3 |
| 9/22 stand-up | October exit-rate tweak early next week | **Unassigned** | Early next week | Open | F11 |
| RevMan + SEM & Display 9/22 | Share the OTB/LTV-bidding report; move the remaining 25% of campaigns to the new system, then 50% | Jakub Nguyen | 9/23 | Open | H4 / F3 |
| CoreBI weekly summary 2026-09-21 (Asana 1218694122519508) | MVR/GP reported as $0 for the week of Sep 14, which suggests a data gap | CoreBI | – | Open | F7 |
| Asana 1216588279401266 | Checkout + Payment + Fraud data/monitoring outputs alignment | Jakub Nguyen | 8/21 (past due) | Open | H2 |

## Hygiene rules for this register

1. **Close items only with evidence.** A number, a ticket state or a decision
   must be linked in the Evidence column.
2. **Re-date with a reason.** A due date moves only with a written reason;
   a second move means the item is escalated at the stand-up.
3. **One owner per item.** Where a group is responsible, name who reports back.
4. **Log every stand-up decision.** Put it in the "Decision" rows (F9, F11)
   the same day.
