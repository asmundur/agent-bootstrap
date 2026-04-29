# Preserve Pre-Scaffold Artifacts

## Summary

Make `scripts/scaffold.sh` adoption-aware so first-time scaffold application never silently destroys a pre-existing target artifact. Existing user-authored files that collide with scaffold targets must be preserved, surfaced as unresolved adoption conflicts, and then resolved through a structured follow-up workflow.

## Goal

Protect valuable pre-scaffold artifacts while keeping scaffold adoption non-interactive and deterministic:

1. Preserve conflicting pre-existing files during first scaffold adoption
2. Block future scaffold refreshes until those preserved artifacts are reviewed and resolved
3. Provide a dedicated workflow that extracts reusable template value and archives the legacy artifacts locally

## Non-Goals

- Semantic merging of arbitrary markdown or config files
- Partial conflict resolution in v1
- Persisting resolved adoption-conflict history in scaffold state

## Constraints

- `scripts/scaffold.sh` remains the default forward refresh path
- Conflict handling must apply to any target path the scaffold writes
- First-run conflict handling must preserve and continue without asking the user
- Later scaffold runs must fail while unresolved conflicts remain
- Legacy artifacts that are purely project-local must not clutter active scaffold docs or templates

## Canonical Terms To Use

- Adoption conflict: a pre-existing non-scaffold-managed file that collides with a scaffold target
- Preserved backup: the sibling `*.pre-scaffold.*` file created during first-run adoption
- Resolution workflow: the dedicated skill that reviews all preserved backups in one pass and archives them under `docs/legacy-agent-artifacts/`
- Archived legacy artifact: a preserved backup moved into the mirrored `docs/legacy-agent-artifacts/` tree after resolution

## Affected Modules

- `scripts/scaffold.sh`
- `scripts/smoke-test-scaffold.sh`
- `README.md`
- `.claude/scaffold-state-spec.md`
- `bootstrap-templates/templates/universal/skills/bootstrap.md.tmpl`
- `bootstrap-templates/templates/universal/skills/resolve-adopted-artifacts.md.tmpl`
- generated local harness mirrors under `.claude/`, `.codex/`, and `.antigravity/`

## Interface Changes

- Add temporary `adoptionConflicts` state to `.agent-scaffold.json`
- Add a new `/resolve-adopted-artifacts` skill mirrored across supported harnesses
- Change first-run scaffold collisions from overwrite behavior to preserve-and-continue behavior
- Change later scaffold refreshes to fail loudly until all adoption conflicts are resolved

## Acceptance Criteria

### Given a pre-existing file at a scaffold target
- When `scripts/scaffold.sh` runs for the first time
- Then the existing file is moved to a sibling `*.pre-scaffold.*` backup
- And the scaffolded file is written at the original target path
- And `.agent-scaffold.json` records an unresolved `adoptionConflicts` entry

### Given unresolved adoption conflicts
- When `scripts/scaffold.sh` runs again
- Then it fails loudly before rewriting anything
- And it reports that the adoption-resolution workflow must be completed first

### Given a preserved backup that changed after capture
- When `scripts/scaffold.sh` runs again
- Then it fails loudly and reports the drift or missing backup path

### Given all preserved backups have been reviewed and archived
- When the resolution workflow clears `adoptionConflicts`
- Then `scripts/scaffold.sh` can run normally again

## Feedback Loops

- Typecheck: `not configured` — intentionally skipped
- Lint: `not configured` — intentionally skipped
- Browser verification: `not configured` — intentionally skipped
- Tests: `scripts/smoke-test-scaffold.sh`

## Open Questions / Parked Decisions

- None for v1. The preserve-and-continue contract, temporary state model, archive location, and all-at-once resolution pass are fixed.
