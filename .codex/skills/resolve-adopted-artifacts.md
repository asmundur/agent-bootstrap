# Resolve-Adopted-Artifacts Skill

You are running the `resolve-adopted-artifacts` skill for **agent-bootstrap**. Your job is to resolve all unresolved scaffold adoption conflicts in one pass.

This skill exists for the case where `scripts/scaffold.sh` preserved pre-existing artifacts as `*.pre-scaffold.*` backups during first-time scaffold adoption.

## Goal

Review every preserved backup, extract any reusable template value, archive the legacy artifacts under `docs/legacy-agent-artifacts/`, and then clear the temporary `adoptionConflicts` state from `.agent-scaffold.json`.

Do not resolve conflicts one-by-one. This is an all-at-once pass.

## Step 1 — Load The Conflict Set

Read `.agent-scaffold.json`.

If `adoptionConflicts` is missing or empty, stop and tell the user there is nothing to resolve.

For each conflict, load:
- the original `target`
- the sibling `preservedBackup`
- the recorded checksums and capture timestamp

Before doing anything else:
- verify every `preservedBackup` still exists
- verify its current checksum still matches `preservedChecksum`

If any preserved backup is missing or drifted, stop and report it clearly. Do not guess at resolution from modified backups.

## Step 2 — Read Before Asking

For each preserved backup, read:
- the preserved backup itself
- the scaffolded file currently at `target`
- relevant local context such as `.claude/context/ubiquitous-language.md`, `.claude/architecture/module-map.md`, and the relevant feature spec when useful

Use the `grill-me` method on the artifacts first:
- what value did the legacy file provide?
- what value is already covered by the scaffolded replacement?
- what is genuinely new or missing?
- is that missing value universal enough to help any project using this scaffold?

Answer as much as you can from the files before asking the user anything.

## Step 3 — Classify Findings

For each meaningful finding, classify it as exactly one of:

1. **Template-worthy**
   - useful to any project using agent-bootstrap
   - belongs in `bootstrap-templates/templates/universal/`

2. **Obsolete / noise**
   - project-local, stale, redundant, or not worth preserving in active scaffold docs
   - archive it locally only

Do not propagate purely project-local legacy guidance into active scaffold files in this repo. Preserve it only through archival.

## Step 4 — Present Proposed Template Improvements

Summarize the preserved artifacts and extracted findings.

Then separate:
- findings you can justify directly from the files
- any user-input questions that only the user can answer

For template-worthy findings, present proposed template changes in the same style as `/retro`.

**Stop and get user approval before writing any template changes.**

## Step 5 — Archive The Legacy Artifacts

Once the findings are captured:
- create `docs/legacy-agent-artifacts/` when needed
- move each `preservedBackup` into that tree using mirrored directory structure relative to the project root

Examples:
- `AGENTS.pre-scaffold.md` -> `docs/legacy-agent-artifacts/AGENTS.pre-scaffold.md`
- `.claude/CLAUDE.pre-scaffold.md` -> `docs/legacy-agent-artifacts/.claude/CLAUDE.pre-scaffold.md`

Do not flatten the tree. Preserve original relative paths.

## Step 6 — Clear Temporary Conflict State

After all preserved backups are archived and any approved template changes are made:
- remove `adoptionConflicts` from `.agent-scaffold.json`

The scaffold state should not retain resolved conflict history.

## Step 7 — Report Completion

Report:
- how many adoption conflicts were resolved
- which preserved backups were archived
- which findings were template-worthy versus obsolete/noise
- whether any template changes were proposed or applied

Once complete, the repo is eligible to run `scripts/scaffold.sh` again.
