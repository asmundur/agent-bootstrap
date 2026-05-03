# Beads Quality Audit Skill Refactor

## Summary

Rename the scaffolded `fabricate-beads-history` skill to `audit-beads-quality` and change its purpose from retroactive commit-task fabrication to Beads task quality auditing and enforcement.

## Goal

- Ship a reusable skill that audits existing Beads items, improves useful sparse items, creates missing durable work items, and deletes confirmed noise.
- Promote useful Beads workflow patterns observed in sibling projects into the scaffold templates.
- Preserve the current scaffold rule that agents must not auto-commit, auto-push, or push tracker state without explicit user approval.

## Non-Goals

- Do not mutate sibling project Beads databases as part of this change.
- Do not preserve old mandatory `git push`, `git commit`, `bd sync`, or `bd dolt push` session-close instructions.
- Do not keep commit-history fabrication as the main skill workflow.

## Affected Modules

- `bootstrap-templates/templates/universal/skills/audit-beads-quality.md.tmpl`
- `bootstrap-templates/templates/universal/AGENTS.md.tmpl`
- `scripts/scaffold.sh`
- `scripts/smoke-test-scaffold.sh`
- generated local scaffold outputs under `.claude/`, `.codex/`, `.antigravity/`, and `.agent-scaffold.json`

## Acceptance Criteria

- Given the scaffold templates are refreshed, when `scripts/scaffold.sh` runs, then generated harness skill copies use `audit-beads-quality` and obsolete generated `fabricate-beads-history` copies are removed.
- Given the new skill is opened, when an agent follows it, then it verifies Beads runtime state, classifies issues, improves useful sparse tasks, creates missing durable tasks, and deletes confirmed noise only after a dry run.
- Given generic Beads instructions are generated, when an agent reads them, then they distinguish durable tracked work from discussion/retro/bookkeeping noise and still forbid automatic git/tracker push workflows.
- Given verification runs, when `scripts/smoke-test-scaffold.sh` completes, then scaffold generation and reference checks pass.

## Feedback Loops

- Typecheck: intentionally skipped (`not configured`)
- Lint: intentionally skipped (`not configured`)
- Browser verification: intentionally skipped (`not configured`)
- Tests: `scripts/smoke-test-scaffold.sh`

## Implementation Slices

1. Rename the skill template and update scaffold skill lists.
2. Rewrite the skill body around audit, classification, remediation, and deletion safeguards.
3. Tighten generic Beads task quality guidance in `AGENTS.md.tmpl`.
4. Update smoke tests for the new skill name and quality/no-auto-push expectations.
5. Run scaffold regeneration and smoke verification.
