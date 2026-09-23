"""Build the HTML report for the 2026-09-22 NA YoY deceleration.

Reads the aggregated query outputs in data/ (see sql/ for the queries),
computes every figure with tools/yoy_bridge.py, and writes one
self-contained HTML file to report/. No network, stdlib only.

    python3 analyses/2026-09-22_na_yoy_deceleration/build_report.py
"""

from __future__ import annotations

import csv
import datetime as dt
import html
import os
import statistics
import sys
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "tools"))

from yoy_bridge import (  # noqa: E402
    Segment, base_effect_split, chain_bridge, segment_bridge,
)

DATA = os.path.join(HERE, "data")
OUT = os.path.join(HERE, "report", "na_yoy_bridge_2026-09-22.html")
BUCKETS = ("ty_d1", "ly_d1", "ty_d", "ly_d")
D, D1 = dt.date(2026, 9, 22), dt.date(2026, 9, 21)


def rows(name: str) -> list[dict]:
    with open(os.path.join(DATA, name), newline="") as f:
        return list(csv.DictReader(f))


def esc(s) -> str:
    return html.escape(str(s))


def pct(x: float | None, digits: int = 1) -> str:
    return "n/a" if x is None else f"{x * 100:+.{digits}f}%"


def pct0(x: float) -> str:
    v = round(x * 100)
    return f"{v:+d}%" if v else "0%"


def bps(x: float) -> str:
    return f"{x * 1e4:+,.0f}"


def num(x: float) -> str:
    return f"{x:,.0f}"


def sign_class(x: float, tol: float = 0.0) -> str:
    return "pos" if x > tol else "neg" if x < -tol else ""


# --------------------------------------------------------------------------
# Data
# --------------------------------------------------------------------------

def load_ue_daily() -> dict[tuple[str, dt.date], tuple[float, float, float]]:
    out = {}
    for r in rows("ue_daily_by_platform.csv"):
        out[(r["platform"], dt.date.fromisoformat(r["date"]))] = (
            float(r["orders"]), float(r["gb"]), float(r["m1vfm"]))
    return out


def load_pivot() -> list[dict]:
    return rows("unagi_bridge_by_dimension.csv")


def pivot_vals(r: dict, metric: str) -> tuple[float, float, float, float]:
    return tuple(float(r[f"{metric}_{b}"]) for b in BUCKETS)


def baseline() -> dict[tuple[str, str], dict[str, tuple[float, float]]]:
    """(segment, year) -> metric -> (actual 09-21 pair, median of other pairs)."""
    acc: dict = defaultdict(lambda: defaultdict(list))
    act: dict = defaultdict(dict)
    for r in rows("unagi_mon_tue_baseline.csv"):
        key = (r["segment"], r["year"])
        for m in ("udv_dod_pct", "orders_dod_pct", "gb_dod_pct", "m1vfm_dod_pct"):
            v = float(r[m]) / 100
            if r["ty_monday"] == "0921":
                act[key][m] = v
            else:
                acc[key][m].append(v)
    return {k: {m: (act[k][m], statistics.median(acc[k][m])) for m in act[k]} for k in act}


# --------------------------------------------------------------------------
# SVG charts (static, per-mark <title> tooltips, colors via CSS tokens)
# --------------------------------------------------------------------------

def line_chart(series: list[tuple[str, str, list[tuple[str, float]]]], height: int = 260) -> str:
    """series: (label, css color var, [(x label, y value)])."""
    w, h, ml, mr, mt, mb = 760, height, 44, 96, 16, 30
    xs = [x for x, _ in series[0][2]]
    ys = [y for _, _, pts in series for _, y in pts]
    lo, hi = min(ys + [0.0]), max(ys + [0.0])
    pad = (hi - lo) * 0.08
    lo, hi = lo - pad, hi + pad
    px = lambda i: ml + i * (w - ml - mr) / (len(xs) - 1)  # noqa: E731
    py = lambda v: mt + (hi - v) * (h - mt - mb) / (hi - lo)  # noqa: E731
    out = [f'<svg viewBox="0 0 {w} {h}" class="chart" role="img" '
           f'aria-label="Daily M1VFM YoY by platform">']
    step = 0.05
    t = (lo // step + 1) * step
    while t < hi:
        y = py(t)
        cls = "axis" if abs(t) < 1e-9 else "grid"
        out.append(f'<line class="{cls}" x1="{ml}" x2="{w - mr}" y1="{y:.1f}" y2="{y:.1f}"/>')
        out.append(f'<text class="tick" x="{ml - 6}" y="{y + 4:.1f}" text-anchor="end">{t * 100:+.0f}%</text>')
        t += step
    for i, x in enumerate(xs):
        out.append(f'<text class="tick" x="{px(i):.1f}" y="{h - 10}" text-anchor="middle">{esc(x)}</text>')
    for label, color, pts in series:
        d = " ".join(f"{'M' if i == 0 else 'L'}{px(i):.1f},{py(v):.1f}" for i, (_, v) in enumerate(pts))
        width = 2.5 if label.startswith("NA") else 2
        out.append(f'<path d="{d}" fill="none" stroke="var({color})" stroke-width="{width}" '
                   f'stroke-linejoin="round" stroke-linecap="round"/>')
        for i, (x, v) in enumerate(pts):
            out.append(f'<circle cx="{px(i):.1f}" cy="{py(v):.1f}" r="4" fill="var({color})" '
                       f'stroke="var(--surface-1)" stroke-width="2"/>')
            out.append(f'<circle cx="{px(i):.1f}" cy="{py(v):.1f}" r="11" class="hit">'
                       f'<title>{esc(label)} · {esc(x)}: {v * 100:+.1f}% YoY</title></circle>')
    # direct labels at the line ends, nudged apart so they never overlap
    ends = sorted(((py(pts[-1][1]), label, pts[-1][1]) for label, _, pts in series))
    placed: list[float] = []
    for y, label, v in ends:
        y = max(y, placed[-1] + 15) if placed else y
        placed.append(y)
        out.append(f'<text class="dlabel" x="{px(len(xs) - 1) + 10:.1f}" y="{y + 4:.1f}">'
                   f'{esc(label)} {v * 100:+.1f}%</text>')
    out.append("</svg>")
    return "".join(out)


def bar_rows(items: list[tuple[str, float, str]], unit: str = "pp", width: int = 360) -> str:
    """Horizontal bars around a zero line. items: (label, value, css color var)."""
    rowh, lab_w, pad_r = 28, 118, 8
    lo = min(0.0, min(v for _, v, _ in items))
    hi = max(0.0, max(v for _, v, _ in items))
    if hi == lo:
        hi = lo + 1
    # reserve fixed room for the value labels beside the bar ends
    x0 = lab_w + (66 if lo < 0 else 4)
    x1 = width - pad_r - (66 if hi > 0 else 4)
    sx = lambda v: x0 + (v - lo) / (hi - lo) * (x1 - x0)  # noqa: E731
    h = rowh * len(items) + 6
    out = [f'<svg viewBox="0 0 {width} {h}" class="chart bars" role="img">']
    out.append(f'<line class="axis" x1="{sx(0):.1f}" x2="{sx(0):.1f}" y1="0" y2="{h}"/>')
    for i, (label, v, color) in enumerate(items):
        y = 4 + i * rowh
        a, b2 = sorted((sx(0), sx(v)))
        val = f"{v * 100:+.1f}{unit}" if unit == "pp" else f"{v * 1e4:+,.0f} bps"
        out.append(f'<text class="rlabel" x="{lab_w - 8}" y="{y + 15}" text-anchor="end">{esc(label)}</text>')
        out.append(f'<rect x="{a:.1f}" y="{y + 4}" width="{max(b2 - a, 1.5):.1f}" height="15" rx="4" '
                   f'fill="var({color})"><title>{esc(label)}: {val}</title></rect>')
        tx, anchor = (b2 + 5, "start") if v >= 0 else (a - 5, "end")
        out.append(f'<text class="vlabel" x="{tx:.1f}" y="{y + 15}" text-anchor="{anchor}">{val}</text>')
    out.append("</svg>")
    return "".join(out)


def heat_cell(v: float, lim: float = 250) -> str:
    """Diverging cell: blue (+) / red (-) mixed into the neutral midpoint."""
    share = min(abs(v) / lim, 1.0) * 80
    color = "--div-pos" if v > 0 else "--div-neg"
    style = (f"background: color-mix(in oklab, var({color}) {share:.0f}%, var(--div-mid))"
             if abs(v) >= 1 else "background: var(--div-mid)")
    return f'<td class="heat" style="{style}" title="{v:+,.0f} bps">{v:+,.0f}</td>'


# --------------------------------------------------------------------------
# Sections
# --------------------------------------------------------------------------

def headline(ue) -> tuple[str, dict]:
    def yoy(seg, day, i):
        return ue[(seg, day)][i] / ue[(seg, day - dt.timedelta(364))][i] - 1
    k = {}
    for name, i in (("M1VFM", 2), ("GB", 1), ("Orders", 0)):
        k[name] = (yoy("ALL", D1, i), yoy("ALL", D, i))
    wow_m1 = ue[("ALL", D)][2] / ue[("ALL", D - dt.timedelta(7))][2] - 1
    wow_ord = ue[("ALL", D)][0] / ue[("ALL", D - dt.timedelta(7))][0] - 1
    tiles = []
    for name, (a, b) in k.items():
        tiles.append(
            f'<div class="tile"><div class="tile-label">NA {name} YoY</div>'
            f'<div class="tile-value">{pct(b)}</div>'
            f'<div class="tile-sub">Mon {pct(a)} → Tue · <span class="{sign_class(b - a)}">'
            f'{bps(b - a)} bps</span></div></div>')
    tiles.append(
        f'<div class="tile"><div class="tile-label">TY Tue vs previous Tue</div>'
        f'<div class="tile-value">{pct(wow_m1)}</div>'
        f'<div class="tile-sub">M1VFM · orders {pct(wow_ord)}</div></div>')
    return '<div class="tiles">' + "".join(tiles) + "</div>", k


def trend_section(ue) -> str:
    days = [dt.date(2026, 9, 14) + dt.timedelta(i) for i in range(9)]
    series = []
    for label, seg, color in (("NA", "ALL", "--ink-series"), ("app", "app", "--series-1"),
                              ("touch", "touch", "--series-2"), ("web", "web", "--series-3")):
        pts = [(d.strftime("%a %d"), ue[(seg, d)][2] / ue[(seg, d - dt.timedelta(364))][2] - 1)
               for d in days]
        series.append((label, color, pts))
    table = ["<table class='num'><thead><tr><th>M1VFM YoY</th>"
             + "".join(f"<th>{d.strftime('%a %d')}</th>" for d in days) + "</tr></thead><tbody>"]
    for label, _, pts in series:
        table.append(f"<tr><td>{esc(label)}</td>" + "".join(
            f"<td class='{sign_class(v)}'>{v * 100:+.1f}%</td>" for _, v in pts) + "</tr>")
    table.append("</tbody></table>")
    legend = ('<div class="legend">'
              '<span><i style="background:var(--ink-series)"></i>NA total</span>'
              '<span><i style="background:var(--series-1)"></i>app</span>'
              '<span><i style="background:var(--series-2)"></i>touch</span>'
              '<span><i style="background:var(--series-3)"></i>web</span></div>')
    return (line_chart(series) + legend
            + "<details><summary>Table view</summary>" + "".join(table) + "</details>")


def base_effect_section(pivot, base) -> tuple[str, dict]:
    total = next(r for r in pivot if r["dimension"] == "total")
    res = {}
    for name, metric, key in (("GB", "gb", "gb_dod_pct"), ("M1VFM", "m1vfm", "m1vfm_dod_pct"),
                              ("Orders", "ord", "orders_dod_pct"), ("UDVs", "udv", "udv_dod_pct")):
        v = pivot_vals(total, metric)
        ty_n = base[("TOTAL", "TY")][key][1]
        ly_n = base[("TOTAL", "LY")][key][1]
        res[name] = base_effect_split(*v, ty_n, ly_n)
    trs = []
    for name, r in res.items():
        p = r["pp"]
        trs.append(
            f"<tr><td>{name}</td><td>{pct(r['ty_dod'])}</td><td>{pct(r['ty_normal_dod'])}</td>"
            f"<td>{pct(r['ly_dod'])}</td><td>{pct(r['ly_normal_dod'])}</td>"
            f"<td class='neg'><b>{bps(p['ly_abnormal_base_effect'])}</b></td>"
            f"<td class='{sign_class(p['ty_abnormal'])}'><b>{bps(p['ty_abnormal'])}</b></td>"
            f"<td>{bps(p['normal_seasonality'])}</td><td>{bps(r['delta_pp'])}</td></tr>")
    table = ("<table class='num'><thead><tr><th>Metric (UNAGI)</th><th>TY Tue/Mon</th>"
             "<th>TY normal</th><th>LY Tue/Mon</th><th>LY normal</th><th>LY base effect</th>"
             "<th>TY vs normal</th><th>Seasonality</th><th>DtD (bps)</th></tr></thead><tbody>"
             + "".join(trs) + "</tbody></table>")
    bars = []
    for name in ("M1VFM", "GB", "Orders"):
        p = res[name]["pp"]
        bars.append(f"<div class='bar-block'><h4>{name}: {bps(res[name]['delta_pp'])} bps</h4>" + bar_rows([
            ("LY base effect", p["ly_abnormal_base_effect"], "--series-2"),
            ("TY vs normal", p["ty_abnormal"], "--series-1"),
            ("Seasonality drift", p["normal_seasonality"], "--series-3"),
        ], unit="bps") + "</div>")
    return "<div class='bars-grid'>" + "".join(bars) + "</div>" + table, res


def wow_section(ue) -> str:
    trs = []
    for seg in ("ALL", "app", "touch", "web"):
        for name, i in (("Orders", 0), ("M1VFM", 2), ("GB", 1)):
            def w(a, b):
                return ue[(seg, a)][i] / ue[(seg, b)][i] - 1
            vals = [w(D1, D1 - dt.timedelta(7)), w(D, D - dt.timedelta(7)),
                    w(D1 - dt.timedelta(364), D1 - dt.timedelta(371)),
                    w(D - dt.timedelta(364), D - dt.timedelta(371))]
            label = "NA" if seg == "ALL" else seg
            trs.append(f"<tr><td>{label}</td><td>{name}</td>" + "".join(
                f"<td class='{sign_class(v, 0.02)}'>{pct(v)}</td>" for v in vals) + "</tr>")
    return ("<table class='num'><thead><tr><th>Platform</th><th>Metric</th>"
            "<th>TY Mon 9/21 vs 9/14</th><th>TY Tue 9/22 vs 9/15</th>"
            "<th>LY Mon 9/22 vs 9/15</th><th>LY Tue 9/23 vs 9/16</th></tr></thead><tbody>"
            + "".join(trs) + "</tbody></table>")


STEP_NAMES = ["Impressions", "UDV / impr. (CTR)", "Orders / UDV (CVR)", "GB / order (AOV)",
              "M1VFM / GB (margin)"]


def funnel_levels_section() -> str:
    data: dict = defaultdict(dict)
    for r in rows("unagi_funnel_platform_source.csv"):
        data[(r["platform"], r["traffic_source"])][r["bucket"]] = tuple(
            float(r[c]) for c in ("impressions", "udv", "orders", "gb_usd", "m1vfm_usd"))
    na = data[("ALL", "ALL")]
    names = ["impressions", "udv", "orders", "gb", "m1vfm"]
    out_rows = []
    for key, v in data.items():
        if min(v[b][1] for b in BUCKETS) < 500 or min(v[b][0] for b in BUCKETS) < 1000:
            continue
        chain = [(n, tuple(v[b][i] for b in BUCKETS)) for i, n in enumerate(names)]
        res = chain_bridge(chain)
        dc = ((v["ty_d"][4] - v["ly_d"][4]) / na["ly_d"][4]
              - (v["ty_d1"][4] - v["ly_d1"][4]) / na["ly_d1"][4])
        out_rows.append((key, res, dc, v))
    order = {"ALL": 0, "app": 1, "touch": 2, "web": 3}
    out_rows.sort(key=lambda x: (x[0][1] != "ALL", order[x[0][0]] if x[0][1] == "ALL" else 9, x[2]))
    trs = []
    for (pf, ts), res, dc, v in out_rows:
        label = ("NA" if pf == "ALL" else pf) + ("" if ts == "ALL" else f" · {ts}")
        cls = "total" if ts == "ALL" else ""
        cells = "".join(
            f"<td><span class='yoy'>{pct0(s['yoy_d1'])} → {pct0(s['yoy_d'])}</span>"
            f"<span class='share {sign_class(s['pp'], 0.002)}'>{s['pp'] * 100:+.1f}pp</span></td>"
            for s in res["steps"])
        trs.append(f"<tr class='{cls}'><td>{esc(label)}</td>"
                   f"<td>{res['yoy_d1'] * 100:+.1f}% → {res['yoy_d'] * 100:+.1f}%</td>"
                   f"<td class='{sign_class(dc)}'><b>{bps(dc)}</b></td>{cells}</tr>")
    return ("<table class='num funnel'><thead><tr><th>Platform · source</th><th>M1VFM YoY Mon → Tue</th>"
            "<th>Contribution to NA DtD (bps)</th>"
            + "".join(f"<th>{n}</th>" for n in STEP_NAMES)
            + "</tr></thead><tbody>" + "".join(trs) + "</tbody></table>"
            "<p class='note'>Each step cell shows the step's YoY on Mon → Tue and its share of that "
            "row's own M1VFM YoY change (pp). Cells with fewer than 500 UDVs or 1,000 impressions "
            "on any day are omitted.</p>")


def funnel_vs_normal_section() -> str:
    cells: dict = defaultdict(dict)
    for r in rows("unagi_funnel_steps_vs_normal.csv"):
        cells[(r["platform"], r["traffic_source"])][int(r["step"])] = r
    order = {"ALL": 0, "app": 1, "touch": 2, "web": 3}
    keys = sorted(cells, key=lambda k: (k[1] != "ALL", order[k[0]] if k[1] == "ALL" else 9,
                                        float(cells[k][1]["dc_bps_exact"])))
    trs = []
    for pf, ts in keys:
        c = cells[(pf, ts)]
        label = ("NA" if pf == "ALL" else pf) + ("" if ts == "ALL" else f" · {ts}")
        ty = [float(c[s]["ty_abn_bps"]) for s in range(1, 6)]
        ly = sum(float(c[s]["ly_abn_bps"]) for s in range(1, 6))
        seas = sum(float(c[s]["seas_bps"]) for s in range(1, 6))
        dc = float(c[1]["dc_bps_exact"])
        cls = "total" if ts == "ALL" else ""
        trs.append(f"<tr class='{cls}'><td>{esc(label)}</td>"
                   + "".join(heat_cell(v) for v in ty)
                   + f"<td class='{sign_class(sum(ty))}'><b>{sum(ty):+,.0f}</b></td>"
                   f"<td class='{sign_class(ly)}'>{ly:+,.0f}</td><td>{seas:+,.0f}</td>"
                   f"<td class='{sign_class(dc)}'>{dc:+,.0f}</td></tr>")
    return ("<table class='num heatmap'><thead><tr><th>Platform · source</th>"
            + "".join(f"<th>{n}</th>" for n in STEP_NAMES)
            + "<th>TY vs normal, all steps</th><th>LY base effect</th><th>Seasonality</th>"
            "<th>Exact DtD</th></tr></thead><tbody>" + "".join(trs) + "</tbody></table>"
            "<p class='note'>bps of the NA M1VFM day-to-day YoY change. Step cells: TY Tue/Mon "
            "for that funnel step vs its normal (median of 4 prior clean Mon/Tue pairs); red = TY "
            "weaker than normal, blue = stronger. Linear approximation, so the three parts sum to "
            "the exact DtD within a few bps.</p>")


def segment_section(pivot, base) -> str:
    out = []
    labels = {"lob_category": "Division (LOB)", "grt_l2": "Category (L2)",
              "platform": "Platform", "traffic_source": "Traffic source"}
    for dim in ("lob_category", "grt_l2", "platform", "traffic_source"):
        seg_rows = [r for r in pivot if r["dimension"] == dim]
        gb_total, gb = segment_bridge([Segment(dim, r["dim_value"], *pivot_vals(r, "gb")) for r in seg_rows])
        _, m1 = segment_bridge([Segment(dim, r["dim_value"], *pivot_vals(r, "m1vfm")) for r in seg_rows])
        m1_by = {b.segment: b for b in m1}
        trs = []
        for b in gb[:8]:
            if abs(b.delta) < 0.0005:
                continue
            m = m1_by[b.segment]
            bl_ty = base.get((b.segment, "TY"), {}).get("orders_dod_pct")
            bl_ly = base.get((b.segment, "LY"), {}).get("gb_dod_pct")
            ty_txt = f"{pct(bl_ty[0])} ({pct(bl_ty[1])})" if bl_ty else "–"
            ly_txt = f"{pct(bl_ly[0])} ({pct(bl_ly[1])})" if bl_ly else "–"
            trs.append(f"<tr><td>{esc(b.segment)}</td><td>{pct(b.yoy_d1)} → {pct(b.yoy_d)}</td>"
                       f"<td class='{sign_class(b.delta)}'><b>{bps(b.delta)}</b></td>"
                       f"<td class='{sign_class(m.delta)}'>{bps(m.delta)}</td>"
                       f"<td>{ty_txt}</td><td>{ly_txt}</td></tr>")
        out.append(f"<h3>{labels[dim]}</h3><table class='num'><thead><tr><th>Segment</th>"
                   "<th>GB YoY Mon → Tue</th><th>GB DtD (bps)</th><th>M1VFM DtD (bps)</th>"
                   "<th>TY orders Tue/Mon (normal)</th><th>LY GB Tue/Mon (normal)</th>"
                   "</tr></thead><tbody>" + "".join(trs) + "</tbody></table>")
    return "".join(out)


def hourly_section() -> str:
    data = rows("ue_hourly_orders_by_platform.csv")
    blocks = {"00–11 UTC": range(0, 12), "12–15 UTC (JPROD-969 window)": range(12, 16),
              "16–23 UTC": range(16, 24)}
    trs = []
    for pf in ("app", "touch", "web", "ALL"):
        for name, hrs in blocks.items():
            s = [0, 0, 0, 0]
            for r in data:
                if (pf == "ALL" or r["platform"] == pf) and int(r["hour_utc"]) in hrs:
                    for i, b in enumerate(BUCKETS):
                        s[i] += int(r[f"ord_{b}"])
            ty, ly = s[2] / s[0] - 1, s[3] / s[1] - 1
            y1, y2 = s[0] / s[1] - 1, s[2] / s[3] - 1
            trs.append(f"<tr><td>{'NA' if pf == 'ALL' else pf}</td><td>{name}</td>"
                       f"<td class='{sign_class(ty, 0.03)}'>{pct(ty)}</td><td>{pct(ly)}</td>"
                       f"<td>{pct(y1)}</td><td>{pct(y2)}</td>"
                       f"<td class='{sign_class(y2 - y1)}'>{bps(y2 - y1)}</td></tr>")
    return ("<table class='num'><thead><tr><th>Platform</th><th>Hours</th><th>TY Tue/Mon</th>"
            "<th>LY Tue/Mon</th><th>Orders YoY Mon</th><th>Orders YoY Tue</th><th>DtD (bps)</th>"
            "</tr></thead><tbody>" + "".join(trs) + "</tbody></table>")


def checkout_section() -> str:
    path = os.path.join(DATA, "checkout_funnel_platform.csv")
    if not os.path.exists(path):
        return ("<p class='callout'>UV, buy-button clicks and checkout steps are not in UNAGI. "
                "Their sources (superfunnel, checkout conversion, product funnel) are not "
                "queryable from FoundryAI today; see follow-up F10.</p>")
    return open(path.replace(".csv", ".html")).read() if os.path.exists(path.replace(".csv", ".html")) else ""


CSS = """
:root {
  color-scheme: light;
  --page: #f9f9f7; --surface-1: #fcfcfb; --ink: #0b0b0b; --ink-2: #52514e; --muted: #898781;
  --grid: #e1e0d9; --axis: #c3c2b7; --border: rgba(11,11,11,0.10);
  --series-1: #2a78d6; --series-2: #eb6834; --series-3: #1baf7a; --ink-series: #0b0b0b;
  --div-pos: #2a78d6; --div-neg: #e34948; --div-mid: #f0efec;
  --good: #006300; --bad: #b42626;
}
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) {
    color-scheme: dark;
    --page: #0d0d0d; --surface-1: #1a1a19; --ink: #ffffff; --ink-2: #c3c2b7; --muted: #898781;
    --grid: #2c2c2a; --axis: #383835; --border: rgba(255,255,255,0.10);
    --series-1: #3987e5; --series-2: #d95926; --series-3: #199e70; --ink-series: #ffffff;
    --div-pos: #3987e5; --div-neg: #e66767; --div-mid: #383835;
    --good: #0ca30c; --bad: #e66767;
  }
}
:root[data-theme="dark"] {
  color-scheme: dark;
  --page: #0d0d0d; --surface-1: #1a1a19; --ink: #ffffff; --ink-2: #c3c2b7; --muted: #898781;
  --grid: #2c2c2a; --axis: #383835; --border: rgba(255,255,255,0.10);
  --series-1: #3987e5; --series-2: #d95926; --series-3: #199e70; --ink-series: #ffffff;
  --div-pos: #3987e5; --div-neg: #e66767; --div-mid: #383835;
  --good: #0ca30c; --bad: #e66767;
}
* { box-sizing: border-box; }
body { margin: 0; background: var(--page); color: var(--ink);
  font: 15px/1.5 system-ui, -apple-system, "Segoe UI", sans-serif; }
main { max-width: 1180px; margin: 0 auto; padding: 24px 16px 64px; }
h1 { font-size: 26px; margin: 0 0 4px; }
h2 { font-size: 19px; margin: 36px 0 8px; }
h3 { font-size: 15px; margin: 20px 0 6px; color: var(--ink-2); }
h4 { font-size: 14px; margin: 0 0 4px; }
p, li { max-width: 78ch; }
.sub { color: var(--ink-2); margin: 0 0 16px; }
.card { background: var(--surface-1); border: 1px solid var(--border); border-radius: 10px;
  padding: 16px 18px; margin: 12px 0; overflow-x: auto; }
.answer { border-left: 4px solid var(--series-2); }
.tiles { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 12px; margin: 16px 0; }
.tile { background: var(--surface-1); border: 1px solid var(--border); border-radius: 10px; padding: 12px 14px; }
.tile-label { color: var(--ink-2); font-size: 13px; }
.tile-value { font-size: 28px; font-weight: 650; }
.tile-sub { color: var(--ink-2); font-size: 13px; }
table { border-collapse: collapse; width: 100%; font-size: 13px; }
th, td { padding: 5px 8px; border-bottom: 1px solid var(--grid); text-align: left; vertical-align: top; }
th { color: var(--ink-2); font-weight: 600; }
table.num td:not(:first-child), table.num th:not(:first-child) { text-align: right; font-variant-numeric: tabular-nums; }
tr.total td { font-weight: 600; background: color-mix(in oklab, var(--grid) 35%, transparent); }
.pos { color: var(--good); } .neg { color: var(--bad); }
td.heat { color: var(--ink); text-align: center !important; font-variant-numeric: tabular-nums; }
.funnel td span { display: block; } .funnel .share { font-size: 12px; }
.note { color: var(--muted); font-size: 12.5px; }
.callout { background: color-mix(in oklab, var(--series-2) 10%, var(--surface-1)); border-radius: 8px; padding: 10px 12px; }
.chart { width: 100%; height: auto; display: block; }
.chart .grid { stroke: var(--grid); stroke-width: 1; }
.chart .axis { stroke: var(--axis); stroke-width: 1; }
.chart .tick { fill: var(--muted); font-size: 11px; }
.chart .dlabel, .chart .vlabel { fill: var(--ink); font-size: 12px; }
.chart .rlabel { fill: var(--ink-2); font-size: 12px; }
.chart .hit { fill: transparent; }
.legend { display: flex; gap: 16px; flex-wrap: wrap; font-size: 13px; color: var(--ink-2); margin: 4px 0 8px; }
.legend i { display: inline-block; width: 12px; height: 3px; border-radius: 2px; margin-right: 6px; vertical-align: middle; }
.bars-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 12px; margin-bottom: 12px; }
details summary { cursor: pointer; color: var(--ink-2); font-size: 13px; margin-top: 6px; }
ul.tight li { margin: 3px 0; }
code { font-size: 12.5px; }
"""


def build() -> str:
    ue = load_ue_daily()
    pivot = load_pivot()
    base = baseline()
    tiles, k = headline(ue)
    base_html, be = base_effect_section(pivot, base)
    m1 = be["M1VFM"]["pp"]
    body = f"""
<main>
<h1>NA YoY bridge: Tue 22 Sep 2026</h1>
<p class="sub">Why NA YoY stepped down from Mon 9/21 to Tue 9/22, and what follows. LY = date − 364
(Tue 2025-09-23, Mon 2025-09-22). DtD = YoY(D) − YoY(D-1). Sources: unit economics (UE) and UNAGI
via FoundryAI BigQuery; built {dt.date.today().isoformat()}.</p>
{tiles}

<div class="card answer">
<h2 style="margin-top:0">The answer</h2>
<ul class="tight">
<li><b>Mostly an LY base effect.</b> Both years ran an ILS-stack Monday and an order-discount
Tuesday, but LY's OD Tuesday was ~2.2× bigger (~$1.07M vs ~$0.49M GB on OD campaigns), and LY's
Monday was weak (−7.1% orders vs the previous Monday). The LY base effect is
<b>{bps(m1['ly_abnormal_base_effect'])} bps</b> of the {bps(be['M1VFM']['delta_pp'])} bps M1VFM DtD
(UNAGI basis; UE shows {bps(k['M1VFM'][1] - k['M1VFM'][0])} bps).</li>
<li><b>TY Tuesday was not weak against its own last week:</b> M1VFM +1.0% and orders +1.5% vs Tue
9/15. Against the normal Mon→Tue pattern TY looks {bps(m1['ty_abnormal'])} bps weaker, but part of
that is a strong TY Monday (touch orders +16.9% vs the previous Monday).</li>
<li><b>Where TY does look soft (funnel):</b> conversion (orders/UDV) on touch and app Direct, Non-Brand
SEM impressions on app and touch (a Mon→Tue drop that has recurred three weeks running), and
app push impressions. Higher AOV (Travel) offsets most of it.</li>
<li><b>Not the driver:</b> JPROD-969 (Orders Index API 404s, 11:42–15:10 UTC) is only ~1.4pp worse
than the hours after it.</li>
</ul>
</div>

<h2>1. Daily M1VFM YoY, last 9 days</h2>
<div class="card">{trend_section(ue)}
<p class="note">9/17–9/21 ran hot (HBW billings push from 9/18, EOQ campaigns). Tue 9/22 is back near
the 9/14–9/16 run rate. Source: UE, NA, operational columns.</p></div>

<h2>2. Base effect vs TY: the headline bridge</h2>
<div class="card">{base_html}
<p class="note">Normal = median Tue/Mon change of the four previous clean Mon/Tue pairs (8/10, 8/17,
8/24, 9/14; Labor Day weeks excluded). Log split allocated pro rata; parts sum to the DtD.</p></div>

<h2>3. Week-over-week check: weak Tuesday, hot Monday, or LY comp?</h2>
<div class="card">{wow_section(ue)}
<p class="note">Same weekday one week earlier. TY Tuesday grew slightly vs the previous Tuesday on every
platform; the swing sits in LY (weak Monday, strong OD Tuesday). Touch's Tue/Mon drop is mostly a hot TY
Monday. Caveat: 9/14–9/15 were themselves hit by reCAPTCHA blocks (JPROD-955/957), so WoW may flatter TY.</p></div>

<h2>4. Funnel by platform and traffic source</h2>
<div class="card"><h3 style="margin-top:0">Impressions → UDV → orders → GB → M1VFM, YoY Mon → Tue</h3>
{funnel_levels_section()}</div>
<div class="card"><h3 style="margin-top:0">Which funnel step is abnormal this year? (TY Tue/Mon vs normal, bps of NA M1VFM DtD)</h3>
{funnel_vs_normal_section()}</div>
<div class="card"><h3 style="margin-top:0">UV → buy-button click → checkout → order</h3>
{checkout_section()}</div>

<h2>5. Segment bridge (UNAGI)</h2>
<div class="card">{segment_section(pivot, base)}
<p class="note">GB and M1VFM DtD in bps of NA YoY. TY/LY Tue/Mon columns come from
the Mon/Tue baseline (normal in brackets); "–" where no baseline was pulled.</p></div>

<h2>6. Hourly orders (UE)</h2>
<div class="card">{hourly_section()}</div>

<h2>7. Outcomes and follow-ups</h2>
<div class="card"><ul class="tight">
<li><b>Base effect (no business action):</b> annotate 9/22 in the Daily Monitoring doc; pre-compute the LY
promo calendar for 9/23–9/30 so LY OD/ILS days are flagged before they read as deterioration (F1).</li>
<li><b>Decision:</b> TY's Tuesday OD push was about half of LY's. Confirm that was intended (margin discipline)
and size the GB vs M1VFM trade-off for the October exit rate (F11).</li>
<li><b>Mobile conversion:</b> touch CVR −9.0% Tue/Mon vs +1.6% normal. Check whether it is TY Monday strength
(reCAPTCHA iOS fix live 9/20 17:28) or a Tuesday checkout issue. Needs checkout-step data (F2, F10).</li>
<li><b>Non-Brand SEM:</b> impressions −8% Tue/Mon on app and touch, the third week in a row. Likely a weekday
bidding or budget pattern, not a 9/22 incident; confirm with the SEM team alongside the campaign migration (F3).</li>
<li><b>App push:</b> impressions −9.7% Tue/Mon vs +1% normal. Check push send volume on 9/22 (new).</li>
<li><b>TTD Leisure / Core Local:</b> review the losing attractions deals at the Top Supply meeting (F4).</li>
<li><b>Re-run 9/24</b> once pending authorizations settle ($36K on 9/22) and watch 9/23–9/25 for recovery (F7, F8).</li>
</ul>
<p class="note">Full register with owners and due dates: FOLLOWUPS.md in the repo.</p></div>

<h2>8. Data and caveats</h2>
<div class="card"><ul class="tight">
<li>UE: <code>kbc-grpn-35.out_c_ue_location_and_ownership.unit_economics</code> (behind
<code>finance_unit_economics.unit_economics</code>). UNAGI: <code>kbc-grpn-35.out_c_unagi.unagi</code>.
The dataview views deny query access to the FoundryAI connector, so the source tables were queried directly.</li>
<li>UE ties to the Daily Monitoring doc for 9/21 (M1VFM +5.5% vs +5.4%; GB +13.0% vs +13%). UNAGI ties to UE
within ~0.6%.</li>
<li>UNAGI orders are counted at deal × platform × channel grain (multi-deal orders count more than once), and
channel attribution on the traffic side may differ from the order side.</li>
<li>$36K GB on 9/22 was still in pending authorization at extraction (±1.1pp on D).</li>
<li>Not queryable today: superfunnel (UV, buy-button clicks), checkout conversion, ad spend, email/push sends.</li>
</ul></div>
</main>"""
    return ("<!doctype html><html lang='en'><head><meta charset='utf-8'>"
            "<meta name='viewport' content='width=device-width, initial-scale=1'>"
            "<title>NA YoY Bridge 22 Sep</title><style>" + CSS + "</style></head><body>"
            + body + "</body></html>")


if __name__ == "__main__":
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w") as f:
        f.write(build())
    print(OUT)
