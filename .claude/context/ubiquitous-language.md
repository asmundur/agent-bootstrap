# Ubiquitous Language — agent-bootstrap

Canonical terms used across planning, implementation, and documentation. Update this file whenever a feature renames or introduces a core concept.

## Core Concepts

| Canonical Term | Aliases to Avoid | Definition | Source Reference |
|---|---|---|---|
| Agent harness | tool target, platform, AI tool, runtime | The system that runs the AI agent (Claude Code, Codex, Antigravity). What `scaffold.sh` selects via `AGENT_HARNESS`. | `.claude/plans/charter.md` §"Antigravity Support"; `scripts/scaffold.sh` |
| Scaffold (verb) | bootstrap, generate, init | The act of running `scripts/scaffold.sh` against a target project to produce its `.claude/`, `.codex/`, `.antigravity/`, `.beads/`, and `.githooks/` files plus `.agent-scaffold.json`. | `README.md` §"Getting Started"; `scripts/scaffold.sh` |
| agent-bootstrap (noun) | the bootstrapper, the system | This project — the upstream repo containing templates and the bootstrap script. | `README.md`; `AGENTS.md` |
| Template | tmpl, source template | A `.md.tmpl` file under `bootstrap-templates/templates/universal/` containing `{{PLACEHOLDER}}` variables, copied into a target project during bootstrap. | `bootstrap-templates/templates/universal/` |
| Scaffold state | manifest, scaffold manifest, config json | `.agent-scaffold.json` — tracks every scaffold-managed file, the template version, and the scaffold variables for that project. | `.claude/plans/charter.md` §"Scaffold State Tracking" |
| Skill | command, slash command | A single reusable workflow document under `.claude/skills/` invoked as a slash command (e.g. `/grill-me`, `/tdd`). | `.claude/skills/`; `bootstrap-templates/templates/universal/skills/` |
| Workflow | pipeline, process | A multi-stage process document under `.claude/workflows/` that orchestrates skills and agents (e.g. `feature-workflow.md`). | `.claude/workflows/feature-workflow.md` |
| Agent (role) | sub-agent, persona | A scoped role document under `.claude/agents/` (Feature-Implementation, Git-Manager) defining model, responsibility, and instructions. Distinct from "agent harness". | `.claude/agents/` |

## Durable Artifacts

| Canonical Term | Aliases to Avoid | Definition | Source Reference |
|---|---|---|---|
| Feature spec | plan, design doc, plan file | The approved per-feature contract at `.claude/plans/<feature-slug>.md` produced by `/feature-start`. The file lives under `plans/` for historical reasons; the *content* is a spec. | `.claude/skills/feature-start.md`; `.claude/workflows/feature-workflow.md` |
| Ubiquitous language | glossary, terminology, vocab | This file. Canonical domain terms shared between user, code, and agents. | `.claude/skills/ubiquitous-language.md` |
| Module map | architecture map, structure doc | `.claude/architecture/module-map.md` — modules, public interfaces, dependencies, and recommended interface tests. | `.claude/skills/improve-architecture.md` |
| Anti-pattern | rule, hard constraint | An entry in `.claude/anti-patterns.md` — a non-negotiable rule that agents must read before any implementation task. | `.claude/anti-patterns.md` |
| Charter | project charter | `.claude/plans/charter.md` — the durable design document for agent-bootstrap itself. | `.claude/plans/charter.md` |

## Workflow Verbs & Stages

| Canonical Term | Aliases to Avoid | Definition | Source Reference |
|---|---|---|---|
| Stage 0 — Shared design alignment | grilling phase, design phase | Loading existing context and reaching a shared design concept before planning. | `.claude/workflows/feature-workflow.md` |
| Stage 1 — Feature spec & approval | planning, spec phase | Producing `.claude/plans/<feature-slug>.md` and obtaining user approval. | `.claude/workflows/feature-workflow.md` |
| Stage 2 — Implementation | build phase, coding | Autonomous Feature-Implementation agent execution under TDD. | `.claude/workflows/feature-workflow.md` |
| Stage 2.5 — Human review | diff review | Mandatory diff review before commit. | `.claude/workflows/feature-workflow.md` |
| Stage 3 — Commit | finalize | Git-Manager agent stages files individually and creates a semantic commit. | `.claude/workflows/feature-workflow.md` |
| Mandatory Gate | consultation point, mandatory checkpoint, approval gate | A point where the agent must stop and obtain explicit user approval before proceeding. | `AGENTS.md` §"Mandatory Gate"; `.claude/CLAUDE.md` §"Mandatory Gates" |
| Implementation slice | step, chunk, sub-task | The smallest unit of red/green/refactor work executed by the TDD skill. | `.claude/skills/tdd.md`; `.claude/skills/feature-start.md` |
| Feedback loop | check, verification command | One of the configured commands: build, typecheck, lint, browser verification, test, run. Each is either a real command or the literal string `not configured`. | `scripts/scaffold.sh`; `.claude/skills/tdd.md` |
| Bootstrap skill | scaffold hydration, project discovery | The `/bootstrap` skill — reads an existing repository, fills in scaffold variables, and refreshes scaffold-managed docs/config from that evidence. | `bootstrap-templates/templates/universal/skills/bootstrap.md.tmpl` |
| Retro | retrospective, postmortem | The `/retro` skill — post-feature analysis using 5W root cause that proposes generalizable findings back to the template. | `.claude/skills/retro.md` |
| Scaffold refresh | sync, pull, update | Re-running `scripts/scaffold.sh` to apply forward scaffold/template changes into a scaffolded project without overwriting drifted scaffold-managed files. | `scripts/scaffold.sh`; `.claude/scaffold-state-spec.md` |
| Template propagation | upstream sync, push back | Promoting a generalizable retro finding into `bootstrap-templates/templates/universal/` via a Mandatory Gate. | `.claude/skills/retro.md` §"Phase 8" |

## Tooling & Integrations

| Canonical Term | Aliases to Avoid | Definition | Source Reference |
|---|---|---|---|
| Beads | bd, beads tracker | The `bd` task tracker. Issues are stored in `.beads/issues.jsonl` and synced via Dolt. | `AGENTS.md` §"Task Tracking — Beads" |
| Beads task | issue, ticket, todo | A `bd` issue. The mandatory unit of work-tracking. Replaces TodoWrite/TaskCreate/markdown TODOs. | `AGENTS.md`; `CLAUDE.md` §"Beads Workflow" |
| Clone contract | beads contract | `.beads/clone-contract.json` — the readability contract that machine consumers must read instead of inferring from `metadata.json`. | `AGENTS.md` §"Git Integration & Clone Contract" |
| Universal template | core template, shared template | The stack-neutral, harness-neutral template tree at `bootstrap-templates/templates/universal/`. | `bootstrap-templates/templates/universal/` |
| Tech stack | stack, language | The build/test toolchain (Node/TS, Go, Rust, .NET, Python, Java/Kotlin) — discovered by the `/bootstrap` skill and used to populate scaffold variables. | `README.md` §"Supported Tech Stacks"; `scripts/scaffold.sh` |
| Placeholder | template variable, var | A `{{PLACEHOLDER}}` token in a `.tmpl` file substituted during scaffold application (e.g. `{{PROJECT_NAME}}`, `{{AGENT_HARNESS}}`). | `bootstrap-templates/templates/universal/` |

## Resolved Drift to Fix in Future Work

The glossary is now canonical. These spots in the codebase still use older variants and should be aligned in follow-up work (file under Beads before changing):

- None currently tracked.
