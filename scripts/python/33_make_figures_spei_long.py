#!/usr/bin/env python3
"""File:    33_make_figures_spei_long.py
Purpose: Publication artifacts for the long-baseline SPEI design:
         (1) the memo's 0.5-SD bin coefficient path on g_IndVA (ten bins,
             reference (-0.5, 0]) -- the diagnostic used to choose cutoffs;
         (2) a binned comparison of SPEI3 under the two calibration windows on
             the estimation sample, quantifying how 1940-2025 moves the index;
         (3) the linear-spline segment-slope table (Specification B, preferred
             form), built from the lincom exports of 32_spei_long_design.do.
Inputs:  output/intermediates/spei_long_bins.csv    (do-file, section (a))
         output/intermediates/spei_long_spline.csv  (do-file, section (c))
         output/intermediates/real_panel_spei_long.csv (panel for the comparison)
Outputs: output/figures/fig_spei_long_bins05.{pdf,png}
         output/figures/fig_spei_long_window_compare.{pdf,png}
         output/tables/spei_long_spline.tex
Notes:   Project palette only (INV-1/INV-15); PDF is vector, PNG is 300 dpi
         transparent. Paths are repo-root-relative (INV-14). No randomness.
"""
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

REPO = Path(__file__).resolve().parents[2]
BINS = REPO / "output" / "intermediates" / "spei_long_bins.csv"
SPLINE = REPO / "output" / "intermediates" / "spei_long_spline.csv"
PANEL = REPO / "output" / "intermediates" / "real_panel_spei_long.csv"
FIGDIR = REPO / "output" / "figures"
TABDIR = REPO / "output" / "tables"

PALETTE = {
    "blue": "#012169",
    "gold": "#B9975B",
    "neutral": "#525252",
    "jet": "#1A1A1A",
}

plt.rcParams.update({
    "font.size": 11,
    "axes.titlesize": 12,
    "axes.labelsize": 11,
    "legend.fontsize": 9,
    "axes.edgecolor": PALETTE["jet"],
    "axes.labelcolor": PALETTE["jet"],
    "xtick.color": PALETTE["jet"],
    "ytick.color": PALETTE["jet"],
    "figure.facecolor": "white",
    "axes.facecolor": "white",
    "savefig.facecolor": "white",
})

BIN_LABELS = ["≤-2", "(-2,-1.5]", "(-1.5,-1]", "(-1,-.5]", "(-.5,0]",
              "(0,.5]", "(.5,1]", "(1,1.5]", "(1.5,2]", ">2"]
REF_BIN = 5   # (-0.5, 0], omitted category in the regression


def _despine(ax):
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)


def _save(fig, stem):
    FIGDIR.mkdir(parents=True, exist_ok=True)
    fig.savefig(FIGDIR / f"{stem}.pdf", bbox_inches="tight")
    fig.savefig(FIGDIR / f"{stem}.png", dpi=300, transparent=True,
                bbox_inches="tight")
    plt.close(fig)


def make_bins_plot() -> None:
    b = pd.read_csv(BINS)
    assert len(b) == 9, f"expected 9 exported bins, got {len(b)}"

    # Rebuild the 10-bin axis with the reference bin at exactly zero.
    coef = np.zeros(10)
    se = np.full(10, np.nan)
    coef[b["bin"].to_numpy() - 1] = b["b"]
    se[b["bin"].to_numpy() - 1] = b["se"]

    x = np.arange(1, 11)
    fig, ax = plt.subplots(figsize=(7.8, 4.7))
    ax.axhline(0.0, color=PALETTE["neutral"], linewidth=1.0, zorder=1)
    ax.axvline(REF_BIN, color=PALETTE["neutral"], linewidth=0.8,
               linestyle=":", zorder=1)
    ax.errorbar(x, coef, yerr=1.96 * se, fmt="o", color=PALETTE["blue"],
                ecolor=PALETTE["blue"], capsize=4, markersize=6, zorder=3)
    ax.plot(REF_BIN, 0.0, marker="s", color=PALETTE["gold"], markersize=6,
            zorder=4)
    ax.set_xticks(x)
    ax.set_xticklabels(BIN_LABELS, fontsize=8.5)
    ax.set_xlabel("SPEI3, long-baseline (1940–2025), 0.5-unit bins")
    ax.set_ylabel("Effect on industrial VA growth (fraction)")
    ax.set_title("0.5-SD bin path, reference bin (-0.5, 0] (gold)")
    _despine(ax)
    _save(fig, "fig_spei_long_bins05")


def make_window_compare() -> None:
    df = pd.read_csv(PANEL)
    s = df[(df["year"] >= 2002) & (~df["month"].isin([1, 2]))
           & df["g_IndVA"].notna()][["SPEI3", "SPEI3_L"]].dropna()

    edges = np.arange(-5.0, 2.51, 0.5)
    s = s.assign(bin=pd.cut(s["SPEI3"], edges, include_lowest=True))
    g = (s.groupby("bin", observed=True)
         .agg(old=("SPEI3", "mean"), new=("SPEI3_L", "mean"),
              new_sd=("SPEI3_L", "std"), n=("SPEI3_L", "size"))
         .dropna().reset_index())
    g["ci"] = 1.96 * g["new_sd"] / np.sqrt(g["n"])
    g["mid"] = g["bin"].apply(lambda iv: iv.mid)

    lim = (-3.2, 1.6)
    fig, ax = plt.subplots(figsize=(6.4, 5.6))
    ax.plot(lim, lim, color=PALETTE["neutral"], linewidth=1.0, linestyle="--",
            zorder=1, label="45° line")
    ax.errorbar(g["old"], g["new"], yerr=g["ci"], fmt="o",
                color=PALETTE["blue"], ecolor=PALETTE["blue"], capsize=3,
                markersize=6, zorder=3, label="0.5-unit bins of old SPEI3")
    ax.set_xlim(lim)
    ax.set_ylim(lim)
    ax.set_xlabel("SPEI3, old baseline (2000–2026)")
    ax.set_ylabel("SPEI3, long baseline (1940–2025)")
    ax.set_title("Calibration window: old vs new SPEI3, 2002–2026")
    ax.legend(frameon=False, loc="upper left")
    _despine(ax)
    _save(fig, "fig_spei_long_window_compare")


def _stars(b: float, se: float) -> str:
    if not np.isfinite(se) or se == 0:
        return ""
    t = abs(b / se)
    if t > 2.576:
        return r"\sym{***}"
    if t > 1.960:
        return r"\sym{**}"
    if t > 1.645:
        return r"\sym{*}"
    return ""


def make_spline_table() -> None:
    s = pd.read_csv(SPLINE)
    assert len(s) == 36, f"expected 36 spline rows, got {len(s)}"
    seg_labels = [r"$\leq -1.5$", r"$(-1.5, -1]$", r"$(-1, 0]$",
                  r"$(0, 1]$", r"$(1, 1.5]$", r"$> 1.5$"]

    def cell(scale, seg, hydro):
        r = s[(s["scale"] == scale) & (s["segment"] == seg)
              & (s["hydro"] == hydro)].iloc[0]
        return f"{r['b']:.4f}{_stars(r['b'], r['se'])}", f"({r['se']:.4f})"

    lines = [
        r"{",
        r"\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}",
        r"\begin{tabular}{l*{6}{c}}",
        r"\toprule",
        r" & \multicolumn{2}{c}{SPEI1} & \multicolumn{2}{c}{SPEI3} "
        r"& \multicolumn{2}{c}{SPEI6} \\",
        r"\cmidrule(lr){2-3}\cmidrule(lr){4-5}\cmidrule(lr){6-7}",
        r"SPEI range & Slope & Hydro $+1$SD & Slope & Hydro $+1$SD "
        r"& Slope & Hydro $+1$SD \\",
        r"\midrule",
    ]
    for j, lab in enumerate(seg_labels, start=1):
        coef_cells = []
        se_cells = []
        for scale in (1, 3, 6):
            for hydro in (0, 1):
                b, se = cell(scale, j, hydro)
                coef_cells.append(b)
                se_cells.append(se)
        lines.append(" & ".join([lab] + coef_cells) + r" \\")
        lines.append(" & ".join([""] + se_cells) + r" \\")
        if j < 6:
            lines.append(r"\addlinespace")
    lines += [
        r"\midrule",
        r"Observations & \multicolumn{6}{c}{6,975} \\",
        r"\bottomrule",
        r"\multicolumn{7}{l}{\footnotesize SEs in parentheses, clustered at "
        r"province level (29 clusters).} \\",
        r"\multicolumn{7}{l}{\footnotesize Segment slopes from a continuous "
        r"linear spline with knots at -1.5, -1, 0, 1, 1.5.} \\",
        r"\multicolumn{7}{l}{\footnotesize ``Hydro $+1$SD'' adds the spline "
        r"$\times$ HydroShare(z) terms at HydroShare(z) = 1.} \\",
        r"\multicolumn{7}{l}{\footnotesize DV: g\_IndVA. FE: province + "
        r"year-month. Sample: Mar-Dec 2002-2026.} \\",
        r"\multicolumn{7}{l}{\footnotesize * p$<$0.10, ** p$<$0.05, "
        r"*** p$<$0.01.} \\",
        r"\end{tabular}",
        r"}",
        "",
    ]
    TABDIR.mkdir(parents=True, exist_ok=True)
    (TABDIR / "spei_long_spline.tex").write_text("\n".join(lines))
    print(f"[done] spei_long_spline.tex ({len(s)} slope cells)")


def main() -> None:
    make_bins_plot()
    make_window_compare()
    make_spline_table()
    print("[done] figures: fig_spei_long_bins05, fig_spei_long_window_compare")


if __name__ == "__main__":
    main()
