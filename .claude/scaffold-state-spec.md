# Scaffold State Specification

## Purpose

`.agent-scaffold.json` is the authoritative log of every scaffold-managed file the scaffold command automatically generated for a project. It serves three purposes:

1. **Audit**: a precise list of what the scaffold created, so you can see exactly what is scaffold-managed.
2. **Cleanup**: enables removal of agent-bootstrap from a project without leaving orphaned scaffold files.
3. **Re-application**: provides the canonical scaffold variables and file checksums so the scaffold can be re-applied without re-prompting a human and without overwriting drifted scaffold-managed files.

## Location

`.agent-scaffold.json` at the project root. One scaffold state file covers all harness mirrors (`.claude/`, `.codex/`, `.antigravity/`).

## Format

```json
{
  "generatedBy": "agent-bootstrap",
  "templateVersion": "1.2.0",
  "generatedAt": "2026-04-26T12:34:56Z",
  "agentHarness": "all",
  "templateSource": "bootstrap-templates/templates/universal",
  "variables": {
    "PROJECT_NAME": "my-project",
    "TECH_STACK": "Go",
    "BUILD_COMMAND": "go build ./...",
    "TEST_COMMAND": "go test ./...",
    "...": "…"
  },
  "files": [
    { "target": ".claude/CLAUDE.md", "source": "CLAUDE.md.tmpl", "category": "config", "checksum": "..." },
    { "target": ".claude/skills/bootstrap.md", "source": "skills/bootstrap.md.tmpl", "category": "skill", "checksum": "..." },
    { "target": ".beads/config.yaml", "source": "beads/config.yaml.tmpl", "category": "beads", "checksum": "..." },
    { "target": ".githooks/pre-commit", "source": "githooks/pre-commit", "category": "hook", "checksum": "..." }
  ]
}
```

## Fields

| Field | Purpose |
|---|---|
| `generatedBy` | Always `"agent-bootstrap"`. Identifies scaffold-state files from this tool. |
| `templateVersion` | Version of the scaffold template that generated this state. |
| `generatedAt` | ISO-8601 UTC timestamp of the scaffold application run. |
| `agentHarness` | One of `all`, `claude-code`, `codex`, `antigravity`. Determines which harness mirrors were generated. |
| `templateSource` | Path (relative to the agent-bootstrap repo) where templates live. Used by `scripts/scaffold.sh` to locate scaffold templates for forward refresh. |
| `variables` | Canonical writable scaffold values. The scaffold command reads them to re-render managed files. The `/bootstrap` skill updates them from repository evidence. |
| `files` | Authoritative log of scaffold-managed files. Each entry: `target` (path relative to project root), `source` (template name relative to `templateSource`), `category` (`config` / `agent` / `skill` / `workflow` / `beads` / `hook`), and `checksum` (the last scaffold-rendered content hash used for drift detection). |

## Accuracy Guarantee

`files` is built at runtime by `scripts/scaffold.sh` from a tracker that records every successful template render. Conditional branches (`AGENT_HARNESS` gates) only contribute entries for files that were actually written. Before overwriting a scaffold-managed file on a later run, the command compares the current file checksum against the stored checksum and fails loud on local drift.

## Usage

### During Scaffold Application

The command generates the state file at the end of the run after creating or refreshing scaffold-managed files. Projects should commit it to version control.

### For Cleanup

To remove scaffold-managed files from a project:

```bash
jq -r '.files[].target' .agent-scaffold.json | xargs rm -rf
rm .agent-scaffold.json
```

This removes only scaffold-managed files. Project-local working artifacts (`.claude/plans/`, `.claude/context/`, `.claude/architecture/`, `.beads/issues.jsonl`) are intentionally not in the scaffold state, so cleanup leaves them alone.

### For `/bootstrap`

The skill reads and updates `variables`, then refreshes scaffold-managed files that depend on those values.

### For Forward Refresh

Re-run `scripts/scaffold.sh`. It is the only forward refresh path for scaffold-managed files.

## Notes

- The scaffold state is the source of truth.
- Commit the scaffold state to git.
- Do not edit it by hand unless you understand the consequences.
- The scaffold state file itself is not listed inside `files`; `rm .agent-scaffold.json` is a separate cleanup step.
