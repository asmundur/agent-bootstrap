# Feature-Start Skill (Stage 0 + Stage 1)

You are running the planning portion of the feature workflow for **agent-bootstrap**. This is an interactive design-and-planning stage. Do not write any code yet.

## Your Goal

Produce a fully-specified, user-approved feature spec and implementation contract that the Feature-Implementation agent can execute without ambiguity.

## Stage 0 — Load Shared Context

Before any task claim, feature-spec write, branch operation, or other repository mutation, capture the original worktree baseline:

```bash
git status --short --branch --untracked-files=all
git diff --name-status
git diff --cached --name-status
git ls-files --others --exclude-standard
```

Record the original branch and HEAD plus every staged, unstaged, and untracked path in the task/session context. Preserve the original patch for any already-dirty path the feature may also touch. Start a task-owned change ledger after capture. If `/grill-me` or another workflow already supplied a trustworthy original baseline and ledger, reuse and extend them instead of recapturing the current worktree.

Before asking questions, load the durable project context when it exists:

- `.agent-scaffold.json`
- `.agents/context/ubiquitous-language.md`
- `.agents/architecture/module-map.md`

If the repository only has legacy `.claude/context/`, `.claude/architecture/`, or `.claude/plans/` artifacts, read them as migration evidence and write the canonical spec/context updates under `.agents/`.

Then explore the codebase to understand:
- Where similar features live in `src/`
- Existing module boundaries, naming conventions, and abstractions to reuse
- Test structure and the fastest feedback loops available for this feature
- For debugging or CI work, the ownership boundary of the failure surface: repo code, generated code, vendored code, or environment

If the request is ambiguous, has multiple reasonable designs, or touches module boundaries, switch into `grill-me` mode:
- Ask decision-shaping questions until the important branches of the design tree are resolved or explicitly parked
- Resolve dependencies between decisions one by one instead of collecting loose preferences
- Record all important decisions, assumptions, and open questions in the feature spec

## Stage 1 — Define the Feature Spec

Create or update `.agents/plans/<feature-slug>.md` with:

- Summary
- Goal and non-goals
- Constraints
- Canonical terms to use
- Affected modules
- Interface changes
- Acceptance criteria in Given/When/Then format
- For debugging or CI specs, the chronology checkpoint: last passing state, first failing state, and suspected boundary of ownership
- Feedback loops for this feature:
  - Typecheck: `not configured`
  - Lint: `not configured`
  - Browser verification: `not configured`
  - Tests: `not configured`
- Implementation slices in execution order
- Beads-ready task slices for any work that should be split across multiple units
- Mutation boundaries, including whether any external apply/deploy is in scope
- Deployment authorization: `none` unless the user explicitly named the target and operation
- Monitoring authorization: `observe-only` unless the user separately authorized a bounded action
- Open questions or explicitly parked decisions

If a feedback-loop command is `not configured`, mark it as intentionally skipped in the spec instead of pretending it exists.

If the task is a small investigation or guidance change, keep user-facing process overhead proportional: record the contract, but avoid turning routine work into unnecessary ceremony.

## Stage 1 — Prepare the Implementation Contract

Present to the user:
- The feature summary
- The shared design decisions that matter
- Acceptance criteria
- Affected modules and interface changes
- The chosen feedback loops
- The implementation slices
- The spec path
- The original worktree baseline summary and current task-owned change ledger
- The branch, deployment, and monitoring authority boundaries

If your tool supports session task tracking, mirror the implementation slices there as well. The spec remains the durable source of truth.

## Stage 1 — User Approval (MANDATORY CHECKPOINT)

Present to the user:
- Summary of the feature
- Acceptance criteria
- Implementation slices
- Estimated scope (number of files, rough complexity)
- Spec path: `.agents/plans/<feature-slug>.md`
- Authority granted by approval: only the in-scope repository edits and non-mutating feedback loops described by the contract

**Stop here and wait for explicit approval before proceeding.**

Say: "Approve this implementation contract and continue to the branch decision? This approval authorizes only its in-scope repository edits and non-mutating feedback loops; branch creation, deployment, staging, and commit remain separate."

## Stage 1 — Optional Feature Branch Decision

After implementation approval, derive the branch name from the already branch-safe feature-spec slug, never from `agent-bootstrap`:

```bash
branch_name="feature/<feature-slug>"
git check-ref-format --branch "${branch_name}"
```

If validation fails or the branch already exists, stop and propose a corrected, explicit operation. Do not silently reuse, reset, or switch to an existing branch.

Present:
- Current branch
- Current HEAD
- Proposed create-and-switch operation: `git switch -c "feature/<feature-slug>"`
- The original baseline and task-owned files that would carry across the branch switch

Stop and ask: "Approve creating and switching to this feature branch, decline and continue on the current branch, or stop after planning?"

If the user approves the exact create-and-switch operation:

```bash
git switch -c "${branch_name}"
```

If the user explicitly declines the proposed feature branch, continue on the current branch and record that decision. If the user asks to stop, end after planning. After either approved implementation path, compare the current worktree with the original baseline plus task-owned planning changes and stop on unexplained drift.

Then hand off to the Feature-Implementation agent with:
- Spec path
- Original branch, HEAD, staged/unstaged/untracked baseline, and any preserved overlapping-path patch
- Task-owned change ledger, including the feature spec
- Branch decision and current branch/HEAD
- Deployment authorization: none, or the exact approved target and operation
- Monitoring authorization: observe-only, or the exact separately authorized action
- Shared design decisions
- Affected modules
- Interface changes
- Chosen feedback loops
- The acceptance criteria
- The implementation slices
- The relevant file paths found during exploration
- The commands:
  - Build: `not configured`
  - Typecheck: `not configured`
  - Lint: `not configured`
  - Browser verification: `not configured`
  - Test: `not configured`
