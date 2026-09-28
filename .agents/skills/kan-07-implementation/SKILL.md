---
name: kan-07-implementation
description: "Use when implementing KAN-07 local validation rules 1 and 2 from debug/KAN-07/PLANO.md: literal CRM length and VPP-required password."
---

# KAN-07 Implementation Workflows

Implement only rules 1 and 2 in `debug/KAN-07/PLANO.md`, using `.agents/AGENTS.md`. This skill coordinates three independently scoped workflows; each file defines its objective, owned files, prerequisites, acceptance checks, and required final `/simple-commit` action.

## Workflow Index

- `workflows/01-modelo-e-extracao.md`: literal CRM extraction for rule 1 only.
- `workflows/02-regras-locais.md`: rule 1 CRM length and rule 2 VPP password requirement.
- `workflows/03-interface-documentacao.md`: presentation, acceptance coverage, and docs for rules 1 and 2.

## Shared Execution Protocol

1. Select exactly one workflow per agent invocation. Read `.agents/AGENTS.md`, the complete `debug/KAN-07/PLANO.md`, and the relevant dependency/source/test files before editing. Treat the workflow's owned-file list as exclusive; do not edit another workflow's files.
2. Before code changes, identify the relevant SDK/package versions from pubspecs and use Context7 to validate any framework, package, API, config, architecture, or language-version decision. No dependency is added by default. If Context7 is unavailable, stop before implementation and report the blocker.
3. Each workflow invocation must run in its own Git worktree and uniquely named branch (`KAN-07-WF01` through `KAN-07-WF03`). Never switch branches in a shared worktree, commit another agent's changes, or stage broad paths. If isolation is unavailable, do not edit; ask for a separate worktree.
4. Workflows are idempotent: inspect the owned files and Git state first; preserve already-correct work, reuse existing tests, and do not duplicate models, routes, rules, fixtures, or registrations. A rerun with passing acceptance checks makes no unnecessary changes.
5. Stay within 500 changed non-test source/config lines for the workflow. Tests and documentation do not count. Count actual changed lines, not files; stop and split the work into a new uniquely scoped workflow if the limit would be exceeded. Keep generated VPP payload compact and verify all 2,792 codes against the JSON source; do not load that JSON at runtime.
6. Never add, stage, print, or commit supplied real XMLs, names, beneficiary data, or secrets. Use small synthetic fixtures.
7. Follow only the closed decisions for rules 1 and 2 in the plan: CRM character count is literal, and all applicable VPP codes produce one rule-specific password error. Do not normalize CRM values or share the VPP list with `RegraCodigoBilateral`.
8. After editing, inspect the complete owned diff and use Context7 to audit the actual files/diff. Run focused native tests/analyzers, then the broad checks required by the workflow when dependencies have been integrated. Fix relevant failures in scope and rerun the same check. Report checks and blockers honestly.
9. Verify the worktree and staged paths contain only this workflow's intended changes. Do not push or commit unrelated/untracked user files.
10. The final action for every implementation workflow is to invoke `/simple-commit` after validation and hygiene checks. If there is no change to commit, report the workflow as already satisfied instead of manufacturing a commit.

## Ordering And Parallelism

WF01 and WF02 may be developed in parallel only if WF02 uses the stated `GuiaTiss.solicitante.numeroConselho` contract and does not edit WF01-owned files. WF03 depends on WF02 and covers only presentation/documentation for rules 1 and 2. Use separate worktrees and branches; never run two agents on the same workflow ID concurrently.
