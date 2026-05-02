# agent-bootstrap

`agent-bootstrap` is a reusable scaffold for agent-assisted software development.

The goal is simple: give an existing repository a consistent set of project rules, planning artifacts, workflow skills, and task-tracking conventions without tying the project to a specific language or framework.

## What It Is

This repository contains:

- a scaffold applicator: `scripts/scaffold.sh`
- the source templates for that scaffold: `bootstrap-templates/templates/universal/`
- local generated copies of the scaffold so this repo uses its own system

Applied to another repository, the scaffold adds:

- `AGENTS.md` as the project contract
- `.claude/` workflow docs, skills, plans, and context artifacts
- optional harness mirrors under `.codex/` and `.antigravity/`
- Beads task-tracking support under `.beads/`
- git hook support under `.githooks/`

## Why It Exists

Most agent-driven coding workflows break down in the same places:

- project expectations live in scattered prompts instead of durable files
- planning is implicit, so scope drifts
- architecture context is tribal knowledge
- retrospectives do not feed back into the next project

`agent-bootstrap` packages those concerns into a scaffold that can be applied, reviewed, and evolved like normal code.

## Current Scope

This is an experimental but real tool, not a polished platform.

What is stable today:

- `scripts/scaffold.sh` applies and refreshes the scaffold
- scaffold-managed files are tracked in `.agent-scaffold.json`
- existing files are preserved rather than overwritten during adoption
- generated workflows center on design-first planning, durable specs, and Beads-backed task tracking

What is intentionally left to the target project:

- build, test, lint, and run commands
- language- or framework-specific conventions
- how much of the generated workflow a team actually adopts

## Quick Start

Apply the scaffold from the target repository:

```bash
/path/to/agent-bootstrap/scripts/scaffold.sh
```

Or specify the target directory and harness explicitly:

```bash
/path/to/agent-bootstrap/scripts/scaffold.sh [target-dir] [all|claude-code|codex|antigravity]
```

After first scaffold adoption, run the generated `/bootstrap` skill in the target repository. That step is responsible for reading the repository and hydrating project-specific values into the scaffold. Later scaffold refreshes do not require `/bootstrap` unless project facts need to be re-read from the codebase.

If the scaffold preserved pre-existing files as `*.pre-scaffold.*`, resolve them before the next refresh with `/resolve-adopted-artifacts`.

## What The Scaffold Does

On apply, the scaffold:

- creates the expected workflow directories
- renders the template set into the target repository
- writes `.agent-scaffold.json` as the scaffold state file
- preserves colliding files instead of silently replacing them
- refuses to overwrite drifted scaffold-managed files
- attempts `bd bootstrap --yes --json` when Beads is available

The legacy `scripts/bootstrap.sh` entrypoint remains as a thin wrapper around `scripts/scaffold.sh`.

## Repository Layout

```text
bootstrap-templates/
  templates/universal/   source templates
scripts/                 scaffold entrypoints and smoke tests
.claude/                 local generated scaffold and project docs
.beads/                  local task-tracking state
.githooks/               local git hook support
```

## Developing This Repo

If you are working on `agent-bootstrap` itself:

- edit template behavior in `bootstrap-templates/templates/universal/`
- re-run `scripts/scaffold.sh` to refresh generated local files
- keep docs aligned with the actual scaffold contract
- use Beads for tracked work; this repo uses the `age` prefix

The main verification path today is the scaffold smoke test in [scripts/smoke-test-scaffold.sh](/Users/auzi/vinnustofa/agent-bootstrap/scripts/smoke-test-scaffold.sh).
