# Bootstrap Manifest Specification

## Purpose

`.claude/.bootstrap-manifest.json` is the authoritative log of every file the bootstrap script automatically generated for this project. It serves three purposes:

1. **Audit**: a precise list of what bootstrap created, so you can see exactly what is "yours" vs. "scaffolding".
2. **Cleanup**: enables removal of agent-bootstrap from a project without leaving orphaned files.
3. **Future updates**: foundation for `/sync-bootstrap` to reason about template evolution without overwriting local customizations.

## Location

`.claude/.bootstrap-manifest.json` (inside the primary harness directory). One manifest covers all harness mirrors (`.codex/`, `.antigravity/`).

## Format

```json
{
  "generatedBy": "agent-bootstrap",
  "templateVersion": "1.0.0",
  "generatedAt": "2026-04-26T12:34:56Z",
  "techStack": "Go",
  "toolTarget": "all",
  "templateSource": "bootstrap-templates/templates/universal",
  "variables": {
    "PROJECT_NAME": "my-project",
    "TECH_STACK": "Go",
    "BUILD_COMMAND": "go build ./...",
    "TEST_COMMAND": "go test ./...",
    "...": "…"
  },
  "files": [
    { "target": ".claude/CLAUDE.md", "source": "CLAUDE.md.tmpl", "category": "config" },
    { "target": ".claude/skills/grill-me.md", "source": "skills/grill-me.md.tmpl", "category": "skill" },
    { "target": ".beads/config.yaml", "source": "beads/config.yaml.tmpl", "category": "beads" },
    { "target": ".githooks/pre-commit", "source": "githooks/pre-commit", "category": "hook" }
  ]
}
```

## Fields

| Field | Purpose |
|---|---|
| `generatedBy` | Always `"agent-bootstrap"`. Identifies manifests from this tool. |
| `templateVersion` | Version of the bootstrap template that generated this manifest. The cursor `/sync-bootstrap` uses to reason about what's new upstream. |
| `generatedAt` | ISO-8601 UTC timestamp of the bootstrap run. |
| `techStack` | Detected or user-specified tech stack at bootstrap time (e.g., `"Go"`, `"Node/TypeScript"`). Informational. |
| `toolTarget` | One of `all`, `claude-code`, `codex`, `antigravity`. Determines which harness mirrors were generated. |
| `templateSource` | Path (relative to the agent-bootstrap repo) where templates live. Used by `/sync-bootstrap` to locate upstream content. |
| `variables` | Snapshot of every placeholder value substituted into templates. Allows future re-renders without re-prompting the user. |
| `files` | Authoritative log of generated files. Each entry: `target` (path relative to project root), `source` (template name relative to `templateSource`), `category` (`config` / `agent` / `skill` / `workflow` / `beads` / `hook`). |

## Accuracy Guarantee

`files` is built at runtime by `scripts/bootstrap.sh` from a tracker that records every successful template render. Conditional branches (`TOOL_TARGET` gates, "skip if file already exists" guards) only contribute entries for files that were actually written. The list is neither a menu of possible files nor a hardcoded snapshot — it is what bootstrap did, on this run, in this project.

## Usage

### During Bootstrap
The script generates the manifest at the end of the run after creating/modifying files. Projects should commit it to version control.

### For Cleanup
To remove agent-bootstrap-generated files from a project:

```bash
jq -r '.files[].target' .claude/.bootstrap-manifest.json | xargs rm -rf
rm .claude/.bootstrap-manifest.json
```

This removes only files bootstrap generated. User-owned runtime artifacts (`.claude/plans/`, `.claude/context/`, `.claude/architecture/`, `.beads/issues.jsonl`) are intentionally not in the manifest, so cleanup leaves them alone.

### For `/sync-bootstrap`
The skill reads `templateSource` to locate upstream templates and uses `files` as the local source of truth for what's already in place. Adds in the upstream that don't appear in `files` are surfaced as candidate imports.

## Notes

- The manifest is the source of truth. If a file is deleted locally but still listed, bootstrap will not silently re-create it — that respects user cleanup.
- Commit the manifest to git.
- Do not edit it by hand unless you understand the consequences.
- The manifest itself is not listed inside `files`; `rm .claude/.bootstrap-manifest.json` is a separate cleanup step.
