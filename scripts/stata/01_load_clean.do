* =============================================================================
* File:     01_load_clean.do
* Purpose:  Import the synthetic panel, validate its shape, attach labels,
*           save the analysis file, and write a descriptives table.
* Inputs:   output/intermediates/synthetic_panel.csv
* Outputs:  output/intermediates/panel.dta
*           output/tables/descriptives.tex
*           output/logs/01_load_clean.smcl
* Run:      from the master 99_run_all.do, or `do` from the repo root
* =============================================================================
version 16
clear all
set more off
set seed 20261028
set sortseed 20261028
cap log close _all

* Normalize cwd to the repo root so every path is repo-root-relative (INV-14)
if regexm(c(pwd), "scripts/stata$") cd ../..

cap mkdir "output"
cap mkdir "output/logs"
cap mkdir "output/intermediates"
cap mkdir "output/tables"

log using "output/logs/01_load_clean.smcl", replace

import delimited "output/intermediates/synthetic_panel.csv", clear
assert inrange(province, 1, 31)
assert inrange(year, 2000, 2019)
assert !missing(h, d, p, ln_y, y_level)
count
assert r(N) == 620

label var province "Province id"
label var year     "Year"
label var d        "Drought index (std.)"
label var p        "Precip. anomaly (std.)"
label var h        "Hydro share (0-1)"
label var ln_y     "Log industrial output"
label var y_level  "Industrial output (index)"

gen d2 = d^2
label var d2 "Drought index squared"

xtset province year
save "output/intermediates/panel.dta", replace

estpost summarize h d p ln_y
esttab using "output/tables/descriptives.tex", replace booktabs label ///
    nonumber noobs cells("mean(fmt(3)) sd(fmt(3))") ///
    collabels("Mean" "Std. Dev.") nonotes

log close
