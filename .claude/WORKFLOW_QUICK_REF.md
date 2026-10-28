# Workflow Quick Reference

**Model:** Contractor (you direct, Claude orchestrates)

---

## The Loop

```
Your instruction
    ↓
[PLAN] (if multi-file or unclear) → Show plan → Your approval
    ↓
[EXECUTE] Implement, verify, done
    ↓
[REPORT] Summary + what's ready
    ↓
Repeat
```

---

## I Ask You When

- **Design forks:** "Option A (fast) vs. Option B (robust). Which?"
- **Code ambiguity:** "Spec unclear on X. Assume Y?"
- **Replication edge case:** "Just missed tolerance. Investigate?"
- **Scope question:** "Also refactor Y while here, or focus on X?"

---

## I Just Execute When

- Code fix is obvious (bug, pattern application)
- Verification (tolerance checks, tests, compilation)
- Documentation (logs, commits)
- Plotting (per established standards)
- Deployment (after you approve, I ship automatically)

---

## Quality Gates (No Exceptions)

| Score | Action |
|-------|--------|
| >= 80 | Ready to commit |
| < 80  | Fix blocking issues |

---

## Non-Negotiables (Customize These)

- **路径:** 一律相对仓库根;代码进 `scripts/stata/` 与 `scripts/python/`,结果进 `output/`(表格、图、日志);禁止绝对路径和硬编码用户目录。
- **种子:** Stata 每个 `.do` 置顶 `set seed` + `set sortseed` 各一次;Python 置顶 `rng = np.random.default_rng(<seed>)` 创建一次,种子写明。禁止在循环/函数内设种。
- **图表:** 论文 → 矢量 PDF(matplotlib `savefig(format="pdf")` / Stata `graph export ... as(pdf)`);幻灯片 → 300 DPI PNG ≥2000px、透明底。只用项目调色板(Emory 蓝 #012169 / 金 #B9975B + 语义色);禁止默认灰底;标签位置按 `.claude/rules/tikz-measurement.md` 计算,不目测。
- **表格:** `esttab → output/*.tex` + `\input{}`,绝不手排;`booktabs`;星号 `* 0.10 ** 0.05 *** 0.01`;`b(3) se(2)`;表注写明聚类层级。
- **容差:** 整数精确;点估计 <0.01;标准误 <0.05(`.claude/rules/replication-protocol.md`)。

---

## Preferences

**Visual:** 发表级标准——项目调色板、矢量论文图、透明底幻灯片图;每次出图后自检标签/图例是否遮挡。
**Reporting:** 简洁要点为主,细节按需展开;改动列出文件与理由。
**Session logs:** Always(post-plan、增量、end-of-session)。
**Replication:** 严格——容差外必须解释(`EXPLAINED` 需指名具体替代设定),不接受"差不多"。
**初期节奏:** 前几次会话多检查——设计分叉、歧义、不可逆操作前先问。
**语言:** 中文交流、中文标点;聊天中的数学用平文本,不用 LaTeX。

---

## Exploration Mode

For experimental work, use the **Fast-Track** workflow:
- Work in `explorations/` folder
- 60/100 quality threshold (vs. 80/100 for production)
- No plan needed — just a research value check (2 min)
- See `.claude/rules/exploration-fast-track.md`

---

## Next Step

You provide task → I plan (if needed) → Your approval → Execute → Done.
