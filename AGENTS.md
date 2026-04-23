# agent-bootstrap

## Project Overview

A tech-agnostic bootstrap for AI coding workflows that generates Claude Code and Codex-compatible agents, skills, workflows, and beads integration from universal templates.

- **Tech Stack:** Markdown + shell templates
- **Language:** Markdown
- **Source Directory:** bootstrap-templates/templates/universal
- **Architecture:** Template-driven bootstrap repo — universal markdown and shell templates plus a bootstrap skill that materializes project-specific `.claude/`, `.codex/`, and `AGENTS.md` files.

## Essential Commands

```bash
# Build
printf 'No build step for this template repo\n'

# Test
bash scripts/smoke-test-bootstrap.sh

# Run
printf 'This repo generates bootstrap templates; see README.md\n'
```

## Feedback Loops

- **Typecheck:** `not configured`
- **Lint:** `not configured`
- **Browser verification:** `not configured`

If a feedback-loop command is set to `not configured`, skip it. Otherwise, use the fastest applicable loop before moving on to larger changes.

## Code Style Guidelines

- Match the style of surrounding code
- Functions should do one thing
- Name things for what they are, not how they're implemented
- Validate at system boundaries (user input, external APIs) — trust internal code
- No dead code, no commented-out blocks, no TODOs left behind after a feature
- Tests are not optional

## Task Tracking — Beads

This project uses [beads](https://github.com/steveyegge/beads) (`bd`) for task tracking. Issue prefix: `agb`.

Before starting new work:
    bd ready --json           # list available tasks
    bd update <id> --claim --json   # claim one

Creating a task:
    bd create --title "..." -p 2 --json

Closing a task:
    bd close <id> --reason "done" --json

`.beads/issues.jsonl` is the git-tracked snapshot; the pre-commit hook refreshes it via `bd export --no-memories` and auto-stages changes, so task state travels with commits. Do not edit `.beads/issues.jsonl` by hand. Do not bypass the hook (`--no-verify`).

## Durable Artifacts

- **Feature specs:** `.claude/plans/<feature-slug>.md`
- **Ubiquitous language:** `.claude/context/ubiquitous-language.md`
- **Module map:** `.claude/architecture/module-map.md`

These files live under `.claude/` even when you are using another tool. Reuse and update them instead of recreating design context from scratch.

## Working Agreements

- Explore the codebase and understand existing patterns before implementing anything
- Reach a shared design concept before writing code; ambiguous work should go through a grilling/interview phase first
- Plan and confirm acceptance criteria with the user before writing code
- Write or update a feature spec in `.claude/plans/` before implementation starts
- Load the ubiquitous-language glossary and module map when present before planning or implementation
- Keep terminology aligned with the glossary; update it when the domain language changes
- Design around module boundaries and simple interfaces, especially for refactors
- Implement in small red/green/refactor steps and stay within the fastest available feedback loop
- Get explicit user approval before committing changes
- Run the full test suite before any commit — do not commit with failing tests
- Prefer interface-level tests over tests of internal implementation details
- Stage files individually; never blindly add everything
- Semantic commit messages: `<type>(<scope>): summary` with a body explaining *why*
- Never force-push, never bypass commit hooks
- Never implement beyond what was agreed
