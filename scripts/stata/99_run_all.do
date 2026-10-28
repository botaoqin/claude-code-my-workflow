* =============================================================================
* File:     99_run_all.do
* Purpose:  One-command reproduction of the mini-replication: generate the
*           synthetic panel, run 01-03, then build the figures.
* Inputs:   none (the panel is generated from seed 20261028)
* Outputs:  output/ (tables, figures, logs, intermediates)
* Run:      cd scripts/stata && "<StataSE>" -b do 99_run_all.do
* =============================================================================
version 16
clear all
set more off
cap log close _all

* Normalize cwd to the repo root (INV-14); the -b log stays in the launch cwd
if regexm(c(pwd), "scripts/stata$") cd ../..
cap mkdir "output"
cap mkdir "output/logs"

* NOTE: Stata SE 16 runs under Rosetta (x86_64) on this machine, so a plain
* `shell python3` cannot load the arm64 numpy/pandas extensions. `arch -arm64`
* launches the native interpreter from inside the x86_64 Stata process.
* `capture noisily` is required: a successful `shell` leaves _rc untouched, so
* an earlier `cap mkdir` error would otherwise be misread as a shell failure.
capture noisily shell arch -arm64 python3 scripts/python/00_make_synthetic_panel.py
if _rc {
    display as error "Python panel generation failed (rc = " _rc ")"
    error _rc
}
capture confirm file "output/intermediates/synthetic_panel.csv"
if _rc error 601

* Gate each step on its ARTIFACT, not on _rc: `do` propagates the last
* command's _rc, and first-time `export delimited ..., replace` leaves a
* nonfatal r(601) "file not found" note. Erase the target first so a stale
* file from an earlier run cannot pass the check.
capture erase "output/intermediates/panel.dta"
do "scripts/stata/01_load_clean.do"
capture confirm file "output/intermediates/panel.dta"
if _rc error 601

capture erase "output/intermediates/coefs.csv"
capture erase "output/intermediates/estimates/m1.ster"
capture erase "output/intermediates/estimates/m4.ster"
do "scripts/stata/02_regressions.do"
capture confirm file "output/intermediates/coefs.csv"
if _rc error 601
capture confirm file "output/intermediates/estimates/m4.ster"
if _rc error 601

capture erase "output/tables/mini_replication.tex"
do "scripts/stata/03_tables.do"
capture confirm file "output/tables/mini_replication.tex"
if _rc error 601

* Same Rosetta / _rc note applies to the figure step.
capture noisily shell arch -arm64 python3 scripts/python/05_make_figures.py
if _rc {
    display as error "Python figure generation failed (rc = " _rc ")"
    error _rc
}
capture confirm file "output/figures/fig_coefplot.png"
if _rc error 601

* Capture the Stata-side environment for the record
log using "output/sessionInfo_stata.txt", text replace
display "$S_DATE $S_TIME"
capture noisily which estout
capture noisily which reghdfe
about
log close

exit, clear STATA
