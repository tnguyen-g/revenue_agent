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
   metric = traffic x CVR x AOV  (orders = traffic x CVR, GB = orders x AOV)
   ln(TY/LY) = ln(traffic ratio) + ln(CVR ratio) + ln(AOV ratio)
   The day-to-day change of each log term is allocated pro rata to the
   total change in YoY (pp). The same split is shown as
   TY day-over-day vs LY day-over-day to separate "TY got weaker" from
   "LY comp got tougher".

Input CSV columns (segment mode):
    dimension,segment,ty_d1,ly_d1,ty_d,ly_d
Input CSV columns (driver mode):
    component,ty_d1,ly_d1,ty_d,ly_d        # components: traffic, orders, gb

Usage:
    python tools/yoy_bridge.py segments data.csv [--dimension platform]
    python tools/yoy_bridge.py drivers drivers.csv
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
    """components: name -> (ty_d1, ly_d1, ty_d, ly_d) for traffic, orders, gb."""
    t, o, g = components["traffic"], components["orders"], components["gb"]

    def ratios(i_ty: int, i_ly: int) -> dict[str, float]:
        traffic = t[i_ty] / t[i_ly]
        cvr = (o[i_ty] / t[i_ty]) / (o[i_ly] / t[i_ly])
        aov = (g[i_ty] / o[i_ty]) / (g[i_ly] / o[i_ly])
        return {"traffic": traffic, "cvr": cvr, "aov": aov}

    r1, r2 = ratios(0, 1), ratios(2, 3)
    yoy_d1, yoy_d = g[0] / g[1] - 1, g[2] / g[3] - 1
    delta_pp = yoy_d - yoy_d1
    log_delta = {k: math.log(r2[k]) - math.log(r1[k]) for k in r1}
    log_total = sum(log_delta.values())
    alloc = {k: (v / log_total * delta_pp if log_total else 0.0)
             for k, v in log_delta.items()}

    # TY day-over-day vs LY day-over-day (log), GB only.
    ty_dod = math.log(g[2] / g[0])
    ly_dod = math.log(g[3] / g[1])
    return {
        "yoy_d1": yoy_d1, "yoy_d": yoy_d, "delta_pp": delta_pp,
        "yoy_by_driver_d1": {k: v - 1 for k, v in r1.items()},
        "yoy_by_driver_d": {k: v - 1 for k, v in r2.items()},
        "delta_pp_by_driver": alloc,
        "ty_dod_log": ty_dod, "ly_dod_log": ly_dod,
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


def format_driver_bridge(res: dict) -> str:
    lines = [
        "### Driver bridge (GB = traffic x CVR x AOV)",
        "",
        f"GB YoY D-1 {_pct(res['yoy_d1'])} -> D {_pct(res['yoy_d'])} "
        f"(change {_pp(res['delta_pp'])})",
        "",
        "| driver | YoY D-1 | YoY D | share of change |",
        "|---|---:|---:|---:|",
    ]
    for k in ("traffic", "cvr", "aov"):
        lines.append(f"| {k} | {_pct(res['yoy_by_driver_d1'][k])} | "
                     f"{_pct(res['yoy_by_driver_d'][k])} | {_pp(res['delta_pp_by_driver'][k])} |")
    lines += [
        "",
        f"TY day-over-day (log) {res['ty_dod_log'] * 100:+.1f}% vs "
        f"LY day-over-day (log) {res['ly_dod_log'] * 100:+.1f}% "
        "-> the YoY change is TY DoD minus LY DoD.",
    ]
    return "\n".join(lines)


def _read_segments(path: str) -> list[Segment]:
    with open(path, newline="") as f:
        return [Segment(r["dimension"], r["segment"], float(r["ty_d1"]), float(r["ly_d1"]),
                        float(r["ty_d"]), float(r["ly_d"])) for r in csv.DictReader(f)]


def _read_drivers(path: str) -> dict[str, tuple[float, float, float, float]]:
    with open(path, newline="") as f:
        return {r["component"]: (float(r["ty_d1"]), float(r["ly_d1"]),
                                 float(r["ty_d"]), float(r["ly_d"]))
                for r in csv.DictReader(f)}


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = p.add_subparsers(dest="mode", required=True)
    s = sub.add_parser("segments")
    s.add_argument("csv")
    s.add_argument("--dimension", help="only bridge this dimension")
    d = sub.add_parser("drivers")
    d.add_argument("csv")
    args = p.parse_args(argv)

    if args.mode == "segments":
        rows = _read_segments(args.csv)
        dims = [args.dimension] if args.dimension else sorted({r.dimension for r in rows})
        for dim in dims:
            total, bridge = segment_bridge([r for r in rows if r.dimension == dim])
            print(format_segment_bridge(dim, total, bridge))
            print()
    else:
        print(format_driver_bridge(driver_bridge(_read_drivers(args.csv))))
    return 0


if __name__ == "__main__":
    sys.exit(main())
