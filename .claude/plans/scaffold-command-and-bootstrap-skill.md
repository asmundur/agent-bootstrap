# Scaffold Command And Bootstrap Skill

## Summary

Replace the current interactive `scripts/bootstrap.sh` flow with a non-interactive `scripts/scaffold.sh` scaffold applicator. Add a new `/bootstrap` skill that inspects an existing project, derives project-specific scaffold values from the codebase, and hydrates the generated scaffold state and user-facing files.

## Goal

Separate two concerns that are currently entangled:

1. Applying the scaffold file set into a project
2. Discovering and maintaining project-specific context inside that scaffold

After this change, the shell command owns scaffold installation and refresh, while the `/bootstrap` skill owns codebase-driven project discovery and scaffold hydration.

## Non-Goals

- Do not redesign the existing feature workflow beyond the bootstrap/scaffold split
- Do not remove `/sync-bootstrap`; it serves the opposite direction from scaffold application
- Do not require interactive shell prompts during scaffold application
- Do not invent stack-specific automation beyond what the bootstrap skill can infer from the target repo

## Constraints

- The shell command must be non-interactive for project metadata and command configuration
- The scaffold-owned machine-readable state file must not live under `.claude/`
- All generated skills going forward must be mirrored across supported harness targets, not only `.claude/`
- Project-local working artifacts must remain distinct from scaffold-managed files
- Existing docs and tests must be updated to reflect the new command and state-file model

## Canonical Terms To Use

- Scaffold command: the shell command that applies or refreshes the scaffold file set
- Scaffold state file: the root-level machine-readable file that tracks generated files, template version, and project variables
- Scaffold hydration: the `/bootstrap` skill updating scaffold values from the existing codebase
- Project-local working artifacts: files such as `.claude/plans/*`, `.claude/context/*`, `.claude/architecture/*`, and `.beads/issues.jsonl`

## Affected Modules

- `scripts/scaffold.sh`
- `scripts/smoke-test-scaffold.sh`
- `README.md`
- `bootstrap-templates/templates/universal/AGENTS.md.tmpl`
- `bootstrap-templates/templates/universal/CLAUDE.md.tmpl`
- `bootstrap-templates/templates/universal/skills/*.md.tmpl`
- `bootstrap-templates/templates/universal/workflows/feature-workflow.md.tmpl`
- `.claude/bootstrap-manifest-spec.md`
- `.claude/context/ubiquitous-language.md`
- Local generated mirrors under `.claude/`, `.codex/`, `.antigravity/`

## Interface Changes

- Add `scripts/scaffold.sh` as the primary scaffold application command
- Remove interactive metadata prompts from the shell command
- Move scaffold state from the legacy `.claude/.bootstrap-manifest.json` path to root-level `.agent-scaffold.json`
- Add a new `/bootstrap` skill to generated skill sets and harness mirrors
- Update generated docs so scaffold-managed values can be hydrated after generation by the bootstrap skill

## Acceptance Criteria

### Given a target project with no existing scaffold
- When `scripts/scaffold.sh` is run
- Then it generates the scaffold file set non-interactively
- And it writes a root-level scaffold state file with generated-file inventory plus placeholder/default project variables

### Given a scaffolded project
- When the `/bootstrap` skill is run
- Then it inspects the existing repository instead of interrogating the human first
- And it derives project-specific values from code, config, and docs where possible
- And it writes those values back into the scaffold state file and scaffolded user-facing files
- And it asks the human only for genuinely unresolved, high-impact ambiguity

### Given generated skills in this project
- When scaffold files are produced
- Then the new `/bootstrap` skill is included in `.claude/skills/`
- And it is mirrored in `.codex/skills/` and `.antigravity/skills/`

### Given project-local working artifacts
- When the scaffold command refreshes scaffold-managed files
- Then it does not treat `.claude/plans/*`, `.claude/context/*`, `.claude/architecture/*`, or `.beads/issues.jsonl` as scaffold-managed outputs

### Given the current documentation and smoke test
- When this change lands
- Then they describe and verify the scaffold-command plus bootstrap-skill model instead of the old interactive bootstrap model

## Feedback Loops

- Typecheck: `not configured` — intentionally skipped
- Lint: `not configured` — intentionally skipped
- Browser verification: `not configured` — intentionally skipped
- Tests: `scripts/smoke-test-scaffold.sh`

## Implementation Slices

1. Define the new scaffold contract in docs and spec terms: rename the command, define `.agent-scaffold.json`, and document scaffold-managed vs project-local artifacts.
2. Refactor the shell script into a non-interactive scaffold applicator that writes placeholder/default variables into the root scaffold state file.
3. Add the new `/bootstrap` skill template and generate it across `.claude`, `.codex`, and `.antigravity`.
4. Update templates and generated docs to reference the scaffold command, scaffold state file, and bootstrap hydration flow.
5. Update the smoke test to validate the non-interactive command, the new state-file location, and the generated bootstrap skill.
6. Regenerate this repo’s local scaffold outputs so they match the updated templates.
7. Run the smoke test and fix any contract drift in docs or generated artifacts.

## Beads-Ready Task Slices

- `docs/spec`: rename bootstrap terminology and define the new scaffold contract
- `command/state-file`: implement non-interactive scaffold application and root-level state file
- `bootstrap-skill`: add and mirror the new bootstrap skill
- `verification`: update smoke tests and regenerate local scaffold outputs

## Open Questions / Parked Decisions

- The long-term product name may change again; this work uses `scaffold.sh` and `.agent-scaffold.json` as provisional names
- Whether generated docs should be re-rendered entirely from scaffold state or patched selectively by `/bootstrap` is left to implementation detail, as long as the writable contract remains the root scaffold state file
