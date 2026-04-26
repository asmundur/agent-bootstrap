# Grill-Me Skill

You are running the `grill-me` skill for **agent-bootstrap**. Your job is to reach a shared design concept before implementation or major decisions are made.

## When to Use This

Use this skill when:
- The request is ambiguous
- There are multiple reasonable designs
- The work changes module boundaries, terminology, or public interfaces
- The user has a clear goal but the design is still fuzzy

Scope can be a single feature, a subsystem, an architectural decision, or repo-wide strategy. `/feature-start` may invoke this behavior automatically. You can also run it directly when you need a deeper design interrogation.

## Step 1 — Load the Existing Design Context

Before you ask questions, read these files when they exist:
- `.claude/context/ubiquitous-language.md`
- `.claude/architecture/module-map.md`
- Any existing `.claude/plans/*.md` related to this work

Then explore the relevant codebase to understand the current implementation shape, similar work, and test boundaries.

## Step 2 — Interview Relentlessly

Ask focused questions until the important design branches are resolved or explicitly parked.

Good questions are:
- Scope-shaping (what are we changing, what stays the same?)
- Interface-shaping (what APIs or contracts change?)
- Dependency-shaping (what does this pull in or depend on?)
- Risk-shaping (where could this break?)
- Constraint-shaping (what's non-negotiable?)

Do not stop at surface preferences. Walk down each branch of the design tree one dependency at a time.

Examples of the decisions you should force into the open:
- What problem are we solving?
- What is out of scope?
- Which module(s) own this behavior?
- Which public interface(s) change?
- What should users/systems observe when this is done?
- Which feedback loops prove the change works?
- What can be postponed without blocking this work?

If a decision is truly unresolved, mark it as an explicit open question or parked decision. Do not silently guess.

## Step 3 — Write or Update the Design Document

Create or update a plan file (e.g., `.claude/plans/<scope-slug>.md`) with:
- Summary
- Goal
- Non-goals
- Constraints
- Canonical terms to use
- Affected modules
- Interface changes
- Acceptance criteria
- Feedback loops
- Open questions / parked decisions

This file is the durable record of the shared design concept. Keep it concise, but do not leave hidden decisions buried in chat history.

## Step 4 — Decide Whether Work Can Continue

You may hand back to the user once:
- The blocking design questions are resolved
- The remaining open questions are explicitly non-blocking
- The design is concrete enough to move forward

If the design is still under-specified, keep grilling. The purpose of this skill is to prevent work from starting on vague intent.
