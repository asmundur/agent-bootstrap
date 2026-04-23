# Retrospective Skill

You are running a retrospective for **agent-bootstrap**. This skill analyzes a completed feature, identifies what worked and what didn't, and propagates generalizable improvements back into the bootstrap template.

## Phase 1 — Load Context

```bash
git log --oneline -20
git branch --show-current
```

Read these files when they exist before you ask retrospective questions:
- `.claude/context/ubiquitous-language.md`
- `.claude/architecture/module-map.md`
- `.claude/plans/` for the relevant feature spec

Ask the user: "Which feature or branch should we retrospect on?"

## Phase 2 — Gather Evidence

```bash
git log <branch> --oneline
git diff main...<branch>
```

Read the relevant changed files. Build a picture of what was implemented, how long it took (from commit timestamps), what the diff looks like, and whether the shipped work matched the approved feature spec.

## Phase 3 — Present Overview & Get User Input

Show the user:
- Files changed, lines added/removed
- Number of commits
- Commit messages (do they tell a coherent story?)
- Whether the feature spec, glossary, and module map were used or drifted

Ask:
1. "What went well? What would you do the same way?"
2. "What was frustrating or slower than it should have been?"
3. "Was anything unclear or ambiguous at the start?"
4. "Did terminology drift between the plan, the code, and the user-facing language?"
5. "Did module boundaries help or get in the way?"
6. "Which feedback loops caught issues early, and which were missing or too slow?"

## Phase 4 — Identify Successes

For each success, document:
- What was it?
- Why did it work? (the mechanism, not just "it was good")
- Is it replicable? (could a different agent on a different project do it the same way?)

## Phase 5 — 5W Root Cause Analysis on Failures

For each failure or friction point, apply:

- **What** happened?
- **Why** did it happen? (first cause)
- **Why** did that happen? (second cause)
- **Why** did that happen? (root cause — keep asking until you hit a process or assumption)
- **Where** in the workflow did it occur? (planning, implementation, review, commit)
- **Who** is responsible for fixing it? (agent behavior, template content, workflow definition, anti-patterns file)

Also classify whether the failure came from:
- Missing shared design
- Term drift / poor ubiquitous language
- Weak module boundaries
- Outrun feedback loops
- Something else

## Phase 6 — Generalizability Test

For each finding, ask: *"Would this improvement help ANY project using this bootstrap, or only agent-bootstrap?"*

- **Universal** → candidate for template propagation
- **Project-specific** → add to local `.claude/anti-patterns.md` only

Exclude findings that are:
- Generic best practices already known
- One-off bugs with no systemic cause
- Highly domain-specific to agent-bootstrap

## Phase 7 — Action Items

Produce a prioritized list:

| Priority | Finding | Action | Target File |
|---|---|---|---|
| High | ... | Add anti-pattern entry | `.claude/anti-patterns.md` |
| High | ... | Update glossary | `.claude/context/ubiquitous-language.md` |
| High | ... | Update module map | `.claude/architecture/module-map.md` |
| Medium | ... | Update workflow checkpoint | `.claude/workflows/feature-workflow.md` |
| Low | ... | Clarify agent instructions | `.claude/agents/feature-implementation.md` |

If terminology or module boundaries changed, propose the concrete updates to the local glossary or module map as part of the retrospective output. These local artifact updates are project maintenance, not template propagation.

## Phase 8 — Template Propagation (MANDATORY CHECKPOINT)

For each universal finding, show the user the proposed change to the bootstrap template in `bootstrap-templates/templates/universal/`.

**Stop and get user approval before writing any template changes.**

Say: "I'd like to propagate these [N] findings to the bootstrap template. Here are the proposed changes — approve to write them?"

After approval, make the changes to the template files. This ensures future projects bootstrapped from this template benefit from what you learned.
