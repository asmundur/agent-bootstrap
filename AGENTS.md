# agent-bootstrap

## Project Overview



- **Tech Stack:** Unknown
- **Language:** Unknown
- **Source Directory:** src/
- **Architecture:** Layered

## Essential Commands

```bash
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

- Fresh clones must bootstrap local Beads state from `.beads/issues.jsonl`:
```bash
bd init -p age --json
bd import -i .beads/issues.jsonl --json
bd status --json
```
- Machine consumers should read `.beads/clone-contract.json` instead of inferring readability from `.beads/metadata.json`.

### Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below:
1. **File issues for remaining work** - Create issues for anything that needs follow-up, using `--deps discovered-from:<id>`
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **Hand off** - Provide context for next session along with a fitting conventional commit message

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

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:ca08a54f -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd dolt push
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
<!-- END BEADS INTEGRATION -->
