---
name: kan-07-implementation
description: "Use when implementing the KAN-07 SulAmerica validator rules from debug/KAN-07/PLANO.md; choose one isolated workflow for XML extraction, local rules, CFM SOAP backend, API route, Flutter CRM validation, or UI/docs."
---

# KAN-07 Implementation Workflows

Implement the rules in `debug/KAN-07/PLANO.md` using the project rules in `.agents/AGENTS.md`. This skill coordinates six independently scoped workflows; each workflow file contains its own objective, owned files, prerequisites, acceptance checks, and required final `/simple-commit` action.

## Workflow Index

- `workflows/01-modelo-e-extracao.md`: solicitante model, UF IBGE map, XML extraction.
- `workflows/02-regras-locais.md`: literal CRM length rule and VPP-required-password rule.
- `workflows/03-cliente-cfm.md`: isolated SOAP 1.1 CFM client and fake-driven tests.
- `workflows/04-rota-profissionais.md`: `POST /api/profissionais`, bounds, rate limit, cache, concurrency.
- `workflows/05-validacao-flutter.md`: response model/service, pure CRM rule, controller orchestration.
- `workflows/06-interface-documentacao.md`: CRM result presentation, acceptance coverage, README updates.

## Shared Execution Protocol

1. Select exactly one workflow per agent invocation. Read `.agents/AGENTS.md`, the complete `debug/KAN-07/PLANO.md`, and the relevant dependency/source/test files before editing. Treat the workflow's owned-file list as exclusive; do not edit another workflow's files.
2. Before code changes, identify the relevant SDK/package versions from pubspecs and use Context7 to validate any framework, package, API, config, architecture, or language-version decision. No dependency is added by default. If Context7 is unavailable, stop before implementation and report the blocker.
3. Each workflow invocation must run in its own Git worktree and uniquely named branch (`KAN-07-WF01` through `KAN-07-WF06`). Never switch branches in a shared worktree, commit another agent's changes, or stage broad paths. If isolation is unavailable, do not edit; ask for a separate worktree.
4. Workflows are idempotent: inspect the owned files and Git state first; preserve already-correct work, reuse existing tests, and do not duplicate models, routes, rules, fixtures, or registrations. A rerun with passing acceptance checks makes no unnecessary changes.
5. Stay within 500 changed non-test source/config lines for the workflow. Tests and documentation do not count. Count actual changed lines, not files; stop and split the work into a new uniquely scoped workflow if the limit would be exceeded. Keep generated VPP payload compact and verify all 2,792 codes against the JSON source; do not load that JSON at runtime.
6. Never add, stage, print, or commit the supplied real XMLs, real names, beneficiary data, access keys, or secrets. Use small synthetic fixtures. CFM credentials belong only in backend environment variables and must never appear in logs, fixtures, client code, or commits.
7. Do not silently resolve open plan decisions. Stop for user confirmation where required: CFM contract/key availability for real-service verification, mapping of `8101` to a separate result, and the local outcome for missing/invalid UF. Follow closed decisions D1-D8 and P1-P7 as written; do not normalize the `EQ ...` prefix. Fake-based implementation may proceed without a real key, but mark live verification pending.
8. After editing, inspect the complete owned diff and use Context7 to audit the actual files/diff. Run focused native tests/analyzers, then the broad checks required by the workflow when dependencies have been integrated. Fix relevant failures in scope and rerun the same check. Report checks and blockers honestly.
9. Verify the worktree and staged paths contain only this workflow's intended changes. Do not push or commit unrelated/untracked user files.
10. The final action for every implementation workflow is to invoke `/simple-commit` after validation and hygiene checks. If there is no change to commit, report the workflow as already satisfied instead of manufacturing a commit.

## Ordering And Parallelism

Independent first-wave work: WF01 and WF03. WF02 requires WF01's `GuiaTiss.solicitante` contract. WF04 requires WF03's client contract. WF05 requires WF01 and the API result contract from WF04 (the JSON contract is also stated in its workflow). WF06 requires WF02, WF04, and WF05. Run dependent work only after merging/cherry-picking its prerequisites into its isolated branch. Multiple agents may work in parallel only on distinct workflow IDs and isolated worktrees. Never run two agents on the same workflow ID concurrently.
