---
paths:
  - "Slides/**/*.tex"
  - "Quarto/**/*.qmd"
  - "Quarto/**/*.scss"
  - "Preambles/header.tex"
  - "scripts/R/**/*.R"
  - "scripts/stata/**/*.do"
  - "scripts/python/**/*.py"
---

# Content Invariants (INV-1 through INV-15)

Numbered non-negotiable rules for content produced in this repository. Critic agents, reviewers, and audit agents should cite invariants by number (e.g., "violates INV-3") when flagging issues. Adapted from clo-author's enforcement pattern.

## Slide invariants

- **INV-1: Palette sync.** Color names in `Preambles/header.tex` must match SCSS variables in `Quarto/theme-template.scss`. Verify with `./scripts/check-palette-sync.sh`. Any new color added to one must be added to the other.
- **INV-2: Beamer↔Quarto notation parity.** Every math symbol, variable name, and subscript in a Beamer `.tex` slide must appear identically in its Quarto `.qmd` mirror. Notation drift between the two is a critical bug.
- **INV-3: Quarto CSS override contract.** Styles that must override Bootstrap defaults (e.g., inline code color, code block background) go in `include-in-header` as a raw `<style>` tag, never in the SCSS file. SCSS is only for styles that do not need to beat Bootstrap's cascade — Bootstrap's own selectors win specificity wars otherwise.
- **INV-4: TikZ as SVG.** Browsers cannot render PDF images inline. All TikZ diagrams in Quarto/HTML must be SVG, produced via `/extract-tikz`. Never embed a `.pdf` in a `.qmd` slide.
- **INV-5: Single bibliography.** `Bibliography_base.bib` is the canonical bibliography. No per-lecture `.bib` files. All citations must resolve against this one file.

## Slide design invariants

- **INV-6: No `\pause` or overlays.** Beamer `\pause`, `\only`, `\visible`, `\onslide` commands are forbidden. See `.claude/rules/no-pause-beamer.md` for rationale.
- **INV-7: Max 2 colored boxes per slide.** Overusing `keybox`, `definitionbox`, or callout environments creates "box fatigue." Two per slide maximum.
- **INV-8: Motivation before formalism.** Every definition must be preceded by a motivating example, intuition, or real-world question. No unmotivated math.

## R script invariants

- **INV-9: `set.seed()` once at top.** Every R script that uses randomness must call `set.seed(N)` exactly once, at the top of the script, before any stochastic code. Never inside loops or functions.
- **INV-10: Relative paths only.** No absolute paths (`/Users/...`, `C:\...`, `~` expansion). All paths relative to the repository root. Use `file.path()` for cross-platform compatibility.
- **INV-11: Transparent backgrounds for Beamer figures.** All `ggsave()` calls producing figures for Beamer slides must include `bg = "transparent"`.
- **INV-12: Project theme on all plots.** Every ggplot figure must use the project's custom theme. No default ggplot2 gray backgrounds should appear in any committed figure.

## Stata / Python script invariants

- **INV-13: Seed pinned once at top.** Every `.do` file that uses randomness must set `set seed N` and `set sortseed N` exactly once at the top, before any stochastic code — never inside loops or programs. Every `.py` file must create `rng = np.random.default_rng(<seed>)` once at the top and use that generator throughout.
- **INV-14: Relative paths only (Stata/Python).** As INV-10, generalized: no absolute paths or `~` expansion; all paths relative to the repository root. Stata scripts use display-free path globals or plain relative paths; Python scripts use `pathlib.Path` relative to the project root.
- **INV-15: Vector + transparent exports.** Paper figures export as vector PDF (matplotlib `savefig(format="pdf")`, Stata `graph export ... as(pdf)`); slide figures as transparent PNG at 300 DPI (≥2000px wide). Every figure uses the project palette; no default gray backgrounds in any committed figure.
