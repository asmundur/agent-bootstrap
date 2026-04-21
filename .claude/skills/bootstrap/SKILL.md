# Bootstrap Skill

You are the bootstrap skill for agent-bootstrap. Your job is to analyze a project, detect its tech stack and commands, and generate a complete AI coding agent setup from the universal templates.

The bootstrap templates live at: `bootstrap-templates/templates/universal/`

---

## Phase 1 — Detect Project State

Check whether the project already has agent orchestration files:

```bash
ls .claude/ 2>/dev/null
ls AGENTS.md 2>/dev/null
```

Classify the project:
- **new-project**: No `.claude/` directory and no `AGENTS.md`
- **existing-no-config**: `.claude/` exists but no `CLAUDE.md`, or `AGENTS.md` exists but is empty/minimal
- **existing-with-config**: `.claude/CLAUDE.md` or `AGENTS.md` already exists with content

If `existing-with-config`: warn the user that re-running will overwrite existing files. Get explicit confirmation before continuing.

---

## Phase 2 — Detect Tech Stack & Commands

Probe for stack indicator files in the project root:

| File(s) | Stack | Build | Test | Run |
|---|---|---|---|---|
| `package.json` | Node/TypeScript | detect from `scripts` in package.json | `npm test` / `yarn test` / `pnpm test` | `npm start` / `npm run dev` |
| `go.mod` | Go | `go build ./...` | `go test ./...` | `go run .` |
| `Cargo.toml` | Rust | `cargo build` | `cargo test` | `cargo run` |
| `*.sln` or `*.csproj` | .NET | `dotnet build` | `dotnet test` | `dotnet run` |
| `requirements.txt` or `pyproject.toml` | Python | detect from `pyproject.toml` build system | `pytest` | `python -m <module>` |
| `pom.xml` | Java/Kotlin (Maven) | `mvn package` | `mvn test` | `mvn exec:java` |
| `build.gradle` or `build.gradle.kts` | Java/Kotlin (Gradle) | `./gradlew build` | `./gradlew test` | `./gradlew run` |

For `package.json`, read it and check the `scripts` field for actual command names.

If multiple stack files are found, list them and ask the user which is primary.

If nothing is detected, proceed to manual collection in Phase 3.

**Detect additional context:**
- Project name: from `package.json` name, `.sln` filename, directory name, or `go.mod` module name
- Source directory: look for `src/`, `lib/`, `app/`, `internal/`, or the main source root
- Architecture pattern: infer from structure (e.g., MVC, layered, hexagonal, flat) — describe briefly what you see

### Beads state detection

Probe `.beads/`:
- `.beads/dolt/` exists → BEADS_STATE = `already-bootstrapped`
- `.beads/issues.jsonl` or `.beads/clone-contract.json` exists (but no dolt/) → BEADS_STATE = `fresh-clone`
- none of the above → BEADS_STATE = `none`

If `.beads/config.yaml` or `.beads/clone-contract.json` exists, read `issue-prefix` / `issue_prefix` from it and use that as the detected BEADS_PREFIX (do not overwrite it later).

Otherwise, derive a default BEADS_PREFIX from PROJECT_NAME: lowercase, strip non-alphanumerics, take the first 2–6 chars or the acronym of word-boundaries (e.g. `my-cool-app` → `mca`, `gloggur-headquarters` → `ghq`).

---

## Phase 3 — Collect & Confirm Values

Present the auto-detected values in a confirmation table:

```
Detected configuration for bootstrap:

  PROJECT_NAME:        my-project
  PROJECT_DESCRIPTION: (not detected — please provide)
  TECH_STACK:          Node/TypeScript
  MAIN_LANGUAGE:       TypeScript
  BUILD_COMMAND:       npm run build
  TEST_COMMAND:        npm test
  RUN_COMMAND:         npm start
  SOURCE_DIR:          src/
  ARCHITECTURE_PATTERN: Layered — routes, services, repositories
  TOOL_TARGET:         both (Recommended — generates AGENTS.md + .claude/CLAUDE.md)
  BEADS_PREFIX:        myp
  BEADS_STATE:         fresh-clone — will import from .beads/issues.jsonl

Are these correct? Enter the number of any value to change it, or 'yes' to continue.
If BEADS_STATE is `already-bootstrapped` or `fresh-clone` and a prefix was read from an existing file, mark BEADS_PREFIX as read-only — changing it would desync the DB.
```

Always ask for `PROJECT_DESCRIPTION` if it could not be auto-detected.

**TOOL_TARGET options:**
- `both` — generates `AGENTS.md` (cross-tool, repo root) + `.claude/CLAUDE.md` (Claude Code-specific). CLAUDE.md imports AGENTS.md and adds Claude-specific agent registry, skill routing, and consultation points. **Recommended** for maximum compatibility.
- `claude-code` — generates only `.claude/CLAUDE.md` with full standalone content. Choose if you only use Claude Code.
- `codex` — generates only `AGENTS.md` at repo root. Choose if you only use Codex CLI (or other tools that read AGENTS.md).

Collect overrides and update the values before proceeding.

---

## Phase 4 — Generate Files

Read each template file from `bootstrap-templates/templates/universal/` and substitute all `{{PLACEHOLDER}}` values with the confirmed values. Also substitute `{{BOOTSTRAP_DATE}}` with today's ISO date.

### Substitution rules for CLAUDE.md.tmpl

The template uses two special placeholders that depend on `TOOL_TARGET`:

**`{{AGENTS_MD_IMPORT}}`**
- If `TOOL_TARGET` is `both`: substitute with `@AGENTS.md\n\n`
- If `TOOL_TARGET` is `claude-code`: substitute with `` (empty string)

**`{{PROJECT_OVERVIEW_SECTION}}`**
- If `TOOL_TARGET` is `both`: substitute with `` (empty string — content comes from imported AGENTS.md)
- If `TOOL_TARGET` is `claude-code`: substitute with the full project overview block below:

```markdown

## Project Overview

{{PROJECT_DESCRIPTION}}

- **Tech Stack:** {{TECH_STACK}}
- **Language:** {{MAIN_LANGUAGE}}
- **Source Directory:** {{SOURCE_DIR}}
- **Architecture:** {{ARCHITECTURE_PATTERN}}

## Essential Commands

\`\`\`bash
# Build
{{BUILD_COMMAND}}

# Test
{{TEST_COMMAND}}

# Run
{{RUN_COMMAND}}
\`\`\`

## Architecture & Key Patterns

{{ARCHITECTURE_PATTERN}}

Follow existing patterns in `{{SOURCE_DIR}}` when implementing new features. Explore before implementing — find similar code and replicate its structure.

## Code Style Guidelines

- Match the style of surrounding code
- Functions should do one thing
- Name things for what they are, not how they're implemented
- Validate at system boundaries (user input, external APIs) — trust internal code
- No dead code, no commented-out blocks, no TODO left behind after a feature
- Tests are not optional

## Task Tracking — Beads

This project uses [beads](https://github.com/steveyegge/beads) (`bd`) for task tracking. Issue prefix: `{{BEADS_PREFIX}}`.

Before starting new work:
    bd ready --json           # list available tasks
    bd update <id> --claim --json   # claim one

Creating a task:
    bd create --title "..." -p 2 --json

Closing a task:
    bd close <id> --reason "done" --json

`.beads/issues.jsonl` is the git-tracked snapshot; the pre-commit hook refreshes it via `bd export --no-memories` and auto-stages changes, so task state travels with commits. Do not edit `.beads/issues.jsonl` by hand. Do not bypass the hook (`--no-verify`).

```

(Remember to also substitute the nested `{{PLACEHOLDERS}}` within the overview block.)

### Beads setup

Preservation rules (never overwrite these if present):
- `.beads/issues.jsonl`
- `.beads/interactions.jsonl`
- `.beads/dolt/` (entire directory)
- `.beads/config.yaml` — if present, leave it; do NOT regenerate
- `.beads/clone-contract.json` — if present, leave it; do NOT regenerate

Files to write (only if missing):
| Template | Target path | Mode |
|---|---|---|
| `beads/config.yaml.tmpl` | `.beads/config.yaml` | 0644 |
| `beads/clone-contract.json.tmpl` | `.beads/clone-contract.json` | 0644 |
| `beads/gitignore` | `.beads/.gitignore` | 0644 |

Hook files (always write — idempotent):
| Template | Target path | Mode |
|---|---|---|
| `githooks/_common.sh` | `.githooks/_common.sh` | 0755 |
| `githooks/beads-pre-commit.sh` | `.githooks/beads-pre-commit.sh` | 0755 |
| `githooks/pre-commit` | `.githooks/pre-commit` | 0755 |

If `.githooks/pre-commit` already exists and differs from the bootstrap version, do NOT overwrite — instead print a warning telling the user to source `beads-pre-commit.sh` from their existing hook (and show the one-liner to paste in). `_common.sh` and `beads-pre-commit.sh` are always safe to (re)write because they are self-contained.

Wire up the hook path:
    git config core.hooksPath .githooks

Then run `bd` if available:
- BEADS_STATE = `none`: `bd init -p <BEADS_PREFIX> --skip-agents --skip-hooks --json`
- BEADS_STATE = `fresh-clone`: `bd init -p <BEADS_PREFIX> --skip-agents --skip-hooks --json` then `bd import .beads/issues.jsonl --json`
- BEADS_STATE = `already-bootstrapped`: skip `bd init`/`bd import` — the DB is live

If `bd` is not on PATH, print the install hint (`curl -sSL https://raw.githubusercontent.com/steveyegge/beads/main/scripts/install.sh | bash`) and the commands the user should run manually; do not fail the bootstrap.

### Files to generate

**Always generate** (when TOOL_TARGET includes `claude-code` or `both`):

| Template | Target Path |
|---|---|
| `CLAUDE.md.tmpl` | `.claude/CLAUDE.md` |
| `anti-patterns.md.tmpl` | `.claude/anti-patterns.md` |
| `agents/feature-implementation.md.tmpl` | `.claude/agents/feature-implementation.md` |
| `agents/git-manager.md.tmpl` | `.claude/agents/git-manager.md` |
| `skills/feature-start.md.tmpl` | `.claude/skills/feature-start.md` |
| `skills/retro.md.tmpl` | `.claude/skills/retro.md` |
| `skills/sync-bootstrap.md.tmpl` | `.claude/skills/sync-bootstrap.md` |
| `workflows/feature-workflow.md.tmpl` | `.claude/workflows/feature-workflow.md` |

**Also generate** when TOOL_TARGET is `both` or `codex`:

| Template | Target Path |
|---|---|
| `AGENTS.md.tmpl` | `AGENTS.md` |

Create the target directories if they don't exist.

**Also write `.claude/.bootstrap-manifest.json`** (always, even for `codex`-only — stored in `.claude/` which is created if needed):

```json
{
  "generatedAt": "{{BOOTSTRAP_DATE}}",
  "pluginVersion": "1.0.0",
  "techStack": "{{TECH_STACK}}",
  "toolTarget": "{{TOOL_TARGET}}",
  "templateSource": "bootstrap-templates/templates/universal",
  "variables": {
    "PROJECT_NAME": "...",
    "PROJECT_DESCRIPTION": "...",
    "TECH_STACK": "...",
    "MAIN_LANGUAGE": "...",
    "BUILD_COMMAND": "...",
    "TEST_COMMAND": "...",
    "RUN_COMMAND": "...",
    "SOURCE_DIR": "...",
    "ARCHITECTURE_PATTERN": "...",
    "TOOL_TARGET": "...",
    "BEADS_PREFIX": "...",
    "BOOTSTRAP_DATE": "..."
  },
  "files": [
    // Include only the files that were actually generated
  ]
}
```

File entries for the manifest:
```json
{ "target": "AGENTS.md", "source": "AGENTS.md.tmpl", "category": "config" }
{ "target": ".claude/CLAUDE.md", "source": "CLAUDE.md.tmpl", "category": "config" }
{ "target": ".claude/anti-patterns.md", "source": "anti-patterns.md.tmpl", "category": "config" }
{ "target": ".claude/agents/feature-implementation.md", "source": "agents/feature-implementation.md.tmpl", "category": "agent" }
{ "target": ".claude/agents/git-manager.md", "source": "agents/git-manager.md.tmpl", "category": "agent" }
{ "target": ".claude/skills/feature-start.md", "source": "skills/feature-start.md.tmpl", "category": "skill" }
{ "target": ".claude/skills/retro.md", "source": "skills/retro.md.tmpl", "category": "skill" }
{ "target": ".claude/skills/sync-bootstrap.md", "source": "skills/sync-bootstrap.md.tmpl", "category": "skill" }
{ "target": ".claude/workflows/feature-workflow.md", "source": "workflows/feature-workflow.md.tmpl", "category": "workflow" }
{ "target": ".beads/config.yaml", "source": "beads/config.yaml.tmpl", "category": "beads" }
{ "target": ".beads/clone-contract.json", "source": "beads/clone-contract.json.tmpl", "category": "beads" }
{ "target": ".beads/.gitignore", "source": "beads/gitignore", "category": "beads" }
{ "target": ".githooks/_common.sh", "source": "githooks/_common.sh", "category": "hook" }
{ "target": ".githooks/beads-pre-commit.sh", "source": "githooks/beads-pre-commit.sh", "category": "hook" }
{ "target": ".githooks/pre-commit", "source": "githooks/pre-commit", "category": "hook" }
```

---

## Phase 5 — Report

List all generated files and confirm success. Tailor the output to the TOOL_TARGET selected.

**For `both`:**
```
Bootstrap complete! Generated files for Claude Code + Codex CLI:

  ✓ AGENTS.md                                  (cross-tool: Codex, Cursor, Gemini CLI, etc.)
  ✓ .claude/CLAUDE.md                          (Claude Code — imports AGENTS.md)
  ✓ .claude/anti-patterns.md
  ✓ .claude/.bootstrap-manifest.json
  ✓ .claude/agents/feature-implementation.md
  ✓ .claude/agents/git-manager.md
  ✓ .claude/skills/feature-start.md
  ✓ .claude/skills/retro.md
  ✓ .claude/skills/sync-bootstrap.md
  ✓ .claude/workflows/feature-workflow.md

Beads:
  ✓ Prefix:        ghq
  ✓ State:         fresh-clone → imported 42 issues
  ✓ Hook path:     .githooks (configured via `git config core.hooksPath`)

Next steps:
  → Run `bd ready --json` to see available work
  → Run /feature-start to begin your first feature (Claude Code)
  → After merging a feature, run /retro to capture learnings
  → Run /sync-bootstrap to pull future template improvements
```

**For `claude-code`:**
```
Bootstrap complete! Generated files for Claude Code:

  ✓ .claude/CLAUDE.md
  ✓ .claude/anti-patterns.md
  ✓ .claude/.bootstrap-manifest.json
  ✓ .claude/agents/feature-implementation.md
  ✓ .claude/agents/git-manager.md
  ✓ .claude/skills/feature-start.md
  ✓ .claude/skills/retro.md
  ✓ .claude/skills/sync-bootstrap.md
  ✓ .claude/workflows/feature-workflow.md

Beads:
  ✓ Prefix:        ghq
  ✓ State:         fresh-clone → imported 42 issues
  ✓ Hook path:     .githooks (configured via `git config core.hooksPath`)

Next steps:
  → Run `bd ready --json` to see available work
  → Run /feature-start to begin your first feature
  → After merging a feature, run /retro to capture learnings
  → Run /sync-bootstrap to pull future template improvements
```

**For `codex`:**
```
Bootstrap complete! Generated files for Codex CLI (and other AGENTS.md-compatible tools):

  ✓ AGENTS.md
  ✓ .claude/.bootstrap-manifest.json

Beads:
  ✓ Prefix:        ghq
  ✓ State:         fresh-clone → imported 42 issues
  ✓ Hook path:     .githooks (configured via `git config core.hooksPath`)

Next steps:
  → Run `bd ready --json` to see available work

Note: The full Claude Code workflow system (.claude/skills/, .claude/agents/, etc.)
was not generated. Re-run /bootstrap and select "both" to add Claude Code support.
```
