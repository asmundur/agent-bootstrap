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

Are these correct? Enter the number of any value to change it, or 'yes' to continue.
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

```

(Remember to also substitute the nested `{{PLACEHOLDERS}}` within the overview block.)

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

Next steps:
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

Next steps:
  → Run /feature-start to begin your first feature
  → After merging a feature, run /retro to capture learnings
  → Run /sync-bootstrap to pull future template improvements
```

**For `codex`:**
```
Bootstrap complete! Generated files for Codex CLI (and other AGENTS.md-compatible tools):

  ✓ AGENTS.md
  ✓ .claude/.bootstrap-manifest.json

Note: The full Claude Code workflow system (.claude/skills/, .claude/agents/, etc.)
was not generated. Re-run /bootstrap and select "both" to add Claude Code support.
```
