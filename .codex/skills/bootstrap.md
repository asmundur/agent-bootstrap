# Bootstrap Skill

You are running the `bootstrap` skill for **agent-bootstrap**. Your job is to hydrate the scaffold by reading the existing repository and filling in the project-specific values that the shell scaffold command intentionally leaves generic.

## Your Goal

Read the codebase, configuration, and docs first. Infer as much project context as you can from evidence. Update the scaffold state and scaffold-managed files with those values. Ask the user only when a high-impact ambiguity cannot be resolved from the repository itself.

## Step 1 — Load Scaffold State

Read `.agent-scaffold.json`.

Treat its `variables` section as the canonical writable source for scaffold values such as:
- project name and description
- tech stack and language
- build, typecheck, lint, browser verification, test, and run commands
- source directory
- architecture pattern
- Beads prefix

## Step 2 — Inspect The Existing Repository

Read the strongest evidence first:
- root build and package files
- entrypoints and source directories
- README and other project docs
- test layout
- existing agent artifacts when present

Use the `grill-me` method, but point it at the repository before the user:
- resolve scope from the actual codebase
- resolve interfaces from config, entrypoints, and tests
- resolve dependencies from package/build files
- resolve constraints from docs and existing conventions

Only escalate to the user when the repository leaves a genuinely consequential ambiguity unresolved.

## Step 3 — Derive The Scaffold Values

Update `.agent-scaffold.json` with the best evidence-backed values you can determine.

Prefer:
- explicit config over naming conventions
- observed commands over guessed commands
- repo terminology over generic labels

If a value cannot be justified from the repo, leave it as-is and record the ambiguity clearly before asking the user.

## Step 4 — Refresh Scaffold-Managed Files

After updating `.agent-scaffold.json`, refresh the scaffold-managed files that depend on those values so they stop showing generic placeholders.

This includes project-facing docs and config such as:
- `AGENTS.md`
- `.claude/CLAUDE.md`
- `.beads/config.yaml`
- any scaffolded skill or workflow file that uses scaffold variables

Do not treat project-local working artifacts as scaffold-managed:
- `.claude/plans/`
- `.claude/context/`
- `.claude/architecture/`
- `.beads/issues.jsonl`

## Step 5 — Produce Or Refresh Project-Local Working Artifacts

When the evidence supports it, create or refresh:
- `.claude/context/ubiquitous-language.md`
- `.claude/architecture/module-map.md`

These are project-local working artifacts. They are informed by the scaffold, but they are not the scaffold itself.

## Step 6 — Report Remaining Ambiguity

If anything important is still unresolved, ask narrow questions with concrete evidence:
- what you found
- why it is ambiguous
- what decision needs confirmation

Do not interrogate the user for information the repository already contains.
