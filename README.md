# agent-bootstrap

A tech-agnostic Claude Code workflow orchestration system. Bootstrap any project with automated agents, skills, and workflows that guide feature development and improve over time.

Inspired by [aproorg/bootstrap-demo](https://github.com/aproorg/bootstrap-demo), but built to work across any language or tech stack.

## What It Does

- **Bootstrap** any project: scans your codebase, detects tech stack and commands, and generates a complete Claude Code orchestration setup
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

Any other stack can be configured manually during bootstrap.

## Getting Started

### 1. Install the bootstrap skill

Copy `.claude/skills/bootstrap/` from this repo into your project's `.claude/skills/` directory, or clone this repo and add it as a Claude Code plugin.

### 2. Run the bootstrap skill in your project

```
/bootstrap
```

Claude will:
1. Detect your tech stack and commands
2. Show you the detected values for confirmation
3. Generate all orchestration files into `.claude/`

### 3. Start developing features

```
/feature-start
```

Useful companion skills:

```
/grill-me
/ubiquitous-language
/improve-architecture
/tdd
```

### 4. After a feature is merged, run a retrospective

```
/retro
```

### 5. Pull improvements from the upstream template

```
/sync-bootstrap
```

## Generated File Structure

After bootstrapping a project, the following files are created in `.claude/`:

```
.claude/
├── CLAUDE.md                    # Project config and workflow routing
├── anti-patterns.md             # Hard constraints agents must follow
├── .bootstrap-manifest.json     # Tracks generated files + template variables
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
│   ├── grill-me.md
│   ├── ubiquitous-language.md
│   ├── improve-architecture.md
│   ├── tdd.md
│   ├── feature-start.md
│   ├── retro.md
│   ├── sync-bootstrap.md
│   └── fabricate-beads-history.md
└── workflows/
    └── feature-workflow.md
```

When bootstrapped in `both` or `codex` mode, the repo also gets:

```
AGENTS.md                        # Tool-agnostic project contract
.codex/
└── skills/
    ├── grill-me.md
    ├── ubiquitous-language.md
    ├── improve-architecture.md
    ├── tdd.md
    └── fabricate-beads-history.md
```

## Template Development

Templates live in `bootstrap-templates/templates/universal/`. All templates use `{{PLACEHOLDER}}` syntax. See the template files for the full list of available variables.

## How It Improves Over Time

1. You run `/retro` after a feature — it analyzes what worked and what didn't
2. Generalizable findings get propagated back into `bootstrap-templates/`
3. Other projects using this bootstrap run `/sync-bootstrap` to pull those improvements
4. The system gets better with every project
