# revenue_agent

Revenue Monitoring analyses and tooling for Groupon FIN (NA / INTL YoY
performance).

- `tools/yoy_bridge.py` explains a day-to-day change in YoY growth (D-1 -> D)
  in three exact views, using stdlib only:
  - segment bridge, in bps, split into rate and LY-mix effects
  - driver bridge, UDV x CVR x AOV x margin
  - base-effect split, TY vs LY against normal day-over-day
- `analyses/<date>_<topic>/` holds one folder per investigation, containing
  `PLAN.md`, `FOLLOWUPS.md` and the `sql/` that feeds the bridge.

BigQuery jobs always run in the FoundryAI billing project
`prj-grp-foundryai-dev-7c37`; data tables are referenced fully qualified.

Tests: `python3 -m unittest discover -s tests`
