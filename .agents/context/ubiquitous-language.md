# Ubiquitous Language — agent-bootstrap

Canonical terms used across planning, implementation, and documentation.

## Scaffold Concepts

| Canonical term | Aliases to avoid | Definition | Source |
|---|---|---|---|
| Agent harness | platform, AI tool | The system running an agent: Claude Code, Codex, or Antigravity. | `scripts/scaffold.sh` |
| Scaffold | bootstrap, generate | Running `scripts/scaffold.sh` against a target project to produce managed agent, Beads, and Git-hook artifacts plus scaffold state. | `README.md` |
| Universal template | core template | Harness-neutral source under `bootstrap-templates/templates/universal/`. | `bootstrap-templates/templates/universal/` |
| Scaffold state | manifest | `.agent-scaffold.json`, which records rendered files, checksums, variables, harness, and template version. | `.claude/scaffold-state-spec.md` |
| Scaffold refresh | sync, pull | Re-running the scaffold to apply forward template changes without overwriting local drift. | `scripts/scaffold.sh` |
| Scaffold preflight | dry apply | The complete render and validation phase that detects blockers before any target-side mutation. | `scripts/scaffold.sh --check` |
| Apply phase | render phase | Installation of a successfully preflighted plan, with scaffold state written last. It is not a rollback transaction. | `scripts/scaffold.sh` |
| Adoption conflict | legacy collision | A pre-existing non-managed target that remains active while a scaffold candidate is recorded for explicit resolution. | `.agent-scaffold.json` |
| Migration blocker | adoption conflict | A known managed legacy contract that makes refresh stop with zero target writes until explicitly resolved. | `scripts/scaffold.sh` |
| Clone contract | Beads contract | `.beads/clone-contract.json`, whose paths are repository-root-relative and whose tracked recovery export is `.beads/issues.jsonl`. | `.beads/clone-contract.json` |

## Workflow Concepts

| Canonical term | Aliases to avoid | Definition | Source |
|---|---|---|---|
| Feature spec | plan file | Approved implementation contract at `.agents/plans/<feature-slug>.md`. | `.agents/workflows/feature-workflow.md` |
| Original worktree baseline | pre-commit status | Branch, HEAD, staged/unstaged/untracked paths, and overlapping dirty patches captured before the first mutation. | `AGENTS.md` |
| Task-owned change ledger | TODO list | In-session record of changes attributable to the current task, carried with the original baseline through handoffs. | `AGENTS.md` |
| Commit preparation | pre-commit mutation | Explicit pre-review generation and Beads export through `.githooks/prepare-commit`; it must not stage files. | `.githooks/prepare-commit` |
| Preparation extension | local hook | Optional project-owned `.githooks/prepare-commit.local`, allowed to update the worktree but not the index. | `.githooks/prepare-commit` |
| Validation extension | local hook | Optional project-owned `.githooks/pre-commit.validate`, required to be read-only. | `.githooks/pre-commit` |
| Reviewed tree | staged diff | The staged Git tree identified by `git write-tree` and approved together with its base HEAD. | `.claude/agents/git-manager.md` |
| Monitoring authority | fix authority | Permission to persistently observe and report; it does not itself authorize retries, mutations, deployments, or messages. | `AGENTS.md` |
| Deployment authorization | TDD approval | Explicit authority naming the live operation and target environment. | `.claude/skills/tdd.md` |

## Durable Artifacts and Roles

| Canonical term | Aliases to avoid | Definition | Source |
|---|---|---|---|
| Ubiquitous language | glossary | This provider-neutral terminology file. | `.agents/context/ubiquitous-language.md` |
| Module map | architecture map | Provider-neutral architecture boundaries at `.agents/architecture/module-map.md`. | `AGENTS.md` |
| Skill | slash command | Reusable workflow source rendered into one or more harness skill directories. | `bootstrap-templates/templates/universal/skills/` |
| Agent role | sub-agent | A bounded role contract such as Feature-Implementation or Git-Manager. | `bootstrap-templates/templates/universal/agents/` |
| Beads task | issue, TODO | The durable tracked body of work managed with `bd`. | `AGENTS.md` |
| Mandatory gate | checkpoint | A point requiring explicit approval for the named operation. Permissions at different gates do not imply one another. | `AGENTS.md` |
