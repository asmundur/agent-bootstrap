# README Rewrite

## Summary

Rewrite `README.md` so it explains what `agent-bootstrap` is, what it is not, how to use it today, and how to contribute without relying on internal jargon or unsupported claims.

## Goal

Give a new contributor enough context to:
- understand the repository purpose in one pass
- apply the scaffold to another project correctly
- know which commands are real today
- see the current limits and rough edges honestly

## Non-Goals

- Do not change scaffold behavior
- Do not invent automation that is not present in the repo
- Do not document speculative future features as shipped behavior

## Affected Files

- `README.md`

## Acceptance Criteria

- README states the repo purpose in plain language
- README documents the scaffold flow accurately: apply scaffold, then run `/bootstrap` in the target repo
- README reflects current repo reality, including unknown project metadata and unconfigured feedback loops where relevant
- README is shorter, calmer, and easier to scan than the current version

## Verification

- Manual review against `scripts/scaffold.sh`, `.agent-scaffold.json`, `AGENTS.md`, and `.claude/context/ubiquitous-language.md`
