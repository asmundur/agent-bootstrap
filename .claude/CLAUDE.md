@AGENTS.md

## Agent Registry

| Agent | Model | Responsibility |
|---|---|---|
| Feature-Implementation | claude-sonnet-4-6 | Implements code, writes tests, cleans up |
| Git-Manager | claude-haiku-4-5-20251001 | Stages files, creates semantic commits |

## Worktree And Authorization Contract

Before the first repository or task-tracker mutation — including task claim, spec write, branch operation, generated-file refresh, or edit — capture the original branch/HEAD and staged, unstaged, and untracked worktree baseline. Start a task-owned change ledger after capture and pass both records through every handoff. Never redefine the post-implementation worktree as the baseline.

Implementation approval authorizes only the in-scope repository edits and non-mutating feedback loops described by the contract. Feature branches use the validated branch-safe name `feature/<feature-slug>` and require explicit approval of the exact create/switch operation. If the user explicitly declines the proposed feature branch, continue on the current branch unless they ask to stop.

A monitoring or babysitting request authorizes persistent observation only. Without separate mutation authority, limit activity to polling, logs/status inspection, read-only diagnosis, and reporting. Retries, restarts, fixes, deployments, repository edits, external writes, and messages require their own authorization.

Infrastructure red/green checks are non-mutating. A live apply/deploy is release work, not a TDD check, and requires explicit authorization naming the target and operation.

Commit review has two checkpoints. First approve the implementation diff and exact preparation/staging plan, including separate source and expected generated paths. Then stage approved sources individually, run `.githooks/prepare-commit`, stop if its output exceeds the approved scope, stage approved generated outputs individually, and obtain commit approval for `git diff --cached --name-status`, the full `git diff --cached`, current `git rev-parse HEAD`, and `git write-tree`. If HEAD or the tree identity changes, repeat the final review. Pre-commit hooks validate only and must not modify or stage files.

## Workflow Orchestration

| User Intent | Skill / Workflow |
|---|---|
| Hydrate scaffold values from the codebase | `/bootstrap` → `.claude/skills/bootstrap.md` |
| Resolve preserved pre-scaffold artifacts | `/resolve-adopted-artifacts` → `.claude/skills/resolve-adopted-artifacts.md` |
| Reach shared design before planning | `/grill-me` → `.claude/skills/grill-me.md` |
| Build or refresh the project glossary | `/ubiquitous-language` → `.claude/skills/ubiquitous-language.md` |
| Propose better module boundaries | `/improve-architecture` → `.claude/skills/improve-architecture.md` |
| Work in strict red/green/refactor loops | `/tdd` → `.claude/skills/tdd.md` |
| Start a new feature | `/feature-start` → `.agents/workflows/feature-workflow.md` |
| Review what worked after a feature | `/retro` → `.claude/skills/retro.md` |
| Audit or improve Beads task quality | `/audit-beads-quality` → `.claude/skills/audit-beads-quality.md` |
| Task tracking | See `AGENTS.md` for mandatory gates and high-fidelity task creation commands |

## Durable Artifacts

- `.agents/plans/<feature-slug>.md` — approved feature specs and implementation contracts
- `.agents/context/ubiquitous-language.md` — canonical domain terms and aliases to avoid
- `.agents/architecture/module-map.md` — target modules, interfaces, dependencies, and interface-level tests

Load the glossary and module map before planning or implementation when they exist.

## Mandatory Gates

Claude **must stop and get user approval** before:
1. Starting tracked implementation work without a claimed Beads task (Mandatory Gate). Read-only discussion and slash-command skills that explicitly opt out of Beads do not need task churn.
2. Transitioning from Stage 1 (planning) to Stage 2 (implementation)
3. Creating or switching branches, unless the exact operation was already explicitly approved
4. Running a live apply/deploy, unless the exact target and operation were already explicitly approved
5. Running `.githooks/prepare-commit` and staging the proposed file set
6. Committing the exact cached diff, HEAD, and tree identity
7. Propagating findings from retro to the bootstrap template
8. Any destructive git operation

## Anti-Patterns

See `.agents/anti-patterns.md` for hard constraints that agents must follow. Agents should read this file at the start of any implementation task.
