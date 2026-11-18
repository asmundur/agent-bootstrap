# TDD Skill

You are running the `tdd` skill for **agent-bootstrap**. Your job is to drive implementation through small feedback loops instead of large unverified code drops.

## Your Default Loop

Work in strict red/green/refactor cycles:
1. Pick the next smallest observable behavior from the approved feature spec
2. Write the failing test or other failing observable check first
3. Run the fastest relevant feedback loop and confirm it fails for the expected reason
4. Make the smallest code change that can make the check pass
5. Run the relevant feedback loops again
6. Refactor while the checks stay green
7. Repeat

## Infrastructure And YAML Contract TDD

For infrastructure, deployment, configuration, and YAML-heavy work, treat TDD
as contract-first delivery rather than ordinary feature construction. The red
phase should prove that an unsafe or ambiguous state is rejected before any
mutation happens.

Prefer checks that enforce:
- preflight validation before host, cloud, DNS, database, queue, secret, or
  deployment mutation
- explicit failure before runtime drift, implicit defaults, or partial success
- small reversible steps with a clear blast radius
- failure messages that name the violated contract and the recovery path
- no silent fallback behavior and no hidden partial success

For YAML or declarative config, write contract checks around the rendered or
effective behavior when possible, not only around syntax. Examples include
rendered Compose services, Kubernetes manifests, Ansible inventory variables,
GitHub Actions workflow ordering, Terraform plans, Caddy routes, secret
delivery paths, and public ingress rules.

Red and green checks are non-mutating by default: render, parse, lint, policy,
plan, preflight, read-only smoke checks, or a documented dry run
that guarantees no apply. A failed live apply/deploy is not a red check because
it may already have partially mutated external state. A successful live deploy
is release verification after the contract is green, not the green phase.

Run a live apply/deploy only when the user explicitly authorized the exact
target and operation, either in the approved implementation handoff or in a
later message. Before applying, verify the non-mutating checks, expected blast
radius, and recovery path. If deployment fails, stop with a named blocker or
follow only the separately authorized recovery action; do not turn repeated
deployments into a feedback loop. Never weaken a guardrail just to make a
deploy pass.

## Required Inputs

Before starting, read:
- The approved `.agents/plans/<feature-slug>.md`
- `.agents/context/ubiquitous-language.md` when it exists
- `.agents/architecture/module-map.md` when it exists

If the approved spec or shared context still exists only under legacy `.claude/...` paths, read it as migration evidence and keep new updates under `.agents/`.

Receive the original worktree baseline and task-owned change ledger from the planning handoff. If `/tdd` is the direct entry path and no mutation has happened, capture the original baseline before any task claim, spec write, branch operation, or edit:

```bash
git status --short --branch --untracked-files=all
git diff --name-status
git diff --cached --name-status
git ls-files --others --exclude-standard
```

If mutation already happened without a trustworthy original baseline, stop rather than recapturing the current worktree and guessing ownership. Record each TDD edit in the task-owned change ledger. Do not create or switch branches, stage files, commit, emit commit/stage directives, or run a live apply/deploy unless the user explicitly approved that exact operation. Approval to implement with `/tdd` authorizes only code/test edits and non-mutating feedback loops by default.

## Feedback Loops

Use these commands when they are configured:
- Typecheck: `not configured`
- Lint: `not configured`
- Browser verification: `not configured`
- Tests: `not configured`

If a command is literally `not configured`, skip it. Otherwise, treat it as part of the development speed limit.

## How Small Is Small Enough?

A slice is small enough when:
- A failing check clearly points at the last edit
- The change can be explained by one acceptance criterion or one sub-behavior
- The next refactor can still happen with confidence

If you find yourself writing a lot of code before running a check, you are outrunning your headlights. Stop and reduce the slice size.

## Testing Guidance

- Prefer tests at the module interface
- Avoid locking tests to internal implementation structure
- Mock only what you do not own or cannot conveniently exercise for real
- Use browser verification for user-facing behavior when the project has it configured

This skill is the default implementation style for the Feature-Implementation agent.

When finishing, report the original baseline, task-owned change ledger, changed files by intended scope, deployment authorization/result, and any dirty files that existed before or outside the work. Leave preparation, staging, final cached-diff review, and commit to the explicit review/commit workflow.
