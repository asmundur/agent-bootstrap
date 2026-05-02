# agent-bootstrap

## Project Overview

Project description pending /bootstrap.

- **Tech Stack:** Unknown
- **Language:** Unknown
- **Source Directory:** src/
- **Architecture:** Layered

## Essential Commands

```bash
# Apply or refresh scaffold
scripts/scaffold.sh

# Build
not configured

# Test
not configured

# Run
not configured
```

## Feedback Loops

- **Typecheck:** `not configured`
- **Lint:** `not configured`
- **Browser verification:** `not configured`

If a feedback-loop command is set to `not configured`, skip it. Otherwise, use the fastest applicable loop before moving on to larger changes.

## Scaffold Hydration

Run `/bootstrap` after first scaffold adoption, or when project-specific scaffold values need intentional re-hydration. That skill inspects the existing repository, derives project-specific values, updates `.agent-scaffold.json`, and deterministically refreshes scaffolded docs/config through the scaffold renderer where those values are used.

Re-run `scripts/scaffold.sh` whenever you want to pull the latest forward scaffold changes into the project. It is the only forward refresh path; routine scaffold refreshes do not require `/bootstrap` unless project facts need to be re-read from the codebase.

## Code Style Guidelines

- Match the style of surrounding code
- Functions should do one thing
- Name things for what they are, not how they're implemented
- Validate at system boundaries (user input, external APIs) — trust internal code
- No dead code, no commented-out blocks, no TODOs left behind after a feature
- Tests are not optional

## Task Tracking — Beads

This project uses [beads](https://github.com/steveyegge/beads) (`bd`) for task tracking. Issue prefix: `age`.

### Mandatory Gate — One Task Per Body of Work

**Before starting any body of work**, you must have a single claimed Beads task in hand. One task covers all the edits for that work.
1. **Run `bd ready --json`** to inspect open tasks.
2. **If a match exists**, claim it: `bd update <id> --claim --json`. Announce the claimed ID in your first response.
3. **If no match exists**, create one first, then claim it. Do not start planning or editing until the task is created and claimed.
4. **Announce the task ID** in your response before any plan or code (e.g., `Working on age-xxx — <title>`).

### Working with Tasks

**Create new issues:**

```bash
bd create "Tight, concrete issue title" \
  --type bug|feature|task \
  --priority 1 \
  --description "Current behavior, why it matters, scope boundaries, and the exact code/docs/tests paths involved." \
  --design "Implementation touchpoints in src/... tests/... docs/... plus key constraints and non-goals." \
  --acceptance "- Observable outcome 1\n- Observable outcome 2\n- Verification or fail-loud contract" \
  --notes "Current evidence: direct probes, failing commands, relevant commits, and focused test nodes." \
  --estimate 120 \
  --json

bd create "Concrete follow-up discovered while landing age-123" \
  --type task \
  --priority 1 \
  --description "Specific follow-up needed after inspecting src/... and tests/... during age-123." \
  --design "Call out the exact files, contracts, or parser/search/index surfaces likely to change." \
  --acceptance "- Define the shipped contract\n- Add or adjust targeted regression coverage\n- Keep scope narrower than the parent issue" \
  --notes "Discovered during age-123; include the exact probe, failure, or code-path evidence that surfaced it." \
  --estimate 90 \
  --deps discovered-from:age-123 \
  --json
```

**Complete work:**
```bash
bd close <id> --reason "done" --json
```

### Git Integration & Clone Contract

`.beads/issues.jsonl` is the git-tracked snapshot; the pre-commit hook refreshes it via `bd export --no-memories` and auto-stages changes, so task state travels with commits. Do not edit `.beads/issues.jsonl` by hand. Do not bypass the hook (`--no-verify`).

Important: the presence of `.beads/config.yaml`, `.beads/clone-contract.json`, or `.githooks/pre-commit` does **not** by itself prove that the local Beads database has been bootstrapped. Treat “files scaffolded” and “tool operational” as separate states.

- Fresh clones must bootstrap local Beads state from `.beads/issues.jsonl`:
```bash
bd bootstrap --yes --json
bd status --json
```
- Machine consumers should read `.beads/clone-contract.json` instead of inferring readability from `.beads/metadata.json`.

### Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below:
1. **File issues for remaining work** - Create issues for anything that needs follow-up, using `--deps discovered-from:<id>`
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **Hand off** - Provide context for next session along with a fitting conventional commit message

If the unit of work changed any git-tracked files, the handoff must include a meaningful, high-signal conventional commit message. Do not end a tracked-file work session without one.

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
- When handing work back with tracked-file changes, always provide a meaningful, high-signal conventional commit message even if no commit is being created yet
- Never force-push, never bypass commit hooks
- Never implement beyond what was agreed
