# agent-bootstrap

A tech-agnostic workflow orchestration system. Apply a reusable scaffold to any project, then hydrate it with agents, skills, and workflows that guide feature development and improve over time.

Inspired by [aproorg/bootstrap-demo](https://github.com/aproorg/bootstrap-demo), but built to work across any language or tech stack.

## What It Does

- **Scaffold** any project: apply a complete agent workflow scaffold non-interactively
- **Hydrate the scaffold**: run `/bootstrap` so the agent reads the existing codebase and fills in project-specific values
- **Design-first feature workflow**: `/feature-start` begins by building a shared design concept, writes a reusable feature spec, and hands off a concrete implementation contract
- **Shared language + architecture maps**: generate a ubiquitous-language glossary and a module map so planning and implementation use the same terms and boundaries
- **Feedback-loop execution**: TDD-oriented implementation guidance with optional typecheck, lint, and browser verification commands alongside tests
- **Retrospectives**: post-feature analysis with 5W root cause analysis that feeds learnings back into the template
- **Sync**: pull upstream template improvements into your project as the template evolves

## Supported Tech Stacks (auto-detected)

| Stack | Detection | Commands |
|---|---|---|
| Node / TypeScript | `package.json` | npm/yarn/pnpm |
| Go | `go.mod` | `go build`, `go test ./...` |
| Rust | `Cargo.toml` | `cargo build`, `cargo test` |
| .NET | `*.sln` / `*.csproj` | `dotnet build`, `dotnet test` |
| Python | `requirements.txt` / `pyproject.toml` | `pytest`, `python -m` |
| Java / Kotlin | `pom.xml` / `build.gradle` | `mvn` / `gradle` |

Any other stack can be configured manually during scaffold hydration.

### Tech-Stack Irrelevance

Agent-bootstrap is fundamentally about **agent programming**, not language-specific orchestration. The scaffold command applies generic files and state. The `/bootstrap` skill then inspects the target repository and populates a small set of command and project placeholders — `BUILD_COMMAND`, `TYPECHECK_COMMAND`, `LINT_COMMAND`, `BROWSER_VERIFY_COMMAND`, `TEST_COMMAND`, `RUN_COMMAND`, and related project metadata. That is the entire surface area where stack matters.

Every skill, workflow, and agent file under `bootstrap-templates/templates/universal/` is stack-neutral. The glossary, module map, design-first feature workflow, and retrospective skill work the same whether you're in Go, Python, TypeScript, Rust, or anything else.

## Getting Started

### 1. Clone this repository

Clone `agent-bootstrap` somewhere alongside your existing projects:

```bash
git clone https://github.com/steveyegge/agent-bootstrap.git ../agent-bootstrap
```

### 2. Apply the scaffold in your project

Navigate to your target project and run the scaffold command:

```bash
cd ~/my-cool-app
../agent-bootstrap/scripts/scaffold.sh
```

The command will:
1. Generate the scaffold files into `.claude/`, `.beads/`, `.githooks/`, and harness mirrors
2. Write `.agent-scaffold.json` with the scaffold inventory and placeholder/default variables
3. Preserve any pre-existing scaffold target as a sibling `*.pre-scaffold.*` backup instead of silently overwriting it
4. Record unresolved adoption conflicts in `.agent-scaffold.json` until they are reviewed and archived
5. Attempt a non-destructive `bd bootstrap --yes --json` when `bd` is available so Beads-backed workflows are operational immediately
6. Refresh the scaffold later when you re-run it

If the scaffold preserved any pre-existing targets, you must resolve them before the next refresh:

```
/resolve-adopted-artifacts
```

### 3. Hydrate the scaffold from the existing codebase

Run:

```
/bootstrap
```

The skill will:
1. Read the existing repository instead of interrogating you for basic project facts
2. Fill in scaffold values from code, config, tests, and docs
3. Re-run the deterministic scaffold renderer so scaffold-managed files stay consistent with `.agent-scaffold.json`
4. Verify that scaffold-adjacent tooling such as Beads is actually operational instead of assuming generated files imply readiness
5. Ask you only about unresolved, high-impact ambiguity

### 4. Start developing features

```
/feature-start
```

Useful companion skills:

```
/grill-me
/resolve-adopted-artifacts
/ubiquitous-language
/improve-architecture
/tdd
```

### 5. After a feature is merged, run a retrospective

```
/retro
```

### 6. Refresh scaffold-managed files from the upstream template

```
../agent-bootstrap/scripts/scaffold.sh
```

## Generated File Structure

After applying the scaffold, the following files are created at the project root and under `.claude/`:

```
.agent-scaffold.json            # Tracks generated files + scaffold variables
```

```
.claude/
├── CLAUDE.md                    # Project config and workflow routing
├── anti-patterns.md             # Hard constraints agents must follow
├── agents/
│   ├── feature-implementation.md
│   └── git-manager.md
├── architecture/                # Created on first use
│   └── module-map.md
├── context/                     # Created on first use
│   └── ubiquitous-language.md
├── plans/                       # Created on first use
│   └── <feature-slug>.md
├── skills/
│   ├── bootstrap.md
│   ├── resolve-adopted-artifacts.md
│   ├── grill-me.md
│   ├── ubiquitous-language.md
│   ├── improve-architecture.md
│   ├── tdd.md
│   ├── feature-start.md
│   ├── retro.md
│   └── fabricate-beads-history.md
└── workflows/
    └── feature-workflow.md
```

When scaffolded in `all`, `codex`, or `antigravity` mode, the repo also gets:

```
AGENTS.md                        # Tool-agnostic project contract
.codex/
└── skills/
    ├── bootstrap.md
    ├── resolve-adopted-artifacts.md
    ├── grill-me.md
    ├── feature-start.md
    ├── ubiquitous-language.md
    ├── improve-architecture.md
    ├── tdd.md
    ├── retro.md
    └── fabricate-beads-history.md
.antigravity/
└── skills/
    ├── bootstrap.md
    ├── resolve-adopted-artifacts.md
    ├── grill-me.md
    ├── feature-start.md
    ├── ubiquitous-language.md
    ├── improve-architecture.md
    ├── tdd.md
    ├── retro.md
    └── fabricate-beads-history.md
```

## Template Development

Templates live in `bootstrap-templates/templates/universal/`. All templates use `{{PLACEHOLDER}}` syntax. See the template files for the full list of available variables.

## Adopting Into Existing Projects

When `scripts/scaffold.sh` encounters a pre-existing file at any scaffold target path, it preserves the file first and then continues:

- `AGENTS.md` becomes `AGENTS.pre-scaffold.md`
- `.claude/CLAUDE.md` becomes `.claude/CLAUDE.pre-scaffold.md`

Those preserved backups are recorded in `.agent-scaffold.json` under temporary `adoptionConflicts` state. While that state exists, later scaffold runs fail until you review and resolve the preserved artifacts.

The resolution flow is:
1. Run `/resolve-adopted-artifacts`
2. Extract any template-worthy guidance
3. Archive the preserved backups under `docs/legacy-agent-artifacts/` using mirrored directory structure
4. Clear `adoptionConflicts` so scaffold refreshes can proceed again

## How It Improves Over Time

1. You run `/retro` after a feature — it analyzes what worked and what didn't
2. Generalizable findings get propagated back into `bootstrap-templates/`
3. Other projects using this scaffold re-run `scripts/scaffold.sh` to pull forward template changes
4. The system gets better with every project
