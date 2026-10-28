# CLAUDE.MD -- Academic Project Development with Claude Code

<!-- HOW TO USE: This file has been customized for the Workflow Practice Sandbox
     (2026-10-28). Placeholders are filled; Beamer environments and CSS classes
     reflect Preambles/header.tex and Quarto/theme-template.scss as shipped.
     Keep this file under ~200 lines (official guidance) — Claude loads it every session.
     See the guide at docs/workflow-guide.html for full documentation. -->

**Project:** Workflow Practice Sandbox
**Institution:** —(练习沙盒,无机构)
**Branch:** main

---

## Scope Discipline

**Do exactly what was asked — nothing adjacent.** Do not add README files, build scripts,
`.gitignore` edits, helper utilities, or extra tooling that was not requested. If an addition
looks valuable, **list it as a suggestion at the end** and let the user decide.

A request for a codebook is a request for a codebook. Delivering a codebook plus a README plus
build scripts plus gitignore edits means the user now has to review four things to accept one,
and the usual outcome is that all four get thrown away.

**Before adding anything not named in the request, ask.** One line is cheaper than a revert.

---

## Core Principles

- **Plan first** -- enter plan mode before non-trivial tasks; save plans to `quality_reports/plans/`
- **Verify after** -- when a task changes a `.tex`, `.qmd`, `.do`, or `.py` file, compile, render, or run it and confirm the output before reporting done
- **Single source of truth** -- Beamer `.tex` is authoritative; Quarto `.qmd` derives from it
- **Quality gates** -- nothing ships below 80/100
- **[LEARN] tags** -- when corrected, save `[LEARN:category] wrong → right` to [MEMORY.md](MEMORY.md)

Cross-session context lives in [MEMORY.md](MEMORY.md); past plans, specs, and session logs are in [quality_reports/](quality_reports/).

**How we verify** — the references and rules that carry the verification discipline:

- [`verification-ladder.md`](.claude/references/verification-ladder.md) — the seven rungs, from *qualify the checker* to the external oracle, and how the review loop converges.
- [`external-oracle-process.md`](.claude/references/external-oracle-process.md) — running an independent frontier-model referee (Claude Code → another vendor's model via the Oracle CLI; current targets in its §2) and adjudicating what it returns.
- [`provenance-and-ground-truth.md`](.claude/references/provenance-and-ground-truth.md) — naming and pinning your oracles, classifying divergence, and the clean-room boundary.
- [`review-fencing.md`](.claude/rules/review-fencing.md) — reviewer independence is a property of the environment, not an instruction: a neutral copy outside the checkout, prior verdicts withheld, and the answer keys the repo already commits fenced off.
- [`release-engineering.md`](.claude/references/release-engineering.md) — shipping research software: message and silent-resolution censuses, frozen feature matrices for ports, hash-claimed inherited tests, and downstream consumers pinned by commit SHA.

**How we write** — [`writing-with-ai.md`](.claude/rules/writing-with-ai.md): internal vs external-facing documents, why a model cannot make its own output stop reading as model output, and the human-readable standard for anything with your name on it.

**Theory work** — [`theory-proving.md`](.claude/references/theory-proving.md): proof contracts, portfolio search with isolated explorers, counterexample-hunting your own lemmas, adversarial audits, and the rule that an AI-generated proof is a claim, not a theorem.

**The laws** — [`research-agent-laws.md`](.claude/references/research-agent-laws.md): 21 laws for running agents on research infrastructure, each paid for by a real incident.

**How we remember** — the record lives in the repo, not the transcript:

- [`progress-reports.md`](.claude/rules/progress-reports.md) — GitHub issues as defect memory, `quality_reports/` as work memory, `MEMORY.md` as lesson memory.
- [`issue-ledger.md`](.claude/rules/issue-ledger.md) — every shipped bug, deferred improvement and blocking owner decision gets a GitHub issue, closed by hand when the fix lands; the evidence standard and the closing comment.
- [`repo-hygiene.md`](.claude/rules/repo-hygiene.md) — **scratch must not become main.** Enforced by `check-repo-hygiene.py` on every commit.

Nothing clears work until it has a row in [`quality_reports/qualification/LEDGER.md`](quality_reports/qualification/LEDGER.md) — run [`/vaccinate`](.claude/skills/vaccinate/SKILL.md) to put one there.

---

## Project Constitution

**Immutable articles** — deviate only by explicit amendment (see below).

- **Art. I 权威源 (Primary artifact).** 脚本是唯一权威:Stata `.do` / Python `.py` 生成数字与图表,LaTeX `.tex` 引用它们的产物。表格经 `esttab → output/*.tex → \input{}`,图经脚本导出;**绝不手改脚本生成物**。改数字先改脚本再重跑。
- **Art. II Plan-first 阈值.** 触及 >3 个文件,或改变交付物实质(讲稿、论文、分析管线、复现包)→ 先进计划模式并把计划写入 `quality_reports/plans/`;小而明确的修改直接做。
- **Art. III 质量门.** 提交前 ≥80/100(经 `/commit`;`./scripts/install-hooks.sh` 后由 pre-commit 钩子强制);`explorations/` 走 60 分快轨;低于门槛不发布,除非显式 override 并记录理由。
- **Art. IV 验证标准.** 改 `.tex`/`.qmd`/`.do`/`.py` 必须编译/渲染/运行验证通过才可报告"完成";数字与论文对得上(`/audit-reproducibility` 容差:整数精确,点估计 <0.01,标准误 <0.05)。
- **Art. V 发表级图表标准.** 只用项目调色板(Emory 蓝 #012169 / 金 #B9975B + 语义色,`header.tex` ↔ `theme-template.scss` 锁定);论文图表矢量 PDF,幻灯片 300 DPI PNG ≥2000px、透明底;禁止默认灰底;标签位置按 [`tikz-measurement.md`](.claude/rules/tikz-measurement.md) 计算,新图走 `/new-diagram` + `/extract-tikz`。
- **Art. VI 决策记忆.** 设计决策即时写入会话日志;用户纠正沉淀为 `[LEARN]` 条目(通用)或自动记忆(本机/本项目)。同一错误不重复第三次——第二次即停机重估方案。

**偏好 (preferences,可随时调整).** 初期多检查:设计分叉、歧义、不可逆操作前用 `AskUserQuestion` 先确认;报告用简洁要点,细节按需展开;会话日志始终写;中文交流、中文标点;聊天中的数学用平文本不用 LaTeX。

**修订流程.** 用户提出偏离某条时,先问:"是**修订该条**(永久)还是**本次任务一次性 override**?" 前者更新本节并记入会话日志(`[CONSTITUTIONAL AMENDMENT]`),后者只在本任务生效。

> 沙盒阶段本宪法内联于 CLAUDE.md(每次会话常驻上下文)。完整模板见 [`templates/constitutional-governance.md`](templates/constitutional-governance.md);项目定型后可实例化为 `.claude/rules/` 独立规则文件——届时须走模板发布流程(装 Quarto → 同步 surface-sync 计数 → 重渲染 guide → `stamp-render.sh`)。

---

## Folder Structure

```
my-project/
├── CLAUDE.MD                    # This file
├── .claude/                     # Rules, skills, agents, hooks
├── Bibliography_base.bib        # Centralized bibliography
├── Figures/                     # Figures and images
├── Preambles/header.tex         # LaTeX headers
├── Slides/                      # Beamer .tex files
├── Quarto/                      # RevealJS .qmd files + theme
├── docs/                        # GitHub Pages (auto-generated)
├── scripts/                     # Utility scripts + analysis code (numbered stages)
├── output/                      # Generated tables, figures, logs (created by the code)
├── quality_reports/             # Plans, session logs, merge reports, decision records
├── explorations/                # Research sandbox (see rules)
├── templates/                   # Session log, quality report templates
└── master_supporting_docs/      # Papers and existing slides
```

---

## Commands

```bash
# LaTeX (3-pass, XeLaTeX only)
cd Slides && TEXINPUTS=../Preambles:$TEXINPUTS xelatex -interaction=nonstopmode file.tex
BIBINPUTS=..:$BIBINPUTS bibtex file
TEXINPUTS=../Preambles:$TEXINPUTS xelatex -interaction=nonstopmode file.tex
TEXINPUTS=../Preambles:$TEXINPUTS xelatex -interaction=nonstopmode file.tex

# Deploy Quarto to GitHub Pages
./scripts/sync_to_docs.sh LectureN

# Quality score
python3 scripts/quality_score.py Quarto/file.qmd

# Palette sync (LaTeX ↔ SCSS)
./scripts/check-palette-sync.sh

# Stata (batch; logs land in cwd, so cd first)
# This machine runs Stata SE 16 → pin `version 16` at the top of local .do files
# (the version 18 in .claude/rules/stata-code-conventions.md is the generic example).
cd scripts/stata && "/Applications/Stata/StataSE.app/Contents/MacOS/stata-se" -b do 99_run_all.do

# Backtest: is the repo internally consistent and currently true?
# (surface-sync + skill-integrity + model-versions + links + spec-conformance + staleness + repo-hygiene + derived-counts + ledger-coverage + hook-battery)
# Run this after ANY change. Also runs in pre-commit and CI.
./scripts/backtest.sh
```

**Palette contract:** color names in `Preambles/header.tex` must match SCSS variables in `Quarto/theme-template.scss`. See [`Preambles/README.md`](Preambles/README.md).

---

## Quality Thresholds (advisory)

| Score | Checkpoint | Meaning |
|-------|------|---------|
| 80 | Commit | Good enough to save |
| 90 | PR | Ready for deployment |
| 95 | Excellence | Aspirational |

Enforced by `/commit` (halts + asks for override) **and** — once you run `./scripts/install-hooks.sh` — by a real git pre-commit hook (`.githooks/pre-commit`) that runs the backtest gate suite (the hook battery only when a hook, its settings or the battery itself is staged; CI always runs everything) plus the quality (≥80) gate on every commit. Bypass sparingly with `SKIP_QUALITY_GATE=1` or `--no-verify`.

---

## Skills Quick Reference

The full table of all skills lives in [README.md](README.md#skills-claudeskills). Most-used, by workflow:

- **Slides / teaching:** `/create-lecture` `/compile-latex` `/deploy` `/qa-quarto` `/slide-excellence` `/syllabus` `/teach-from-paper` `/scaffold-exercises`
- **Papers / review:** `/review-paper` (`--peer`) `/seven-pass-review` `/respond-to-referees` `/verify-claims` `/proofread` `/humanize` `/submission-disclosures`
- **Data / reproducibility:** `/data-analysis` `/simulation-study` `/audit-reproducibility` `/diagnose` `/replication-package` `/capture-environment` `/power-analysis` `/disclosure-check`
- **Research / writing:** `/interview-me` `/lit-review` `/research-ideation` `/preregister` `/grant-proposal` `/data-management-plan`
- **Verification / rigor:** `/vaccinate` `/challenge` `/oracle-review` `/adjudicate-review` `/differential-audit` `/blast-radius` `/verify-artifact` `/credible-claims` `/deep-audit`
- **Meta / workflow:** `/commit` `/learn` `/new-skill` `/checkpoint` `/context-status` `/deep-audit` `/coauthor-brief` `/triage-inbox` `/issues`

Stata (`/stata-replication`), R packages (`/r-package-check`), TikZ (`/extract-tikz`, `/new-diagram`), and more — see the README for the complete index.

---

## Beamer Custom Environments

Defined in [`Preambles/header.tex`](Preambles/header.tex) (loaded automatically by `/compile-latex`).

| Macro / Style | Effect | Use Case |
| --- | --- | --- |
| `\transitionslide{Title}` | Full-bleed dark blue section frame | Section breaks |
| `\key{...}` | Gold bold emphasis | Key terms |
| `\good{...}` / `\bad{...}` | Green / red semantic text | Observed vs. bias/counterfactual |
| `\muted{...}` | Neutral gray | Asides, caveats |
| `dag-node`, `decision-node`, `observed-edge`, `confound-edge` | TikZ node/edge styles | Causal DAGs — start from `templates/tikz-snippets/` |

## Quarto CSS Classes

Defined in [`Quarto/theme-template.scss`](Quarto/theme-template.scss).

| Class | Effect | Use Case |
| --- | --- | --- |
| `.keybox` | Gold left-border callout | Key takeaways |
| `.methodbox` | Blue left-border callout | Method notes |
| `.resultbox` | Gold outlined box | Headline results |
| `.positive` / `.negative` / `.neutral` | Green / red / gray bold | Sign and status annotations |
| `.smaller` / `.bigger` | 85% / 115% font | Dense slides |

---

## Current Project State

| Lecture | Beamer | Quarto | Key Content |
| --- | --- | --- | --- |
| HelloWorld *(安装验证样例;`/compile-latex HelloWorld` 通过后按 README 删除)* | `HelloWorld.tex` | `HelloWorld.qmd` | Minimal deck to verify setup |
| MiniReplication *(首个全链路练习:合成面板 → Stata → esttab → 图 → 讲稿)* | `MiniReplication.tex` | — | 干旱→水电→工业产出合成面板(N=620);reghdfe 双向 FE + 省聚类;2 张调色板图 |
