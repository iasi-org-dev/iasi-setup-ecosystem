# IASI Corporate Specifications — Approved Baseline v1.2.0

🇬🇧 **English** | 🇪🇸 [Español](README_es.md)

Complete, clean baseline for the IASI corporate rules. **26 atomic, approved `.iasi` specifications**, containing the 17 specifications from the approved v1.1.0 baseline and 9 new workflow specifications.

## Rules included

- Coding: UTF-8 without BOM; LF for cross-platform source and CRLF for Windows-specific scripts; real line breaks and readable layout.
- Java: naming, formatting, functional decomposition, binary `if` convention, `switch` delegation, method length (60 effective lines), max nesting (3 levels), Java-specific complexity and JDK/dependency version policies.
- Quality: cyclomatic complexity ≤ 10 and cognitive complexity ≤ 15 per function/method, subject to the declared analyzer.
- Technology: frozen major.minor line with verified compatible patches; prior impact analysis and approval for changing release line; ongoing vulnerability handling.
- Workflow: `iasi/` is for governance; task outputs belong exclusively to project-root `outputs/<task-id>/`; temporary build files, candidate artifacts and QA evidence are kept separate. Only approved artifacts are explicitly promoted (manually or automatically) to project-root `release/`, without promotion traces inside the product.
- Contextual specifications: corporate/departmental/project scope, atomic documentation, and external input archive semantics.

## Recommended project layout

See `examples/repository-layout.txt`.

## Supporting config

`.editorconfig`, `.gitattributes` and `.gitignore` are **templates** for applying this policy in a project root; they are not substitutes for validation or compatible with every legacy file without review.

## Codex handoff

Use this version as the complete current corporate baseline. Do not combine it with older baselines. Resolve applicable specifications by context; do not duplicate them into each task. Compile, test and validate in `outputs/<task-id>/`; do not promote to `release/` without passing the QA Gate and explicit authorization.

No GitHub repository was changed when generating this package.
