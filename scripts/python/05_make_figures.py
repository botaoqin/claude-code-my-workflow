#!/usr/bin/env python3
"""File:    05_make_figures.py
Purpose: Publication figures for the mini-replication:
         (1) hydro share across bins of the drought index,
         (2) coefficient plot across specifications.
Inputs:  output/intermediates/synthetic_panel.csv
         output/intermediates/coefs.csv
Outputs: output/figures/fig_hydro_by_drought_bins.{pdf,png}
         output/figures/fig_coefplot.{pdf,png}
         (PDF = vector for papers; PNG = 300 dpi, transparent, for slides)
Notes:   Project palette only (INV-1/INV-15). No randomness is used, so no
         RNG is created (INV-13 applies only where randomness is used).
         All paths are repo-root-relative via REPO (INV-14).
"""
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

REPO = Path(__file__).resolve().parents[2]
PANEL = REPO / "output" / "intermediates" / "synthetic_panel.csv"
COEFS = REPO / "output" / "intermediates" / "coefs.csv"
FIGDIR = REPO / "output" / "figures"

PALETTE = {
    "blue": "#012169",     # primary-blue
    "gold": "#B9975B",     # primary-gold
    "neutral": "#525252",  # neutral
    "jet": "#1A1A1A",      # jet
}

plt.rcParams.update({
    "font.size": 11,
    "axes.titlesize": 12,
    "axes.labelsize": 11,
    "legend.fontsize": 10,
    "axes.edgecolor": PALETTE["jet"],
    "axes.labelcolor": PALETTE["jet"],
    "xtick.color": PALETTE["jet"],
    "ytick.color": PALETTE["jet"],
    "figure.facecolor": "white",
    "axes.facecolor": "white",
    "savefig.facecolor": "white",
})


def _despine(ax):
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)


def _save(fig, stem):
    FIGDIR.mkdir(parents=True, exist_ok=True)
    fig.savefig(FIGDIR / f"{stem}.pdf", bbox_inches="tight")
    fig.savefig(FIGDIR / f"{stem}.png", dpi=300, transparent=True,
                bbox_inches="tight")
    plt.close(fig)


def make_hydro_by_drought_bins(panel: pd.DataFrame) -> None:
    edges = np.quantile(panel["d"], np.linspace(0.0, 1.0, 21))
    binned = panel.assign(dbin=pd.cut(panel["d"], edges, include_lowest=True))
    grouped = (binned.groupby("dbin", observed=True)
               .agg(d=("d", "mean"), h=("h", "mean"))
               .dropna())

    fig, ax = plt.subplots(figsize=(7.5, 4.5))
    ax.scatter(grouped["d"], grouped["h"], s=60, color=PALETTE["blue"],
               zorder=3)
    ax.set_xlabel("Drought index (standardized)")
    ax.set_ylabel("Hydro share (0-1)")
    _despine(ax)
    _save(fig, "fig_hydro_by_drought_bins")


def make_coefplot(coefs: pd.DataFrame) -> None:
    h = coefs.loc[coefs["param"] == "h"].sort_values("spec")
    d = coefs.loc[coefs["param"] == "d"].sort_values("spec")

    fig, (ax1, ax2) = plt.subplots(
        1, 2, figsize=(7.5, 4.5), gridspec_kw={"width_ratios": [1.15, 1.0]}
    )

    # Panel A: hydro-share coefficient against the true value
    xs = np.arange(len(h))
    ax1.axhline(2.0, color=PALETTE["gold"], linestyle="--", linewidth=1.5)
    ax1.errorbar(xs, h["b"], yerr=1.96 * h["se"], fmt="o",
                 color=PALETTE["blue"], capsize=5, markersize=7, linewidth=1.8)
    ax1.text(1.5, 2.02, "True $\\theta = 2.0$", color=PALETTE["gold"],
             ha="center", va="bottom", fontsize=10)
    ax1.set_xticks(xs)
    ax1.set_xticklabels([f"({s})" for s in h["spec"]])
    ax1.set_xlim(-0.5, len(h) - 0.5)
    ax1.set_title("Hydro-share coefficient")
    ax1.set_xlabel("Specification")
    ax1.set_ylabel("Coefficient estimate")
    _despine(ax1)

    # Panel B: drought coefficient, total association vs direct effect
    xs = np.arange(len(d))
    ax2.axhline(0.0, color=PALETTE["neutral"], linewidth=1.2)
    ax2.errorbar(xs, d["b"], yerr=1.96 * d["se"], fmt="o",
                 color=PALETTE["gold"], capsize=5, markersize=7, linewidth=1.8)
    ax2.set_xticks(xs)
    ax2.set_xticklabels([f"({s})" for s in d["spec"]])
    ax2.set_xlim(-0.5, len(d) - 0.5)
    ax2.set_title("Drought coefficient")
    ax2.set_xlabel("Specification")
    ax2.set_ylabel("Coefficient estimate")
    _despine(ax2)

    fig.tight_layout()
    _save(fig, "fig_coefplot")


def main() -> None:
    make_hydro_by_drought_bins(pd.read_csv(PANEL))
    make_coefplot(pd.read_csv(COEFS))
    print(f"Wrote figures to {FIGDIR}")


if __name__ == "__main__":
    main()
