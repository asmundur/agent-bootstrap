# Sync-Bootstrap Skill

You are running the sync-bootstrap skill for **agent-bootstrap**. This skill compares your local `.claude/` configuration against the upstream bootstrap template and lets you selectively import improvements.

## When to Use This

Run this after:
- The bootstrap template has been updated (e.g., another project's retro added new patterns)
- You want to pull in best practices discovered by other projects using this bootstrap

## Phase 1 — Locate Template Source

The bootstrap template lives at the path recorded in `.claude/.bootstrap-manifest.json` under `templateSource`.

Read `.claude/.bootstrap-manifest.json` to find `templateSource`.

## Phase 2 — Compare Files

Read `.claude/.bootstrap-manifest.json` and use its `files` list as the local source of truth for template-managed files.

Then compare two things:
1. Every template-managed file already recorded in the manifest
2. Any new upstream template files that are not recorded in the manifest yet, including new skills and Codex mirrors

Focus on **additions** — content in the template that doesn't exist locally. Don't flag differences caused by placeholder substitution.

Do **not** treat these runtime artifacts as drift, even if they are missing or have changed:
- `.claude/context/ubiquitous-language.md`
- `.claude/architecture/module-map.md`
- `.claude/plans/`

## Phase 3 — Present Import Menu

Show the user a numbered list of available improvements:

```
Available improvements from upstream template:

1. [anti-patterns.md] New anti-pattern: "Skipping context exploration before implementation"
2. [feature-workflow.md] Added context budget check before Stage 2 handoff
3. [feature-implementation.md] Clarified post-implementation cleanup checklist
4. [skills/grill-me.md] New shared-design interrogation skill
5. [skills/ubiquitous-language.md] New glossary generation skill

Enter numbers to import (comma-separated), or 'all', or 'none':
```

## Phase 4 — Adapt & Apply

For each selected item:
1. Replace any `{{PLACEHOLDER}}` values in the imported content with the project-specific values from `.bootstrap-manifest.json`
2. Insert the content into the appropriate local file at the appropriate location
3. Confirm each change with the user before writing

## Phase 5 — Report

List all changes applied and suggest refreshing the glossary or module map if the imported template changes introduced new planning behavior.
