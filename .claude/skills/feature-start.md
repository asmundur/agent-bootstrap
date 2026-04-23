# Feature-Start Skill (Stage 0 + Stage 1)

You are running the planning portion of the feature workflow for **agent-bootstrap**. This is an interactive design-and-planning stage. Do not write any code yet.

## Your Goal

Produce a fully-specified, user-approved feature spec and implementation contract that the Feature-Implementation agent can execute without ambiguity.

## Stage 0 — Load Shared Context

Before asking questions, load the durable project context when it exists:

- `.claude/context/ubiquitous-language.md`
- `.claude/architecture/module-map.md`

Then explore the codebase to understand:
- Where similar features live in `bootstrap-templates/templates/universal`
- Existing module boundaries, naming conventions, and abstractions to reuse
- Test structure and the fastest feedback loops available for this feature

If the request is ambiguous, has multiple reasonable designs, or touches module boundaries, switch into `grill-me` mode:
- Ask decision-shaping questions until the important branches of the design tree are resolved or explicitly parked
- Resolve dependencies between decisions one by one instead of collecting loose preferences
- Record all important decisions, assumptions, and open questions in the feature spec

## Stage 1 — Define the Feature Spec

Create or update `.claude/plans/<feature-slug>.md` with:

- Summary
- Goal and non-goals
- Constraints
- Canonical terms to use
- Affected modules
- Interface changes
- Acceptance criteria in Given/When/Then format
- Feedback loops for this feature:
  - Typecheck: `not configured`
  - Lint: `not configured`
  - Browser verification: `not configured`
  - Tests: `bash scripts/smoke-test-bootstrap.sh`
- Implementation slices in execution order
- Beads-ready task slices for any work that should be split across multiple units
- Open questions or explicitly parked decisions

If a feedback-loop command is `not configured`, mark it as intentionally skipped in the spec instead of pretending it exists.

## Stage 2 — Prepare the Implementation Contract

Present to the user:
- The feature summary
- The shared design decisions that matter
- Acceptance criteria
- Affected modules and interface changes
- The chosen feedback loops
- The implementation slices
- The spec path

If your tool supports session task tracking, mirror the implementation slices there as well. The spec remains the durable source of truth.

## Phase 5 — User Approval (MANDATORY CHECKPOINT)

Present to the user:
- Summary of the feature
- Acceptance criteria
- Implementation slices
- Estimated scope (number of files, rough complexity)
- Spec path: `.claude/plans/<feature-slug>.md`

**Stop here and wait for explicit approval before proceeding.**

Say: "Ready to hand off to the Feature-Implementation agent. Approve to continue to Stage 2?"

## Phase 6 — Create Feature Branch

After approval:
```bash
git checkout -b feature/agent-bootstrap-<short-description>
```

Then hand off to the Feature-Implementation agent with:
- Spec path
- Shared design decisions
- Affected modules
- Interface changes
- Chosen feedback loops
- The acceptance criteria
- The implementation slices
- The relevant file paths found during exploration
- The commands:
  - Build: `printf 'No build step for this template repo\n'`
  - Typecheck: `not configured`
  - Lint: `not configured`
  - Browser verification: `not configured`
  - Test: `bash scripts/smoke-test-bootstrap.sh`
