* =============================================================================
* File:     03_tables.do
* Purpose:  Publish the main regression table with esttab (booktabs,
*           b(3) se(2), star levels, clustered-SE note).
* Inputs:   output/intermediates/estimates/m1..m4.ster
* Outputs:  output/tables/mini_replication.tex
*           output/logs/03_tables.smcl
* Run:      from the master 99_run_all.do, or `do` from the repo root
* =============================================================================
version 16
clear all
set more off
cap log close _all

if regexm(c(pwd), "scripts/stata$") cd ../..
cap mkdir "output/logs"
cap mkdir "output/tables"

log using "output/logs/03_tables.smcl", replace

* `estimates use <file>` loads into the ACTIVE estimates; store each one so
* esttab can address them by name.
estimates use "output/intermediates/estimates/m1.ster"
estimates store m1
estimates use "output/intermediates/estimates/m2.ster"
estimates store m2
estimates use "output/intermediates/estimates/m3.ster"
estimates store m3
estimates use "output/intermediates/estimates/m4.ster"
estimates store m4

esttab m1 m2 m3 m4 using "output/tables/mini_replication.tex", replace ///
    booktabs label b(3) se(2) star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles("Baseline" "+ Precip." "Drought only" "Direct effect") ///
    stats(N r2_a, fmt(%9.0fc %9.3f) labels("Observations" "Adj. R-squared")) ///
    drop(_cons) nonotes ///
    addnotes("SEs in parentheses, clustered at province level (31 clusters)." ///
             "* p<0.10, ** p<0.05, *** p<0.01.")

log close
