# Feature Workflow — agent-bootstrap

This document defines the design-first feature development pipeline. It is referenced by the `/feature-start` skill.

---

## Stage 0 — Shared Design Alignment (Interactive)

**Skills:** `.claude/skills/feature-start.md`, `.claude/skills/grill-me.md`
**Mode:** Interactive with user
**Agent:** Main Claude instance

Goals:
- Load `.claude/context/ubiquitous-language.md` and `.claude/architecture/module-map.md` when they exist
- Reach a shared design concept for the feature
- Resolve high-impact decisions or explicitly park them
- Record the decisions in `.claude/plans/<feature-slug>.md`

**Exit condition:** The important design decisions have been resolved or clearly parked.

---

## Stage 1 — Feature Spec & Approval (Interactive)

**Skill:** `.claude/skills/feature-start.md`
**Mode:** Interactive with user
**Agent:** Main Claude instance

Goals:
- Clarify the feature request
- Explore codebase for reusable patterns
- Define acceptance criteria (Given/When/Then)
- Record affected modules, interface changes, and chosen feedback loops
- Create implementation slices and beads-ready task slices
- Create feature branch

**Exit condition:** User gives explicit approval to proceed.

**Handoff to Stage 2** — Pass to Feature-Implementation agent:
- Spec path
- Shared design decisions
- Affected modules
- Interface changes
- Chosen feedback loops
- Acceptance criteria
- Implementation slices
- Relevant file paths
- Build command: `not configured`
- Typecheck command: `not configured`
- Lint command: `not configured`
- Browser verification command: `not configured`
- Test command: `not configured`

---

## Stage 2 — Implementation

**Agent:** Feature-Implementation (`.claude/agents/feature-implementation.md`)
**Model:** claude-sonnet-4-6
**Mode:** Autonomous (no user interaction)

The agent will:
1. Read `.claude/anti-patterns.md`
2. Read the approved feature spec and load the glossary / module map when present
3. Explore identified files to understand patterns
4. Implement the feature in red/green/refactor slices
5. Run the configured feedback loops as the implementation evolves
6. Update shared terms or module boundaries if the feature changes them
7. Clean up (dead code, naming, DRY)
8. Report completion

**Context budget check:** If the feature is large enough to risk hitting context limits, split into sub-tasks and complete them sequentially. Never half-finish an implementation.

---

## Stage 2.5 — Human Review (MANDATORY CHECKPOINT)

**Mode:** Interactive with user

Run:
```bash
git diff main...HEAD
```

Present the diff to the user and ask: "Ready to commit? Approve to continue to Stage 3."

**Do not proceed until the user explicitly approves.**

---

## Stage 3 — Commit

**Agent:** Git-Manager (`.claude/agents/git-manager.md`)
**Model:** claude-haiku-4-5-20251001
**Mode:** Autonomous

The agent will:
1. Run `git status` + `git diff`
2. Stage files individually
3. Create a semantic commit (feat/fix/refactor/test/chore)
4. Verify with `git log`
5. Report commit hash

**Never push** without explicit user instruction.

---

## Workflow Summary

```
User: /feature-start
       │
       ▼
[Stage 0] Shared design ─────────► Decisions resolved
       │
       ▼
[Stage 1] Feature spec ──────────► User approval
       │
       ▼
[Stage 2] Feature-Implementation ► Tests passing
       │
       ▼
[Stage 2.5] Human review diff ──► User approval
       │
       ▼
[Stage 3] Git-Manager commit ───► Done
       │
       ▼
       (optional) /retro
```
