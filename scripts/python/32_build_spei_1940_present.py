#!/usr/bin/env python3
"""File:    32_build_spei_1940_present.py
Purpose: Build province-month SPEI1/3/6/12 from the 1940-2026 ERA5 monthly-means
         record, with FAO-56 Penman-Monteith PET and a long standardization
         reference period (1940-2025), then merge the new series into the monthly
         analysis panel as SPEI*_L columns.

         Estimator parity with the existing panel (heat-china-thesis): the PM ET0
         formula, the cos(latitude) province aggregation, the Thornthwaite PET and
         the log-logistic standardization are ported verbatim from
             heat-china-thesis/src/pet_monthly_pm.py
             heat-china-thesis/src/spei.py  (_standardize_loglogistic,
                                             thornthwaite_pet)
         The ONLY change relative to the existing SPEI1/SPEI3 is the calibration
         window: 1940-2025 (86 years) instead of 2000-2026 (26 years). Everything
         else is held fixed so the new-vs-old difference isolates baseline length.

         Variants written alongside the main series (see the memo's robustness
         checklist, Charlie 2026-11-10):
           spei3_pm_prefit  pooled fit on 1940-2001 (pre-analysis window)
           spei3_pm_wmo     pooled fit on 1961-2020 (WMO normal period)
           spei3_pm_cm      calendar-month standardization, fit 1940-2025
           spei1_th/spei3_th  Thornthwaite PET instead of PM (fit 1940-2025)

Inputs:  output/intermediates/weather_1940_present/era5_monthly_means/
             era5_monthly_means_<year>_merged.nc   (87 files, 1940-2026)
         ../heat-china-thesis/data/interim/era5_grid_province_mask.csv
             (read-only cache; same 0.25 deg grid; regenerate via heat's
              pet_monthly_pm.build_mask() if absent)
         ../heat-china-thesis/data/interim/province_latitude.csv  (read-only)
         output/intermediates/real_panel.csv  (read-only; merge + overlap check)
Outputs: output/intermediates/weather_1940_present/
             spei_pm_province_month_1940_2026.csv
         output/intermediates/real_panel_spei_long.csv
Notes:   The mask covers 31 provinces; heat's panel uses the same canonical names.
         Aggregation is a one-time cell->province index build plus per-month
         np.bincount weighted sums (identical arithmetic to heat's groupby).
         gamma uses the sea-level simplification and Rso = 0.75*Ra exactly as
         heat's pm_et0_per_grid (the module docstring there mentions elevation-
         adjusted gamma, but the code path does not apply it; parity wins here).
         Fixed DAYS table (February = 28) as in heat, monthly step.
         Paths are repo-root-relative (INV-14). No randomness.
Run:
  .venv/bin/python scripts/python/32_build_spei_1940_present.py
"""
from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd

REPO = Path(__file__).resolve().parents[2]
HEAT = REPO.parent / "heat-china-thesis"
MM = REPO / "output" / "intermediates" / "weather_1940_present" / "era5_monthly_means"
OUTDIR = REPO / "output" / "intermediates" / "weather_1940_present"
MASK_CSV = HEAT / "data" / "interim" / "era5_grid_province_mask.csv"
LAT_CSV = HEAT / "data" / "interim" / "province_latitude.csv"
PANEL = REPO / "output" / "intermediates" / "real_panel.csv"
OUT_SPEI = OUTDIR / "spei_pm_province_month_1940_2026.csv"
OUT_PANEL = REPO / "output" / "intermediates" / "real_panel_spei_long.csv"

FIT_START, FIT_END = 1940, 2025          # main reference window
PREFIT_END = 2001                        # pre-analysis window
WMO = (1961, 2020)                       # WMO normal period
SCALES = (1, 3, 6, 12)

# --- Ported verbatim from heat-china-thesis/src/pet_monthly_pm.py -------------
SIGMA = 4.903e-9          # MJ K^-4 m^-2 day^-1
GSC = 0.0820              # MJ m^-2 min^-1
ALBEDO = 0.23
DAYS = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]


def es_kpa(t_c):
    """Saturation vapour pressure (kPa)."""
    return 0.6108 * np.exp(17.27 * t_c / (t_c + 237.3))


def delta_kpa(t_c):
    """Slope of the saturation vapour pressure curve (kPa/degC)."""
    return 4098.0 * es_kpa(t_c) / (t_c + 237.3) ** 2


def ra_mj(lat_deg, month):
    """Extraterrestrial radiation Ra (MJ m^-2 day^-1) at the 15th of the month."""
    phi = np.deg2rad(lat_deg)
    j = 15 + (month - 1) * 30.4
    dr = 1 + 0.033 * np.cos(2 * np.pi * j / 365)
    decl = 0.409 * np.sin(2 * np.pi * j / 365 - 1.39)
    ws = np.arccos(np.clip(-np.tan(phi) * np.tan(decl), -1, 1))
    return (24 * 60 / np.pi) * GSC * dr * (
        ws * np.sin(phi) * np.sin(decl) + np.cos(phi) * np.cos(decl) * np.sin(ws))


def pm_et0_per_grid(ds, month):
    """FAO-56 monthly ET0 (mm/day) on the grid for one calendar month."""
    t = ds["t2m"].values - 273.15            # (lat, lon)
    td = ds["d2m"].values - 273.15
    u10 = np.sqrt(ds["u10"].values ** 2 + ds["v10"].values ** 2)
    u2 = u10 * 0.748
    ssrd = ds["ssrd"].values / 1e6           # MJ m^-2 day^-1 (monthly mean)
    lat2d = np.broadcast_to(ds.latitude.values[:, None], t.shape)

    ra = ra_mj(lat2d, month)
    rs = ssrd
    rso = (0.75 + 2e-5 * 0.0) * ra           # sea-level simplification; gamma is fixed
    ea = es_kpa(td)
    es = es_kpa(t)
    vpd = np.clip(es - ea, 0, None)
    delta = delta_kpa(t)
    gamma = 0.665e-3 * 101.3                 # kPa/degC at ~sea level (heat parity)
    rns = (1 - ALBEDO) * rs
    t_k = t + 273.16
    rnl = SIGMA * t_k ** 4 * (0.34 - 0.14 * np.sqrt(np.clip(ea, 0, None))) * \
        (1.35 * np.clip(rs / rso, 0, 1.2) - 0.35)
    rn = rns - rnl
    num = 0.408 * delta * rn + gamma * (900.0 / (t + 273.0)) * u2 * vpd
    den = delta + gamma * (1 + 0.34 * u2)
    et0 = np.clip(num / den, 0, None)        # mm/day
    return et0


# --- Ported verbatim from heat-china-thesis/src/spei.py -----------------------
def thornthwaite_pet(tmean_c: np.ndarray, month: np.ndarray, lat_deg: float) -> np.ndarray:
    """Monthly potential evapotranspiration (mm) via Thornthwaite (1948)."""
    t = np.clip(tmean_c, 0, None)
    monthly_mean = pd.Series(t).groupby(month).mean()
    I = float(((monthly_mean / 5.0) ** 1.514).sum())
    a = 6.75e-7 * I**3 - 7.71e-5 * I**2 + 1.792e-2 * I + 0.49239
    pet = 16.0 * (10.0 * t / I) ** a  # mm/month, unadjusted
    phi = np.deg2rad(lat_deg)
    days = np.array(DAYS)
    corr = []
    for m in month:
        J = int(m)
        decl = 0.409 * np.sin(2 * np.pi * (30 * J) / 365 - 1.39)
        ws = np.arccos(np.clip(-np.tan(phi) * np.tan(decl), -1, 1))
        N = 24 / np.pi * ws
        corr.append((N / 12.0) * (days[J - 1] / 30.0))
    return pet * np.array(corr)


def standardize(x: np.ndarray, fit_sel: np.ndarray) -> np.ndarray:
    """Log-logistic standardization, fit on `fit_sel` rows, applied to all finite rows.

    Same fisk fit / shift / clip as heat's _standardize_loglogistic; the only
    addition is the fit-window argument (heat fits and applies in-sample).
    """
    from scipy import stats

    x = x.astype(float)
    out = np.full_like(x, np.nan, dtype=float)
    ok = np.isfinite(x)
    fs = ok & fit_sel
    if fs.sum() < 10:
        return out
    shift = np.nanmin(x[fs])
    c, loc, scale = stats.fisk.fit(x[fs] - shift + 1e-6, floc=0)
    cdf = stats.fisk.cdf(x[ok] - shift + 1e-6, c, loc, scale)
    cdf = np.clip(cdf, 1e-6, 1 - 1e-6)
    out[ok] = stats.norm.ppf(cdf)
    return out


def standardize_by_month(x: np.ndarray, month: np.ndarray, fit_sel: np.ndarray) -> np.ndarray:
    """Calendar-month standardization (each Jan fit and applied with Januaries, ...)."""
    out = np.full_like(x, np.nan, dtype=float)
    for m in range(1, 13):
        sel = month == m
        out[sel] = standardize(x[sel], fit_sel[sel])
    return out


# --- Grid -> province index ------------------------------------------------
def build_aggregator(ds, mask):
    """Per-cell province code and area weight on the dataset's grid."""
    lat_vals = ds.latitude.values
    lon_vals = ds.longitude.values
    lat_pos = {round(float(v), 3): i for i, v in enumerate(lat_vals)}
    lon_pos = {round(float(v), 3): i for i, v in enumerate(lon_vals)}

    provinces = sorted(mask["province"].unique())
    code_of = {p: i for i, p in enumerate(provinces)}
    nprov = len(provinces)

    codes = np.full((len(lat_vals), len(lon_vals)), -1, dtype=int)
    wgt = np.zeros_like(codes, dtype=float)
    missing = 0
    for row in mask.itertuples(index=False):
        i = lat_pos.get(round(float(row.lat), 3))
        j = lon_pos.get(round(float(row.lon), 3))
        if i is None or j is None:
            missing += 1
            continue
        codes[i, j] = code_of[row.province]
        wgt[i, j] = np.cos(np.deg2rad(row.lat))
    assert missing == 0, f"{missing} mask cells not on the ERA5 grid"
    used = np.unique(codes[codes >= 0])
    assert len(used) == nprov, "some province has no grid cell"
    denom = np.bincount(codes.ravel()[codes.ravel() >= 0],
                        weights=wgt.ravel()[codes.ravel() >= 0], minlength=nprov)
    return provinces, codes.ravel(), wgt.ravel(), denom


def aggregate(field, codes, wgt, denom):
    """Area-weighted province mean of a (lat, lon) field."""
    f = field.ravel()
    valid = codes >= 0
    num = np.bincount(codes[valid], weights=wgt[valid] * f[valid], minlength=len(denom))
    return num / denom


def main() -> None:
    import xarray as xr

    mask = pd.read_csv(MASK_CSV)
    prov_lat = pd.read_csv(LAT_CSV).set_index("province")["lat"].to_dict()

    files = sorted(MM.glob("era5_monthly_means_*_merged.nc"))
    assert len(files) == 87, f"expected 87 yearly files, found {len(files)}"

    sample = xr.open_dataset(files[0])
    tc = "time" if "time" in sample.coords else "valid_time"
    provinces, codes, wgt, denom = build_aggregator(sample, mask)
    sample.close()
    nprov = len(provinces)
    print(f"[grid] {nprov} provinces, {int((codes >= 0).sum())} cells mapped")

    rows = []
    for f in files:
        year = int(f.stem.split("_")[-2])
        ds = xr.open_dataset(f)
        tc = "time" if "time" in ds.coords else "valid_time"
        for ti in range(ds.sizes[tc]):
            tstamp = pd.Timestamp(ds[tc].values[ti])
            month = tstamp.month
            sub = ds.isel({tc: ti})
            et0 = pm_et0_per_grid(sub, month)                 # mm/day grid
            tp = sub["tp"].values * 1000.0                    # mm/day grid
            t2m = sub["t2m"].values - 273.15
            rows.append(pd.DataFrame({
                "province": provinces,
                "year": year,
                "month": month,
                "pet_pm_mm": aggregate(et0, codes, wgt, denom) * DAYS[month - 1],
                "precip_mm": aggregate(tp, codes, wgt, denom) * DAYS[month - 1],
                "tmean_c": aggregate(t2m, codes, wgt, denom),
            }))
        ds.close()
    df = pd.concat(rows, ignore_index=True).sort_values(
        ["province", "year", "month"]).reset_index(drop=True)

    # --- Coverage assertions ---------------------------------------------------
    assert df["province"].nunique() == 31
    per_year = df.groupby("year")["month"].nunique()
    assert (per_year.loc[1940:2025] == 12).all(), "a pre-2026 year is incomplete"
    assert per_year.loc[2026] == 8, f"2026 months = {per_year.loc[2026]}, expected 8"
    assert len(df) == 31 * (86 * 12 + 8), f"unexpected row count {len(df)}"
    assert df[["precip_mm", "pet_pm_mm", "tmean_c"]].notna().all().all()

    # --- Thornthwaite PET on the same inputs -----------------------------------
    pet_th = np.empty(len(df))
    for prov, g in df.groupby("province", sort=False):
        pet_th[g.index] = thornthwaite_pet(
            g["tmean_c"].to_numpy(), g["month"].to_numpy(), prov_lat[prov])
    df["pet_th_mm"] = pet_th

    # --- SPEI series -----------------------------------------------------------
    fit_main = df["year"].between(FIT_START, FIT_END).to_numpy()
    fit_pre = (df["year"] <= PREFIT_END).to_numpy()
    fit_wmo = df["year"].between(*WMO).to_numpy()
    month_arr = df["month"].to_numpy()

    out = []
    for prov, g in df.groupby("province", sort=False):
        g = g.sort_values(["year", "month"]).copy()
        idx = g.index
        for pet_col, tag in (("pet_pm_mm", "pm"), ("pet_th_mm", "th")):
            d = (g["precip_mm"] - g[pet_col]).to_numpy()
            for s in SCALES:
                acc = pd.Series(d).rolling(s, min_periods=s).sum().to_numpy()
                if tag == "pm":
                    g[f"spei{s}_pm"] = standardize(acc, fit_main[idx])
                elif s in (1, 3):
                    g[f"spei{s}_th"] = standardize(acc, fit_main[idx])
                if tag == "pm" and s == 3:
                    g["spei3_pm_prefit"] = standardize(acc, fit_pre[idx])
                    g["spei3_pm_wmo"] = standardize(acc, fit_wmo[idx])
                    g["spei3_pm_cm"] = standardize_by_month(
                        acc, month_arr[idx], fit_main[idx])
        out.append(g)
    df = pd.concat(out, ignore_index=True).sort_values(
        ["province", "year", "month"]).reset_index(drop=True)

    usable = df.groupby("province")["spei3_pm"].apply(lambda s: s.notna().sum())
    assert usable.min() >= 1000, f"province with <1000 usable months: {usable.idxmin()}"
    for c in ("spei1_pm", "spei3_pm", "spei6_pm", "spei12_pm",
              "spei3_pm_prefit", "spei3_pm_wmo", "spei3_pm_cm", "spei1_th", "spei3_th"):
        assert c in df.columns, c

    OUTDIR.mkdir(parents=True, exist_ok=True)
    df.to_csv(OUT_SPEI, index=False)
    print(f"[done] {OUT_SPEI.relative_to(REPO)}: {len(df)} rows, "
          f"{df.province.nunique()} provinces, {df.year.min()}-{df.year.max()}")

    # --- Merge into the analysis panel ----------------------------------------
    panel = pd.read_csv(PANEL)
    assert len(panel) == 9858, f"panel rows {len(panel)}"
    assert set(panel.province.unique()) == set(provinces)
    new_cols = {
        "spei1_pm": "SPEI1_L", "spei3_pm": "SPEI3_L",
        "spei6_pm": "SPEI6_L", "spei12_pm": "SPEI12_L",
        "spei3_pm_prefit": "SPEI3_L_prefit", "spei3_pm_wmo": "SPEI3_L_wmo",
        "spei3_pm_cm": "SPEI3_L_cm", "spei1_th": "SPEI1_L_th",
        "spei3_th": "SPEI3_L_th",
    }
    add = df[["province", "year", "month"] + list(new_cols)].rename(columns=new_cols)
    merged = panel.merge(add, on=["province", "year", "month"], how="left",
                         validate="m:1")
    assert len(merged) == len(panel) == 9858

    sample_sel = (merged["year"] >= 2000) & ~((merged["year"] == 2000) & (merged["month"] < 3))
    for c in new_cols.values():
        miss = merged.loc[sample_sel, c].isna().sum()
        assert miss == 0, f"{miss} missing {c} in 2000+ panel rows"

    est = merged[(merged["year"] >= 2002) & (~merged["month"].isin([1, 2]))
                 & merged["g_IndVA"].notna()]
    print(f"[panel] estimation rows (pre-keep): {len(est)}; "
          f"SPEI3_L nonmissing: {est['SPEI3_L'].notna().sum()}")

    merged.to_csv(OUT_PANEL, index=False)
    print(f"[done] {OUT_PANEL.relative_to(REPO)}: {len(merged)} rows x {merged.shape[1]} cols")

    # --- Old vs new diagnostics ------------------------------------------------
    ov = merged[merged["year"].between(2000, 2026)]
    print("\n[overlap] correlations with the existing (short-baseline) series:")
    corr1 = ov[["SPEI1", "SPEI1_L"]].corr().iloc[0, 1]
    corr3 = ov[["SPEI3", "SPEI3_L"]].corr().iloc[0, 1]
    print(f"  corr(SPEI1, SPEI1_L) = {corr1:.3f}")
    print(f"  corr(SPEI3, SPEI3_L) = {corr3:.3f}")
    if min(corr1, corr3) < 0.6:
        raise SystemExit("[stop] new SPEI diverges from the existing series "
                         "(corr < 0.6); investigate before estimating")

    diff = (merged["SPEI3_L"] - merged["SPEI3"]).dropna()
    print("\n[overlap] SPEI3_L - SPEI3 distribution:")
    print(diff.describe(percentiles=[0.05, 0.25, 0.5, 0.75, 0.95]).round(3).to_string())

    print("\n[diagnostics] estimation-sample bin counts, SPEI3_L (raw units):")
    cut = [-np.inf, -2, -1.5, -1, -0.5, 0, 0.5, 1, 1.5, 2, np.inf]
    labels = ["<=-2", "(-2,-1.5]", "(-1.5,-1]", "(-1,-.5]", "(-.5,0]", "(0,.5]",
              "(.5,1]", "(1,1.5]", "(1.5,2]", ">2"]
    est = est.copy()
    est["bin"] = pd.cut(est["SPEI3_L"], bins=cut, labels=labels)
    tab = est.groupby("bin", observed=False).agg(
        n=("SPEI3_L", "size"), provinces=("province", "nunique"))
    print(tab.to_string())


if __name__ == "__main__":
    main()
