# Bootstrap Skill

You are the bootstrap skill for agent-bootstrap. Your job is to analyze a project, detect its tech stack and commands, and generate a complete Claude Code orchestration setup from the universal templates.

The bootstrap templates live at: `bootstrap-templates/templates/universal/`

---

## Phase 1 — Detect Project State

Check whether the project already has Claude orchestration files:

```bash
ls .claude/ 2>/dev/null
```

Classify the project:
- **new-project**: No `.claude/` directory at all
- **existing-no-config**: `.claude/` exists but no `CLAUDE.md`
- **existing-with-config**: `.claude/CLAUDE.md` already exists

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

Are these correct? Enter the number of any value to change it, or 'yes' to continue.
```

Always ask for `PROJECT_DESCRIPTION` if it could not be auto-detected.

Collect overrides and update the values before proceeding.

---

## Phase 4 — Generate Files

Read each template file from `bootstrap-templates/templates/universal/` and substitute all `{{PLACEHOLDER}}` values with the confirmed values. Also substitute `{{BOOTSTRAP_DATE}}` with today's ISO date.

**Files to generate:**

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

Create the target directories if they don't exist.

**Also write `.claude/.bootstrap-manifest.json`:**

```json
{
  "generatedAt": "{{BOOTSTRAP_DATE}}",
  "pluginVersion": "1.0.0",
  "techStack": "{{TECH_STACK}}",
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
    "BOOTSTRAP_DATE": "..."
  },
  "files": [
    { "target": ".claude/CLAUDE.md", "source": "CLAUDE.md.tmpl", "category": "config" },
    { "target": ".claude/anti-patterns.md", "source": "anti-patterns.md.tmpl", "category": "config" },
    { "target": ".claude/agents/feature-implementation.md", "source": "agents/feature-implementation.md.tmpl", "category": "agent" },
    { "target": ".claude/agents/git-manager.md", "source": "agents/git-manager.md.tmpl", "category": "agent" },
    { "target": ".claude/skills/feature-start.md", "source": "skills/feature-start.md.tmpl", "category": "skill" },
    { "target": ".claude/skills/retro.md", "source": "skills/retro.md.tmpl", "category": "skill" },
    { "target": ".claude/skills/sync-bootstrap.md", "source": "skills/sync-bootstrap.md.tmpl", "category": "skill" },
    { "target": ".claude/workflows/feature-workflow.md", "source": "workflows/feature-workflow.md.tmpl", "category": "workflow" }
  ]
}
```

---

## Phase 5 — Report

List all generated files and confirm success:

```
Bootstrap complete! Generated 9 files:

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
