# Grill-Me Skill

You are running the `grill-me` skill for **agent-bootstrap**. Your job is to reach a shared design concept before implementation starts.

## When to Use This

Use this skill when:
- The request is ambiguous
- There are multiple reasonable designs
- The work changes module boundaries, terminology, or public interfaces
- The user has a clear goal but the design is still fuzzy

`/feature-start` may invoke this behavior automatically. You can also run it directly when you need a deeper design interrogation.

## Step 1 — Load the Existing Design Context

Before any task claim, feature-spec write, branch operation, or other repository mutation, capture the original worktree baseline:

```bash
git status --short --branch --untracked-files=all
git diff --name-status
git diff --cached --name-status
git ls-files --others --exclude-standard
```

Record the original branch and HEAD plus every staged, unstaged, and untracked path in the task/session context, then start a task-owned change ledger. If `/feature-start` or another workflow already supplied a trustworthy original baseline and ledger, reuse and extend them rather than recapturing a post-mutation worktree.

Before you ask questions, read these files when they exist:
- `.agent-scaffold.json`
- `.agents/context/ubiquitous-language.md`
- `.agents/architecture/module-map.md`
- Any existing `.agents/plans/<feature-slug>.md` for the same feature

If only legacy `.claude/...` planning artifacts exist, read them as migration evidence and write canonical updates under `.agents/`.

Then explore `src/` to understand the current implementation shape, similar features, and test boundaries.

## Step 2 — Interview Relentlessly

Ask focused questions until the important design branches are resolved or explicitly parked.

For exploratory prompts, guessing games, or design probes, use the useful part of cold reading without the fraud:
- Make broad, falsifiable reads instead of jumping to one precise answer.
- Offer 2-4 plausible hypotheses when the user's intent is intentionally under-specified.
- Label confidence and uncertainty plainly.
- Ask one small steering question that lets the user correct the frame with minimal effort.
- Treat the user's correction as signal, then narrow the hypothesis.
- Never present inference as evidence.

Good questions are:
- Scope-shaping
- Interface-shaping
- Dependency-shaping
- Risk-shaping
- Constraint-shaping

Do not stop at surface preferences. Walk down each branch of the design tree one dependency at a time.

Examples of the decisions you should force into the open:
- What problem are we solving?
- What is out of scope?
- Which module owns the behavior?
- Which public interface changes?
- What should the user observe when this is done?
- Which feedback loops prove the change works?
- What can be postponed without blocking implementation?

If a decision is truly unresolved, mark it as an explicit open question or parked decision. Do not silently guess.

## Step 3 — Write or Update the Feature Spec

Create or update `.agents/plans/<feature-slug>.md` with:
- Summary
- Goal
- Non-goals
- Constraints
- Canonical terms to use
- Affected modules
- Interface changes
- Acceptance criteria
- Feedback loops
- Mutation boundaries, including deployment authorization (`none` unless the exact target and operation were explicitly approved)
- Monitoring authorization (`observe-only` unless a bounded action was separately approved)
- Open questions / parked decisions

This file is the durable record of the shared design concept. Keep it concise, but do not leave hidden decisions buried in chat history. Record the feature-spec path as task-owned in the change ledger; keep the original baseline in task/session handoff context rather than writing a tracked side ledger.

## Step 4 — Decide Whether Planning Can Continue

You may hand back to `/feature-start` or the user once:
- The blocking design questions are resolved
- The remaining open questions are explicitly non-blocking
- The feature spec is concrete enough for implementation
- The original baseline and task-owned change ledger are ready to pass forward

If the design is still under-specified, keep grilling. The purpose of this skill is to prevent implementation from starting on vague intent.
