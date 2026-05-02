# Bootstrap Scaffold Cadence

## Summary

Clarify that `/bootstrap` is a scaffold hydration skill for first adoption or intentional re-hydration, not a mandatory step after every `scripts/scaffold.sh` refresh.

## Acceptance Criteria

- Generated agent instructions do not imply `/bootstrap` must run after every scaffold refresh.
- `scripts/scaffold.sh` still points first-time scaffold adopters to `/bootstrap`.
- Routine scaffold refresh output says `/bootstrap` is only needed when project-specific scaffold values need re-hydration.
- README and smoke tests describe and verify the same cadence.

## Scope

- `bootstrap-templates/templates/universal/AGENTS.md.tmpl`
- `AGENTS.md`
- `README.md`
- `scripts/scaffold.sh`
- `scripts/smoke-test-scaffold.sh`
- `.agent-scaffold.json` checksum entry for the locally generated `AGENTS.md`

## Feedback Loops

- `scripts/smoke-test-scaffold.sh`
