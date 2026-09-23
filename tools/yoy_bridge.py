"""YoY bridge for a day-to-day change in YoY growth.

Explains why YoY growth on day D differs from YoY growth on day D-1
(e.g. Mon 2026-09-21 -> Tue 2026-09-22, each vs its DOW-aligned LY day,
date - 364).

Two views, both exact (components sum to the total change):

1. Segment bridge (additive, in percentage points)
   Contribution of segment i to total YoY on day t:
       c_i,t = (TY_i,t - LY_i,t) / LY_t          sum_i c_i,t = g_t
   Day-to-day change:
       dc_i = c_i,D - c_i,D-1                    sum_i dc_i = g_D - g_D-1
   Each dc_i is split (midpoint / 2-factor Shapley) into
       rate effect   = avg(w_i) * (g_i,D - g_i,D-1)   segment YoY changed
       LY-mix effect = avg(g_i) * (w_i,D - w_i,D-1)   LY base mix shifted
   where w_i,t = LY_i,t / LY_t is the segment's LY share. Segments with no LY
   on either day have no defined YoY, so their whole dc_i goes to "new/lost".

2. Driver bridge (multiplicative, log-additive)
   GB     = traffic x CVR x AOV          (orders = traffic x CVR, GB = orders x AOV)
   M1VFM  = traffic x CVR x AOV x margin (margin = M1VFM / GB), when a value
            component such as M1VFM is supplied
   ln(TY/LY) = sum of ln(driver ratio)
   The day-to-day change of each log term is allocated pro rata to the
   total change in YoY (pp). The same split is shown as
   TY day-over-day vs LY day-over-day to separate "TY got weaker" from
   "LY comp got tougher".

3. Base-effect split (needs "normal" DoD from 03_unagi_mon_tue_baseline.sql)
   ln(1+g_D) - ln(1+g_D-1) = ln(TY DoD) - ln(LY DoD)
     = [ln TY DoD - ln TY normal]        TY abnormal: TY itself got weaker
     - [ln LY DoD - ln LY normal]        LY abnormal: base effect (LY spike)
     + [ln TY normal - ln LY normal]     normal DOW seasonality drift
   allocated pro rata to the pp change, like the driver bridge.

Input CSV columns (segment mode):
    dimension,segment,ty_d1,ly_d1,ty_d,ly_d
Input CSV columns (driver mode):
    component,ty_d1,ly_d1,ty_d,ly_d        # traffic, orders, gb [, value]

Pivoted query output (the sql/ files in analyses/) is read directly with
--metric: columns dimension, dim_value, <metric>_ty_d1, <metric>_ly_d1,
<metric>_ty_d, <metric>_ly_d; the dimension='total' row feeds driver mode.

Usage:
    python tools/yoy_bridge.py segments data.csv [--dimension platform]
    python tools/yoy_bridge.py segments pivot.csv --metric gb
    python tools/yoy_bridge.py drivers drivers.csv
    python tools/yoy_bridge.py drivers pivot.csv --traffic udv --orders ord --gb gb [--value m1vfm]
"""

from __future__ import annotations

import argparse
import csv
import math
import sys
from dataclasses import dataclass


@dataclass
class Segment:
    dimension: str
    segment: str
    ty_d1: float
    ly_d1: float
    ty_d: float
    ly_d: float


@dataclass
class SegmentBridge:
    segment: str
    ty_d1: float
    ly_d1: float
    ty_d: float
    ly_d: float
    yoy_d1: float | None
    yoy_d: float | None
    contrib_d1: float
    contrib_d: float
    delta: float
    rate_effect: float
    mix_effect: float
    new_lost: float


def _yoy(ty: float, ly: float) -> float | None:
    return ty / ly - 1 if ly else None


def segment_bridge(rows: list[Segment]) -> tuple[dict, list[SegmentBridge]]:
    """Bridge one dimension. All rows must belong to the same dimension and
    together cover the total (include an 'other' row if needed)."""
    ly_tot_d1 = sum(r.ly_d1 for r in rows)
    ly_tot_d = sum(r.ly_d for r in rows)
    ty_tot_d1 = sum(r.ty_d1 for r in rows)
    ty_tot_d = sum(r.ty_d for r in rows)
    if not ly_tot_d1 or not ly_tot_d:
        raise ValueError("LY total is zero on one of the days; YoY undefined")

    out = []
    for r in rows:
        c1 = (r.ty_d1 - r.ly_d1) / ly_tot_d1
        c2 = (r.ty_d - r.ly_d) / ly_tot_d
        delta = c2 - c1
        g1, g2 = _yoy(r.ty_d1, r.ly_d1), _yoy(r.ty_d, r.ly_d)
        if g1 is None or g2 is None:
            rate = mix = 0.0
            new_lost = delta
        else:
            w1, w2 = r.ly_d1 / ly_tot_d1, r.ly_d / ly_tot_d
            rate = (w1 + w2) / 2 * (g2 - g1)
            mix = (g1 + g2) / 2 * (w2 - w1)
            new_lost = 0.0
        out.append(SegmentBridge(r.segment, r.ty_d1, r.ly_d1, r.ty_d, r.ly_d,
                                 g1, g2, c1, c2, delta, rate, mix, new_lost))

    total = {
        "ty_d1": ty_tot_d1, "ly_d1": ly_tot_d1, "ty_d": ty_tot_d, "ly_d": ly_tot_d,
        "yoy_d1": ty_tot_d1 / ly_tot_d1 - 1,
        "yoy_d": ty_tot_d / ly_tot_d - 1,
    }
    total["delta"] = total["yoy_d"] - total["yoy_d1"]
    out.sort(key=lambda b: abs(b.delta), reverse=True)
    return total, out


def driver_bridge(components: dict[str, tuple[float, float, float, float]]) -> dict:
    """components: name -> (ty_d1, ly_d1, ty_d, ly_d) for traffic, orders, gb
    and optionally value (e.g. M1VFM). The bridged metric is value if given,
    else gb."""
    t, o, g = components["traffic"], components["orders"], components["gb"]
    v = components.get("value")
    target = v if v is not None else g

    def ratios(i_ty: int, i_ly: int) -> dict[str, float]:
        r = {
            "traffic": t[i_ty] / t[i_ly],
            "cvr": (o[i_ty] / t[i_ty]) / (o[i_ly] / t[i_ly]),
            "aov": (g[i_ty] / o[i_ty]) / (g[i_ly] / o[i_ly]),
        }
        if v is not None:
            r["margin"] = (v[i_ty] / g[i_ty]) / (v[i_ly] / g[i_ly])
        return r

    r1, r2 = ratios(0, 1), ratios(2, 3)
    yoy_d1, yoy_d = target[0] / target[1] - 1, target[2] / target[3] - 1
    delta_pp = yoy_d - yoy_d1
    log_delta = {k: math.log(r2[k]) - math.log(r1[k]) for k in r1}
    log_total = sum(log_delta.values())
    alloc = {k: (x / log_total * delta_pp if log_total else 0.0)
             for k, x in log_delta.items()}

    # TY day-over-day vs LY day-over-day (log) of the bridged metric.
    ty_dod = math.log(target[2] / target[0])
    ly_dod = math.log(target[3] / target[1])
    return {
        "metric": "value" if v is not None else "gb",
        "yoy_d1": yoy_d1, "yoy_d": yoy_d, "delta_pp": delta_pp,
        "yoy_by_driver_d1": {k: x - 1 for k, x in r1.items()},
        "yoy_by_driver_d": {k: x - 1 for k, x in r2.items()},
        "delta_pp_by_driver": alloc,
        "ty_dod_log": ty_dod, "ly_dod_log": ly_dod,
    }


def base_effect_split(ty_d1: float, ly_d1: float, ty_d: float, ly_d: float,
                      ty_normal_dod: float, ly_normal_dod: float) -> dict:
    """Split the D-1 -> D change in YoY into TY abnormal, LY abnormal (base
    effect) and normal seasonality, given the normal day-over-day change for
    TY and LY (e.g. the median Mon -> Tue change over recent clean weeks)."""
    delta_pp = (ty_d / ly_d) - (ty_d1 / ly_d1)
    ty_dod, ly_dod = math.log(ty_d / ty_d1), math.log(ly_d / ly_d1)
    ty_n, ly_n = math.log(1 + ty_normal_dod), math.log(1 + ly_normal_dod)
    parts = {
        "ty_abnormal": ty_dod - ty_n,
        "ly_abnormal_base_effect": -(ly_dod - ly_n),
        "normal_seasonality": ty_n - ly_n,
    }
    total = sum(parts.values())
    return {
        "delta_pp": delta_pp,
        "ty_dod": ty_d / ty_d1 - 1, "ly_dod": ly_d / ly_d1 - 1,
        "ty_normal_dod": ty_normal_dod, "ly_normal_dod": ly_normal_dod,
        "pp": {k: (v / total * delta_pp if total else 0.0) for k, v in parts.items()},
    }


def _pct(x: float | None) -> str:
    return "n/a" if x is None else f"{x * 100:+.1f}%"


def _pp(x: float) -> str:
    return f"{x * 100:+.2f}pp"


def format_segment_bridge(dimension: str, total: dict, rows: list[SegmentBridge]) -> str:
    lines = [
        f"### Bridge by {dimension}",
        "",
        f"Total YoY D-1 {_pct(total['yoy_d1'])} -> D {_pct(total['yoy_d'])} "
        f"(change {_pp(total['delta'])})",
        "",
        "| segment | YoY D-1 | YoY D | contrib D-1 | contrib D | change | rate effect | LY-mix effect | new/lost |",
        "|---|---:|---:|---:|---:|---:|---:|---:|---:|",
    ]
    for b in rows:
        lines.append(
            f"| {b.segment} | {_pct(b.yoy_d1)} | {_pct(b.yoy_d)} | {_pp(b.contrib_d1)} | "
            f"{_pp(b.contrib_d)} | {_pp(b.delta)} | {_pp(b.rate_effect)} | "
            f"{_pp(b.mix_effect)} | {_pp(b.new_lost)} |"
        )
    return "\n".join(lines)


def format_driver_bridge(res: dict, value_name: str = "value") -> str:
    metric = "GB" if res["metric"] == "gb" else value_name
    formula = "traffic x CVR x AOV" + (" x margin" if res["metric"] != "gb" else "")
    lines = [
        f"### Driver bridge ({metric} = {formula})",
        "",
        f"{metric} YoY D-1 {_pct(res['yoy_d1'])} -> D {_pct(res['yoy_d'])} "
        f"(change {_pp(res['delta_pp'])})",
        "",
        "| driver | YoY D-1 | YoY D | share of change |",
        "|---|---:|---:|---:|",
    ]
    for k in res["delta_pp_by_driver"]:
        lines.append(f"| {k} | {_pct(res['yoy_by_driver_d1'][k])} | "
                     f"{_pct(res['yoy_by_driver_d'][k])} | {_pp(res['delta_pp_by_driver'][k])} |")
    lines += [
        "",
        f"TY day-over-day (log) {res['ty_dod_log'] * 100:+.1f}% vs "
        f"LY day-over-day (log) {res['ly_dod_log'] * 100:+.1f}% "
        "-> the YoY change is TY DoD minus LY DoD.",
    ]
    return "\n".join(lines)


BUCKETS = ("ty_d1", "ly_d1", "ty_d", "ly_d")


def _num(x: str) -> float:
    return float(x) if x not in ("", None) else 0.0


def _read_segments(path: str, metric: str | None = None) -> list[Segment]:
    with open(path, newline="") as f:
        rows = list(csv.DictReader(f))
    if metric is None:
        return [Segment(r["dimension"], r["segment"], *(_num(r[b]) for b in BUCKETS))
                for r in rows]
    return [Segment(r["dimension"], r["dim_value"], *(_num(r[f"{metric}_{b}"]) for b in BUCKETS))
            for r in rows if r["dimension"] != "total"]


def _read_drivers(path: str, cols: dict[str, str] | None = None
                  ) -> dict[str, tuple[float, float, float, float]]:
    with open(path, newline="") as f:
        rows = list(csv.DictReader(f))
    if cols is None:
        return {r["component"]: tuple(_num(r[b]) for b in BUCKETS) for r in rows}
    total = next(r for r in rows if r["dimension"] == "total")
    return {comp: tuple(_num(total[f"{col}_{b}"]) for b in BUCKETS)
            for comp, col in cols.items() if col}


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = p.add_subparsers(dest="mode", required=True)
    s = sub.add_parser("segments")
    s.add_argument("csv")
    s.add_argument("--dimension", help="only bridge this dimension")
    s.add_argument("--metric", help="read pivoted query output, e.g. gb or m1vfm")
    d = sub.add_parser("drivers")
    d.add_argument("csv")
    d.add_argument("--traffic", help="pivot column prefix for traffic, e.g. udv")
    d.add_argument("--orders", help="pivot column prefix for orders, e.g. ord")
    d.add_argument("--gb", help="pivot column prefix for gross bookings, e.g. gb")
    d.add_argument("--value", help="optional pivot column prefix for the bridged value, e.g. m1vfm")
    d.add_argument("--label", help="display name of the value metric, e.g. M1VFM")
    args = p.parse_args(argv)

    if args.mode == "segments":
        rows = _read_segments(args.csv, args.metric)
        dims = [args.dimension] if args.dimension else sorted({r.dimension for r in rows})
        for dim in dims:
            total, bridge = segment_bridge([r for r in rows if r.dimension == dim])
            print(format_segment_bridge(dim, total, bridge))
            print()
    else:
        cols = None
        if args.traffic:
            cols = {"traffic": args.traffic, "orders": args.orders, "gb": args.gb,
                    "value": args.value}
        print(format_driver_bridge(driver_bridge(_read_drivers(args.csv, cols)),
                                   args.label or (args.value or "value").upper()))
    return 0


if __name__ == "__main__":
    sys.exit(main())
