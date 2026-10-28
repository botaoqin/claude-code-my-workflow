# Specification ledger

Every specification estimated, kept or not, one row each, appended as it is run. Never edit a past row; a correction is a new row.

| Date | Commit | Script:line | Outcome | Specification | Sample | Status | Why | Estimate |
|---|---|---|---|---|---|---|---|---|
| 2026-10-28 | 767de44-dirty | scripts/stata/02_regressions.do:32 | ln_y | `reghdfe ln_y h, absorb(province year) cluster(province)` | 31 provinces x 2000-2019 (N=620) | kept | baseline FE specification | 1.961 (0.108) |
| 2026-10-28 | 767de44-dirty | scripts/stata/02_regressions.do:38 | ln_y | `reghdfe ln_y h p, absorb(province year) cluster(province)` | 31 provinces x 2000-2019 (N=620) | kept | adds the precipitation-anomaly control | 1.960 (0.107) |
| 2026-10-28 | 767de44-dirty | scripts/stata/02_regressions.do:44 | ln_y | `reghdfe ln_y d, absorb(province year) cluster(province)` | 31 provinces x 2000-2019 (N=620) | kept | total association of drought (descriptive, not causal) | -0.082 (0.007) |
| 2026-10-28 | 767de44-dirty | scripts/stata/02_regressions.do:50 | ln_y | `reghdfe ln_y h p d, absorb(province year) cluster(province)` | 31 provinces x 2000-2019 (N=620) | kept | direct-effect check of drought conditional on hydro share | h: 1.793 (0.152); d: -0.012 (0.011) |
| 2026-10-28 | 767de44-dirty | scripts/stata/02_regressions.do:58 | ln_y | `reghdfe ln_y h p d d2, absorb(province year) cluster(province)` | 31 provinces x 2000-2019 (N=620) | dropped | quadratic term insignificant (0.004, SE 0.003); falsification passed, dropped for parsimony | d2: 0.004 (0.003) |
