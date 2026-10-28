* =============================================================================
* File:     02_regressions.do
* Purpose:  Estimate the five practice specifications (two-way FE, clustered
*           SEs), save the estimates, and export the coefficient summary used
*           by the Python coefficient plot.
* Inputs:   output/intermediates/panel.dta
* Outputs:  output/intermediates/estimates/m1..m4.ster
*           output/intermediates/coefs.csv
*           output/logs/02_regressions.smcl
* Run:      from the master 99_run_all.do, or `do` from the repo root
* =============================================================================
version 16
clear all
set more off
set seed 20261028
set sortseed 20261028
cap log close _all

if regexm(c(pwd), "scripts/stata$") cd ../..
cap mkdir "output/logs"
cap mkdir "output/intermediates"
cap mkdir "output/intermediates/estimates"

log using "output/logs/02_regressions.smcl", replace

use "output/intermediates/panel.dta", clear
xtset province year

eststo clear

* (1) Baseline: hydro share only, province and year FE
reghdfe ln_y h, absorb(province year) cluster(province)
local b1 = _b[h]
local s1 = _se[h]
eststo m1

* (2) Add the precipitation anomaly control
reghdfe ln_y h p, absorb(province year) cluster(province)
local b2 = _b[h]
local s2 = _se[h]
eststo m2

* (3) Drought only: total association, not a causal effect
reghdfe ln_y d, absorb(province year) cluster(province)
local b3 = _b[d]
local s3 = _se[d]
eststo m3

* (4) Direct-effect check: does drought add anything beyond hydro share?
reghdfe ln_y h p d, absorb(province year) cluster(province)
local b4 = _b[h]
local s4 = _se[h]
local b4d = _b[d]
local s4d = _se[d]
eststo m4

* (5) Quadratic falsification: the squared drought term should be ~0
reghdfe ln_y h p d d2, absorb(province year) cluster(province)
eststo m5

* `estimates save <file>` saves the ACTIVE estimates, not a named one, so make
* each stored set active with `estimates restore` before saving it.
estimates restore m1
estimates save "output/intermediates/estimates/m1.ster", replace
estimates restore m2
estimates save "output/intermediates/estimates/m2.ster", replace
estimates restore m3
estimates save "output/intermediates/estimates/m3.ster", replace
estimates restore m4
estimates save "output/intermediates/estimates/m4.ster", replace

* Coefficient summary for the Python coefficient plot. paramcode 1 = hydro
* share, 2 = drought; m4 contributes both coefficients.
matrix M = (1, 1, `b1', `s1' \ 2, 1, `b2', `s2' \ 3, 2, `b3', `s3' \ 4, 1, `b4', `s4' \ 4, 2, `b4d', `s4d')
matrix colnames M = spec paramcode b se
svmat M, names(col)
keep if !missing(spec)
gen str1 param = "h"
replace param = "d" if paramcode == 2
export delimited spec param b se using "output/intermediates/coefs.csv", replace

log close
