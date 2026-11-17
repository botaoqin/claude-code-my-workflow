* =============================================================================
* File:     32_spei_long_design.do
* Purpose:  Estimate the Charlie memo (2026-11-10) SPEI design on the long-
*           baseline SPEI series built by 32_build_spei_1940_present.py:
*
*           (a) 0.5-SD bin diagnostic (ten bins, reference (-0.5, 0]) -- the
*               coefficient path used to choose cutoffs (memo section 4);
*           (b) Specification A: level-shift dummies D1/D2/W1/W2, collapsed
*               single dummy, alternative cutoffs, SPEI1 and SPEI6 versions;
*           (c) Specification B: Eyer-Wichman slope-by-bin (six bins) and a
*               continuous linear spline with the same knots (memo section 5);
*           (d) reference-period / PET comparison: one collapsed-dummy spec
*               estimated on old SPEI3, new SPEI3_L, prefit, WMO, calendar-
*               month and Thornthwaite variants;
*           (e) mechanism: the Spec A categories on hydro / thermal / total
*               generation and the hydro share (mirrors 12_decompose).
*
*           Outcome is g_IndVA (NBS published single-month real YoY growth,
*           fraction) -- NOT ln_IndVA (chained index, base-year dependent).
*           FE: province + year-month. SEs clustered by province (29).
* Inputs:   output/intermediates/real_panel_spei_long.csv
*               (see 32_build_spei_1940_present.py)
* Outputs:  output/intermediates/spei_long_bins.csv      (0.5-SD bin coefs)
*           output/intermediates/spei_long_spline.csv    (spline segment slopes)
*           output/tables/spei_long_specA.tex
*           output/tables/spei_long_specB.tex
*           output/tables/spei_long_baseline_compare.tex
*           output/tables/spei_long_mechanism.tex
*           output/logs/32_spei_long_design.smcl
* Run:      from the repo root, or `do` from scripts/stata
* =============================================================================
version 16
clear all
set more off
set seed 20261028
set sortseed 20261028
cap log close _all

* Normalize cwd to the repo root so every path is repo-root-relative (INV-14)
if regexm(c(pwd), "scripts/stata$") cd ../..

cap mkdir "output/logs"
cap mkdir "output/intermediates"
cap mkdir "output/tables"

log using "output/logs/32_spei_long_design.smcl", replace

* case(preserve): import delimited lowercases header names by default.
import delimited "output/intermediates/real_panel_spei_long.csv", clear case(preserve)

* --- Identical estimation sample to 07 / 31 --------------------------------
keep if !missing(g_IndVA, SPEI3_z, heat_z, HydroShare_z, ///
                 hydro_gen, thermal_gen, total_gen)
drop if inlist(month, 1, 2)
drop if year < 2002

count
assert r(N) == 6975
assert inrange(month, 3, 12)
assert inrange(year, 2002, 2026)
assert !missing(SPEI3_L)

egen byte tag_prov = tag(prov_id)
count if tag_prov
assert r(N) == 29
drop tag_prov

* --- Sample-standardised versions of the long-baseline series --------------
egen SPEI1_L_z = std(SPEI1_L)
egen SPEI3_L_z = std(SPEI3_L)
egen SPEI6_L_z = std(SPEI6_L)
gen heat_x_spei_L = heat_z * SPEI3_L_z

* --- Mechanism outcomes (as in 12_decompose_generation.do) -----------------
gen ln_hydro   = log(hydro_gen + 1)
gen ln_thermal = log(thermal_gen + 1)
gen ln_total   = log(total_gen + 1)

* ===========================================================================
* (a) 0.5-SD bin diagnostic on raw SPEI3_L
*     Bins: <=-2, (-2,-1.5], ..., (1.5,2], >2; reference (-0.5,0].
* ===========================================================================
gen byte spbin = .
replace spbin = 1  if SPEI3_L <= -2
replace spbin = 2  if SPEI3_L > -2   & SPEI3_L <= -1.5
replace spbin = 3  if SPEI3_L > -1.5 & SPEI3_L <= -1
replace spbin = 4  if SPEI3_L > -1   & SPEI3_L <= -0.5
replace spbin = 5  if SPEI3_L > -0.5 & SPEI3_L <= 0
replace spbin = 6  if SPEI3_L > 0    & SPEI3_L <= 0.5
replace spbin = 7  if SPEI3_L > 0.5  & SPEI3_L <= 1
replace spbin = 8  if SPEI3_L > 1    & SPEI3_L <= 1.5
replace spbin = 9  if SPEI3_L > 1.5  & SPEI3_L <= 2
replace spbin = 10 if SPEI3_L > 2
label define spbin 1 "<= -2" 2 "(-2,-1.5]" 3 "(-1.5,-1]" 4 "(-1,-.5]" ///
                   5 "(-.5,0] (ref)" 6 "(0,.5]" 7 "(.5,1]" 8 "(1,1.5]" ///
                   9 "(1.5,2]" 10 "> 2"
label values spbin spbin
tab spbin, missing

forvalues j = 1/10 {
    gen byte b`j' = (spbin == `j') if !missing(SPEI3_L)
}
label var b1  "SPEI $\leq -2$"
label var b2  "$-2 <$ SPEI $\leq -1.5$"
label var b3  "$-1.5 <$ SPEI $\leq -1$"
label var b4  "$-1 <$ SPEI $\leq -0.5$"
label var b6  "$0 <$ SPEI $\leq 0.5$"
label var b7  "$0.5 <$ SPEI $\leq 1$"
label var b8  "$1 <$ SPEI $\leq 1.5$"
label var b9  "$1.5 <$ SPEI $\leq 2$"
label var b10 "SPEI $> 2$"

reghdfe g_IndVA b1 b2 b3 b4 b6 b7 b8 b9 b10 heat_z heat_x_spei_L ///
    precip_sum, absorb(prov_id ym) vce(cluster prov_id)
estimates store bins05

* Export the nine bin coefficients for the Python diagnostic figure.
matrix B = J(9, 3, .)
local binvals "1 2 3 4 6 7 8 9 10"
local binno = 0
foreach v in b1 b2 b3 b4 b6 b7 b8 b9 b10 {
    local ++binno
    local bid : word `binno' of `binvals'
    local bb = _b[`v']
    local ss = _se[`v']
    matrix B[`binno', 1] = `bid'
    matrix B[`binno', 2] = `bb'
    matrix B[`binno', 3] = `ss'
}
matrix colnames B = bin b se
preserve
    clear
    svmat B, names(col)
    export delimited bin b se using "output/intermediates/spei_long_bins.csv", replace
restore

* ===========================================================================
* (b) Specification A: level-shift dummies on raw SPEI3_L
*     Main cutoffs: D1 <=-1.5, D2 (-1.5,-1], W1 [1,1.5), W2 >=1.5,
*     reference (-1,1).
* ===========================================================================
gen byte d1 = (SPEI3_L <= -1.5) if !missing(SPEI3_L)
gen byte d2 = (SPEI3_L > -1.5 & SPEI3_L <= -1) if !missing(SPEI3_L)
gen byte w1 = (SPEI3_L >= 1 & SPEI3_L < 1.5) if !missing(SPEI3_L)
gen byte w2 = (SPEI3_L >= 1.5) if !missing(SPEI3_L)
gen byte rf = (SPEI3_L > -1 & SPEI3_L < 1) if !missing(SPEI3_L)
egen byte ncat = rowtotal(d1 d2 w1 w2 rf)
assert ncat == 1 if !missing(SPEI3_L)

* Collapsed headline dummy (memo's collapse rule)
gen byte drought = (SPEI3_L <= -1) if !missing(SPEI3_L)

* Alternative drought cutoffs: -2 / -1
gen byte d1b = (SPEI3_L <= -2) if !missing(SPEI3_L)
gen byte d2b = (SPEI3_L > -2 & SPEI3_L <= -1) if !missing(SPEI3_L)

* SPEI1 and SPEI6 category versions
foreach v in SPEI1_L SPEI6_L {
    gen byte `v'_d1 = (`v' <= -1.5) if !missing(`v')
    gen byte `v'_d2 = (`v' > -1.5 & `v' <= -1) if !missing(`v')
    gen byte `v'_w1 = (`v' >= 1 & `v' < 1.5) if !missing(`v')
    gen byte `v'_w2 = (`v' >= 1.5) if !missing(`v')
    gen byte `v'_rf = (`v' > -1 & `v' < 1) if !missing(`v')
}

gen d1_x_h    = d1 * HydroShare_z
gen d2_x_h    = d2 * HydroShare_z
gen w1_x_h    = w1 * HydroShare_z
gen w2_x_h    = w2 * HydroShare_z
gen dr_x_h    = drought * HydroShare_z
gen d1b_x_h   = d1b * HydroShare_z
gen d2b_x_h   = d2b * HydroShare_z
gen SPEI1_L_d1_x_h = SPEI1_L_d1 * HydroShare_z
gen SPEI1_L_d2_x_h = SPEI1_L_d2 * HydroShare_z
gen SPEI1_L_w1_x_h = SPEI1_L_w1 * HydroShare_z
gen SPEI1_L_w2_x_h = SPEI1_L_w2 * HydroShare_z
gen SPEI6_L_d1_x_h = SPEI6_L_d1 * HydroShare_z
gen SPEI6_L_d2_x_h = SPEI6_L_d2 * HydroShare_z
gen SPEI6_L_w1_x_h = SPEI6_L_w1 * HydroShare_z
gen SPEI6_L_w2_x_h = SPEI6_L_w2 * HydroShare_z

label var d1  "D1: SPEI3 $\leq -1.5$"
label var d2  "D2: $-1.5 <$ SPEI3 $\leq -1$"
label var w1  "W1: $1 \leq$ SPEI3 $< 1.5$"
label var w2  "W2: SPEI3 $\geq 1.5$"
label var drought "Drought: SPEI3 $\leq -1$"
label var d1b "D1: SPEI3 $\leq -2$"
label var d2b "D2: $-2 <$ SPEI3 $\leq -1$"
label var d1_x_h "D1(-1.5) $\times$ HydroShare(z)"
label var d2_x_h "D2(-1.5/-1) $\times$ HydroShare(z)"
label var w1_x_h "W1 $\times$ HydroShare(z)"
label var w2_x_h "W2 $\times$ HydroShare(z)"
label var dr_x_h "Drought $\times$ HydroShare(z)"
label var d1b_x_h "D1(-2) $\times$ HydroShare(z)"
label var d2b_x_h "D2(-2/-1) $\times$ HydroShare(z)"
label var SPEI1_L_d1_x_h "D1 $\times$ HydroShare(z) [SPEI1]"
label var SPEI1_L_d2_x_h "D2 $\times$ HydroShare(z) [SPEI1]"
label var SPEI1_L_w1_x_h "W1 $\times$ HydroShare(z) [SPEI1]"
label var SPEI1_L_w2_x_h "W2 $\times$ HydroShare(z) [SPEI1]"
label var SPEI6_L_d1_x_h "D1 $\times$ HydroShare(z) [SPEI6]"
label var SPEI6_L_d2_x_h "D2 $\times$ HydroShare(z) [SPEI6]"
label var SPEI6_L_w1_x_h "W1 $\times$ HydroShare(z) [SPEI6]"
label var SPEI6_L_w2_x_h "W2 $\times$ HydroShare(z) [SPEI6]"
label var SPEI1_L_d1 "D1: SPEI1 $\leq -1.5$"
label var SPEI1_L_d2 "D2: $-1.5 <$ SPEI1 $\leq -1$"
label var SPEI1_L_w1 "W1: $1 \leq$ SPEI1 $< 1.5$"
label var SPEI1_L_w2 "W2: SPEI1 $\geq 1.5$"
label var SPEI6_L_d1 "D1: SPEI6 $\leq -1.5$"
label var SPEI6_L_d2 "D2: $-1.5 <$ SPEI6 $\leq -1$"
label var SPEI6_L_w1 "W1: $1 \leq$ SPEI6 $< 1.5$"
label var SPEI6_L_w2 "W2: SPEI6 $\geq 1.5$"

eststo clear

reghdfe g_IndVA d1 d2 w1 w2 heat_z heat_x_spei_L precip_sum, ///
    absorb(prov_id ym) vce(cluster prov_id)
eststo A1

reghdfe g_IndVA d1 d2 w1 w2 d1_x_h d2_x_h w1_x_h w2_x_h ///
    heat_z heat_x_spei_L precip_sum, absorb(prov_id ym) vce(cluster prov_id)
eststo A2

reghdfe g_IndVA drought dr_x_h heat_z heat_x_spei_L precip_sum, ///
    absorb(prov_id ym) vce(cluster prov_id)
eststo A3

reghdfe g_IndVA d1b d2b w1 w2 d1b_x_h d2b_x_h w1_x_h w2_x_h ///
    heat_z heat_x_spei_L precip_sum, absorb(prov_id ym) vce(cluster prov_id)
eststo A4

reghdfe g_IndVA SPEI1_L_d1 SPEI1_L_d2 SPEI1_L_w1 SPEI1_L_w2 ///
    SPEI1_L_d1_x_h SPEI1_L_d2_x_h SPEI1_L_w1_x_h SPEI1_L_w2_x_h ///
    heat_z heat_x_spei_L precip_sum, absorb(prov_id ym) vce(cluster prov_id)
eststo A5

reghdfe g_IndVA SPEI6_L_d1 SPEI6_L_d2 SPEI6_L_w1 SPEI6_L_w2 ///
    SPEI6_L_d1_x_h SPEI6_L_d2_x_h SPEI6_L_w1_x_h SPEI6_L_w2_x_h ///
    heat_z heat_x_spei_L precip_sum, absorb(prov_id ym) vce(cluster prov_id)
eststo A6

* Total category effects one SD above mean hydro share
estimates restore A2
di _n "=== Spec A: total effects at HydroShare(z) = 1 ==="
lincom d1 + d1_x_h
lincom d2 + d2_x_h
lincom w1 + w1_x_h
lincom w2 + w2_x_h
estimates restore A3
di _n "=== Collapsed drought: total effect at HydroShare(z) = 1 ==="
lincom drought + dr_x_h

esttab A1 A2 A3 A4 A5 A6 using "output/tables/spei_long_specA.tex", replace ///
    booktabs label b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
    keep(d1 d2 w1 w2 d1_x_h d2_x_h w1_x_h w2_x_h drought dr_x_h ///
         d1b d2b d1b_x_h d2b_x_h ///
         SPEI1_L_d1 SPEI1_L_d2 SPEI1_L_w1 SPEI1_L_w2 ///
         SPEI1_L_d1_x_h SPEI1_L_d2_x_h SPEI1_L_w1_x_h SPEI1_L_w2_x_h ///
         SPEI6_L_d1 SPEI6_L_d2 SPEI6_L_w1 SPEI6_L_w2 ///
         SPEI6_L_d1_x_h SPEI6_L_d2_x_h SPEI6_L_w1_x_h SPEI6_L_w2_x_h) ///
    order(d1 d2 w1 w2 drought d1b d2b ///
          SPEI1_L_d1 SPEI1_L_d2 SPEI1_L_w1 SPEI1_L_w2 ///
          SPEI6_L_d1 SPEI6_L_d2 SPEI6_L_w1 SPEI6_L_w2 ///
          d1_x_h d2_x_h w1_x_h w2_x_h dr_x_h d1b_x_h d2b_x_h ///
          SPEI1_L_d1_x_h SPEI1_L_d2_x_h SPEI1_L_w1_x_h SPEI1_L_w2_x_h ///
          SPEI6_L_d1_x_h SPEI6_L_d2_x_h SPEI6_L_w1_x_h SPEI6_L_w2_x_h) ///
    mtitles("No int." "Cutoffs -1.5/-1" "Collapsed" "Cutoffs -2/-1" ///
            "SPEI1" "SPEI6") ///
    stats(N r2_a, fmt(%9.0fc %9.3f) labels("Observations" "Adj. R-squared")) ///
    nonotes ///
    addnotes("SEs in parentheses, clustered at province level (29 clusters)." ///
             "DV: g_IndVA = NBS published single-month real YoY growth (fraction)." ///
             "SPEI*_L: long-baseline (1940-2025) log-logistic SPEI, raw standardized units." ///
             "Dummies use the raw index; omitted category is -1 < SPEI < 1." ///
             "HydroShare is standardised within the estimation sample." ///
             "FE: province + year-month. Sample: Mar-Dec 2002-2026." ///
             "* p<0.10, ** p<0.05, *** p<0.01.")

* ===========================================================================
* (c) Specification B: Eyer-Wichman slope-by-bin (six bins) and linear spline
*     Knots: -1.5, -1, 0, 1, 1.5. Each beta is the effect of a one-unit SPEI
*     change within that range.
* ===========================================================================
foreach v in SPEI1_L SPEI3_L SPEI6_L {
    gen byte `v'_e1 = (`v' <= -1.5) if !missing(`v')
    gen byte `v'_e2 = (`v' > -1.5 & `v' <= -1) if !missing(`v')
    gen byte `v'_e3 = (`v' > -1 & `v' <= 0) if !missing(`v')
    gen byte `v'_e4 = (`v' > 0 & `v' <= 1) if !missing(`v')
    gen byte `v'_e5 = (`v' > 1 & `v' <= 1.5) if !missing(`v')
    gen byte `v'_e6 = (`v' > 1.5) if !missing(`v')
    egen byte `v'_ncat = rowtotal(`v'_e1 `v'_e2 `v'_e3 `v'_e4 `v'_e5 `v'_e6)
    assert `v'_ncat == 1 if !missing(`v')
    forvalues j = 1/6 {
        gen `v'_x`j' = `v' * `v'_e`j'
        gen `v'_x`j'_h = `v' * `v'_e`j' * HydroShare_z
    }
}

label var SPEI3_L_x1 "SPEI3 $\times$ 1(SPEI3 $\leq -1.5$)"
label var SPEI3_L_x2 "SPEI3 $\times$ 1($-1.5 <$ SPEI3 $\leq -1$)"
label var SPEI3_L_x3 "SPEI3 $\times$ 1($-1 <$ SPEI3 $\leq 0$)"
label var SPEI3_L_x4 "SPEI3 $\times$ 1($0 <$ SPEI3 $\leq 1$)"
label var SPEI3_L_x5 "SPEI3 $\times$ 1($1 <$ SPEI3 $\leq 1.5$)"
label var SPEI3_L_x6 "SPEI3 $\times$ 1(SPEI3 $> 1.5$)"
label var SPEI3_L_x1_h "SPEI3 $\times$ 1($\leq -1.5$) $\times$ Hydro"
label var SPEI3_L_x2_h "SPEI3 $\times$ 1($-1.5,-1$] $\times$ Hydro"
label var SPEI3_L_x3_h "SPEI3 $\times$ 1($-1,0$] $\times$ Hydro"
label var SPEI3_L_x4_h "SPEI3 $\times$ 1($0,1$] $\times$ Hydro"
label var SPEI3_L_x5_h "SPEI3 $\times$ 1($1,1.5$] $\times$ Hydro"
label var SPEI3_L_x6_h "SPEI3 $\times$ 1($> 1.5$) $\times$ Hydro"

foreach v in SPEI1_L SPEI6_L {
    local nm : subinstr local v "_L" "", all
    label var `v'_x1 "`nm' $\times$ 1(`nm' $\leq -1.5$)"
    label var `v'_x2 "`nm' $\times$ 1($-1.5 <$ `nm' $\leq -1$)"
    label var `v'_x3 "`nm' $\times$ 1($-1 <$ `nm' $\leq 0$)"
    label var `v'_x4 "`nm' $\times$ 1($0 <$ `nm' $\leq 1$)"
    label var `v'_x5 "`nm' $\times$ 1($1 <$ `nm' $\leq 1.5$)"
    label var `v'_x6 "`nm' $\times$ 1(`nm' $> 1.5$)"
    label var `v'_x1_h "`nm' $\times$ 1($\leq -1.5$) $\times$ Hydro"
    label var `v'_x2_h "`nm' $\times$ 1($-1.5,-1$] $\times$ Hydro"
    label var `v'_x3_h "`nm' $\times$ 1($-1,0$] $\times$ Hydro"
    label var `v'_x4_h "`nm' $\times$ 1($0,1$] $\times$ Hydro"
    label var `v'_x5_h "`nm' $\times$ 1($1,1.5$] $\times$ Hydro"
    label var `v'_x6_h "`nm' $\times$ 1($> 1.5$) $\times$ Hydro"
}

eststo clear

reghdfe g_IndVA SPEI3_L_x1 SPEI3_L_x2 SPEI3_L_x3 SPEI3_L_x4 SPEI3_L_x5 ///
    SPEI3_L_x6 heat_z heat_x_spei_L precip_sum, absorb(prov_id ym) vce(cluster prov_id)
eststo B1

reghdfe g_IndVA SPEI3_L_x1 SPEI3_L_x2 SPEI3_L_x3 SPEI3_L_x4 SPEI3_L_x5 ///
    SPEI3_L_x6 SPEI3_L_x1_h SPEI3_L_x2_h SPEI3_L_x3_h SPEI3_L_x4_h ///
    SPEI3_L_x5_h SPEI3_L_x6_h heat_z heat_x_spei_L precip_sum, ///
    absorb(prov_id ym) vce(cluster prov_id)
eststo B2

reghdfe g_IndVA SPEI1_L_x1 SPEI1_L_x2 SPEI1_L_x3 SPEI1_L_x4 SPEI1_L_x5 ///
    SPEI1_L_x6 heat_z heat_x_spei_L precip_sum, absorb(prov_id ym) vce(cluster prov_id)
eststo B3

reghdfe g_IndVA SPEI1_L_x1 SPEI1_L_x2 SPEI1_L_x3 SPEI1_L_x4 SPEI1_L_x5 ///
    SPEI1_L_x6 SPEI1_L_x1_h SPEI1_L_x2_h SPEI1_L_x3_h SPEI1_L_x4_h ///
    SPEI1_L_x5_h SPEI1_L_x6_h heat_z heat_x_spei_L precip_sum, ///
    absorb(prov_id ym) vce(cluster prov_id)
eststo B4

reghdfe g_IndVA SPEI6_L_x1 SPEI6_L_x2 SPEI6_L_x3 SPEI6_L_x4 SPEI6_L_x5 ///
    SPEI6_L_x6 heat_z heat_x_spei_L precip_sum, absorb(prov_id ym) vce(cluster prov_id)
eststo B5

reghdfe g_IndVA SPEI6_L_x1 SPEI6_L_x2 SPEI6_L_x3 SPEI6_L_x4 SPEI6_L_x5 ///
    SPEI6_L_x6 SPEI6_L_x1_h SPEI6_L_x2_h SPEI6_L_x3_h SPEI6_L_x4_h ///
    SPEI6_L_x5_h SPEI6_L_x6_h heat_z heat_x_spei_L precip_sum, ///
    absorb(prov_id ym) vce(cluster prov_id)
eststo B6

esttab B1 B2 B3 B4 B5 B6 using "output/tables/spei_long_specB.tex", replace ///
    booktabs label b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
    keep(SPEI3_L_x1 SPEI3_L_x2 SPEI3_L_x3 SPEI3_L_x4 SPEI3_L_x5 SPEI3_L_x6 ///
         SPEI3_L_x1_h SPEI3_L_x2_h SPEI3_L_x3_h SPEI3_L_x4_h ///
         SPEI3_L_x5_h SPEI3_L_x6_h ///
         SPEI1_L_x1 SPEI1_L_x2 SPEI1_L_x3 SPEI1_L_x4 SPEI1_L_x5 SPEI1_L_x6 ///
         SPEI1_L_x1_h SPEI1_L_x2_h SPEI1_L_x3_h SPEI1_L_x4_h ///
         SPEI1_L_x5_h SPEI1_L_x6_h ///
         SPEI6_L_x1 SPEI6_L_x2 SPEI6_L_x3 SPEI6_L_x4 SPEI6_L_x5 SPEI6_L_x6 ///
         SPEI6_L_x1_h SPEI6_L_x2_h SPEI6_L_x3_h SPEI6_L_x4_h ///
         SPEI6_L_x5_h SPEI6_L_x6_h) ///
    mtitles("SPEI3" "SPEI3 $\times$ Hydro" "SPEI1" "SPEI1 $\times$ Hydro" ///
            "SPEI6" "SPEI6 $\times$ Hydro") ///
    stats(N r2_a, fmt(%9.0fc %9.3f) labels("Observations" "Adj. R-squared")) ///
    nonotes ///
    addnotes("SEs in parentheses, clustered at province level (29 clusters)." ///
             "DV: g_IndVA. Each coefficient is the slope of the one-unit SPEI change inside its bin." ///
             "Bins: <=-1.5, (-1.5,-1], (-1,0], (0,1], (1,1.5], >1.5; no separate bin dummies (Eyer-Wichman form)." ///
             "HydroShare is standardised; interaction slopes are the extra slope per one SD of baseline hydro share." ///
             "FE: province + year-month. Sample: Mar-Dec 2002-2026." ///
             "* p<0.10, ** p<0.05, *** p<0.01.")

* --- Linear spline with the same knots (preferred form if it differs) ------
* Basis: x, (x+1.5)+, (x+1)+, (x)+, (x-1)+, (x-1.5)+; segment slopes are sums
* of the basis coefficients up to the segment's upper knot.
matrix S = J(36, 5, .)
local row = 0

foreach sc of numlist 1 3 6 {
    gen bx_0   = SPEI`sc'_L
    gen bx_15  = max(SPEI`sc'_L + 1.5, 0)
    gen bx_1   = max(SPEI`sc'_L + 1, 0)
    gen bx_00  = max(SPEI`sc'_L, 0)
    gen bx_10  = max(SPEI`sc'_L - 1, 0)
    gen bx_115 = max(SPEI`sc'_L - 1.5, 0)
    gen hbx_0   = bx_0   * HydroShare_z
    gen hbx_15  = bx_15  * HydroShare_z
    gen hbx_1   = bx_1   * HydroShare_z
    gen hbx_00  = bx_00  * HydroShare_z
    gen hbx_10  = bx_10  * HydroShare_z
    gen hbx_115 = bx_115 * HydroShare_z

    reghdfe g_IndVA bx_0 bx_15 bx_1 bx_00 bx_10 bx_115 ///
        hbx_0 hbx_15 hbx_1 hbx_00 hbx_10 hbx_115 ///
        heat_z heat_x_spei_L precip_sum, absorb(prov_id ym) vce(cluster prov_id)
    estimates store spl`sc'

    local e0 "bx_0"
    local e1 "bx_0 + bx_15"
    local e2 "bx_0 + bx_15 + bx_1"
    local e3 "bx_0 + bx_15 + bx_1 + bx_00"
    local e4 "bx_0 + bx_15 + bx_1 + bx_00 + bx_10"
    local e5 "bx_0 + bx_15 + bx_1 + bx_00 + bx_10 + bx_115"
    local h0 "hbx_0"
    local h1 "hbx_0 + hbx_15"
    local h2 "hbx_0 + hbx_15 + hbx_1"
    local h3 "hbx_0 + hbx_15 + hbx_1 + hbx_00"
    local h4 "hbx_0 + hbx_15 + hbx_1 + hbx_00 + hbx_10"
    local h5 "hbx_0 + hbx_15 + hbx_1 + hbx_00 + hbx_10 + hbx_115"

    forvalues j = 0/5 {
        local row = `row' + 1
        matrix S[`row', 1] = `sc'
        matrix S[`row', 2] = `j' + 1
        matrix S[`row', 3] = 0
        lincom `e`j''
        matrix S[`row', 4] = r(estimate)
        matrix S[`row', 5] = r(se)
        local row = `row' + 1
        matrix S[`row', 1] = `sc'
        matrix S[`row', 2] = `j' + 1
        matrix S[`row', 3] = 1
        lincom `e`j'' + `h`j''
        matrix S[`row', 4] = r(estimate)
        matrix S[`row', 5] = r(se)
    }
    drop bx_0 bx_15 bx_1 bx_00 bx_10 bx_115 hbx_0 hbx_15 hbx_1 hbx_00 hbx_10 hbx_115
}

matrix colnames S = scale segment hydro b se
preserve
    clear
    svmat S, names(col)
    export delimited scale segment hydro b se ///
        using "output/intermediates/spei_long_spline.csv", replace
restore

* ===========================================================================
* (d) Reference-period and PET comparison on one collapsed-dummy spec
*     Variants: old SPEI3 (2000-2026 fit), SPEI3_L (1940-2025 fit),
*     prefit (1940-2001), WMO (1961-2020), calendar-month, Thornthwaite.
*     Each variant has its own z-score and heat x SPEI control.
* ===========================================================================
eststo clear
local names "old L pre wmo cm th"
local vars  "SPEI3 SPEI3_L SPEI3_L_prefit SPEI3_L_wmo SPEI3_L_cm SPEI3_L_th"
local k = 0
foreach n of local names {
    local ++k
    local v : word `k' of `vars'
    egen z_`n' = std(`v')
    gen byte dr_`n' = (`v' <= -1) if !missing(`v')
    gen drh_`n' = dr_`n' * HydroShare_z
    gen hx_`n' = heat_z * z_`n'
    label var dr_`n' "Drought: SPEI $\leq -1$"
    label var drh_`n' "Drought $\times$ HydroShare(z)"
    reghdfe g_IndVA dr_`n' drh_`n' heat_z hx_`n' precip_sum, ///
        absorb(prov_id ym) vce(cluster prov_id)
    eststo V_`n'
}

esttab V_old V_L V_pre V_wmo V_cm V_th ///
    using "output/tables/spei_long_baseline_compare.tex", replace ///
    booktabs label b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
    keep(dr_* drh_*) ///
    mtitles("Old SPEI3" "SPEI3 L" "Prefit 1940-2001" "WMO 1961-2020" ///
            "Calendar month" "Thornthwaite") ///
    stats(N r2_a, fmt(%9.0fc %9.3f) labels("Observations" "Adj. R-squared")) ///
    nonotes ///
    addnotes("SEs in parentheses, clustered at province level (29 clusters)." ///
             "DV: g_IndVA. Each column: 1(SPEI <= -1) + its HydroShare(z) interaction." ///
             "Rows: the drought dummy and its interaction (coefplot row labels follow variable names)." ///
             "Each variant uses its own sample z-score in the heat x SPEI control." ///
             "Baselines: old = 2000-2026; L = 1940-2025; prefit = 1940-2001; WMO = 1961-2020." ///
             "Calendar month: separate log-logistic fit per calendar month. Thornthwaite: temperature-only PET." ///
             "FE: province + year-month. Sample: Mar-Dec 2002-2026." ///
             "* p<0.10, ** p<0.05, *** p<0.01.")

* ===========================================================================
* (e) Mechanism: Spec A categories on generation outcomes
* ===========================================================================
eststo clear
foreach y in ln_hydro ln_thermal ln_total hydro_frac {
    reghdfe `y' d1 d2 w1 w2 d1_x_h d2_x_h w1_x_h w2_x_h ///
        heat_z heat_x_spei_L precip_sum, absorb(prov_id ym) vce(cluster prov_id)
    eststo M_`y'
}

esttab M_ln_hydro M_ln_thermal M_ln_total M_hydro_frac ///
    using "output/tables/spei_long_mechanism.tex", replace ///
    booktabs label b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
    keep(d1 d2 w1 w2 d1_x_h d2_x_h w1_x_h w2_x_h) ///
    mtitles("ln Hydro" "ln Thermal" "ln Total" "Hydro share") ///
    stats(N r2_a, fmt(%9.0fc %9.3f) labels("Observations" "Adj. R-squared")) ///
    nonotes ///
    addnotes("SEs in parentheses, clustered at province level (29 clusters)." ///
             "Categories from long-baseline SPEI3; omitted category -1 < SPEI3 < 1." ///
             "Outcomes as in 12_decompose_generation.do (logs are log(1 + generation))." ///
             "FE: province + year-month. Sample: Mar-Dec 2002-2026." ///
             "* p<0.10, ** p<0.05, *** p<0.01.")

log close
