#!/usr/bin/env python3
"""File:    00_make_synthetic_panel.py
Purpose: Generate the synthetic province-year panel used by the mini-replication
         practice pipeline (drought -> hydropower share -> industrial output).
Inputs:  none.
Outputs: output/intermediates/synthetic_panel.csv
         (province, year, d, p, h, ln_y, y_level)
Notes:   Fully synthetic data. True parameters: theta = 2.0, beta = 0.04,
         gamma = -0.010. Seed pinned once at the top (INV-13); all paths are
         repo-root-relative via REPO (INV-14).
"""
from pathlib import Path

import numpy as np
import pandas as pd

rng = np.random.default_rng(20261028)

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / "output" / "intermediates" / "synthetic_panel.csv"

N_PROV = 31
YEARS = np.arange(2000, 2020)
T = len(YEARS)

# Province-level effects
alpha = rng.uniform(0.20, 0.45, N_PROV)   # hydro-share level
eta = rng.uniform(10.0, 11.0, N_PROV)     # log-output level

# Common time effect
t = np.arange(T)
lam = 0.04 * t + 0.02 * np.sin(2 * np.pi * t / 10)

# Drought index: AR(1) per province, then standardized to mean 0, sd 1
xi = rng.normal(0.0, 0.8, (N_PROV, T))
d_panel = np.zeros((N_PROV, T))
d_panel[:, 0] = rng.normal(0.0, 1.0, N_PROV)
for tt in range(1, T):
    d_panel[:, tt] = 0.6 * d_panel[:, tt - 1] + xi[:, tt]
d = d_panel.ravel()
d = (d - d.mean()) / d.std()

# Precipitation anomaly: correlated with drought, then standardized
omega = rng.normal(0.0, 0.75, N_PROV * T)
p = -0.5 * d + omega
p = (p - p.mean()) / p.std()

# Hydro share: province level minus beta * drought
v = rng.normal(0.0, 0.03, N_PROV * T)
h = np.repeat(alpha, T) - 0.04 * d + v

# Log industrial output: province + year effects, theta * hydro, direct precip effect
eps = rng.normal(0.0, 0.12, N_PROV * T)
ln_y = np.repeat(eta, T) + np.tile(lam, N_PROV) + 2.0 * h - 0.010 * p + eps

df = pd.DataFrame({
    "province": np.repeat(np.arange(1, N_PROV + 1), T),
    "year": np.tile(YEARS, N_PROV),
    "d": d,
    "p": p,
    "h": h,
    "ln_y": ln_y,
    "y_level": np.exp(ln_y),
})

OUT.parent.mkdir(parents=True, exist_ok=True)
df.to_csv(OUT, index=False)
print(f"Wrote {OUT} ({len(df)} rows, {df.shape[1]} columns)")
print(df[["d", "p", "h", "ln_y"]].describe().round(3).to_string())
