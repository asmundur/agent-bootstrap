# Scaffold State Specification

## Purpose

`.agent-scaffold.json` is the authoritative log of every scaffold-managed file the scaffold command automatically generated for a project. It serves three purposes:

1. **Audit**: a precise list of what the scaffold created, so you can see exactly what is scaffold-managed.
2. **Cleanup**: enables removal of agent-bootstrap from a project without leaving orphaned scaffold files.
3. **Re-application**: provides the canonical scaffold variables and file checksums so the scaffold can be re-applied without re-prompting a human and without overwriting drifted scaffold-managed files.
4. **Adoption safety**: temporarily records pre-existing active targets and their generated scaffold-candidate sidecars so later refreshes block until they are explicitly resolved.

## Location

`.agent-scaffold.json` at the project root. One scaffold state file covers all harness mirrors (`.claude/`, `.codex/`, `.antigravity/`).

## Format

```json
{
  "generatedBy": "agent-bootstrap",
  "templateVersion": "1.3.0",
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
  "adoptionConflicts": [
    {
      "target": "AGENTS.md",
      "scaffoldCandidate": "AGENTS.scaffold-candidate.md",
      "detectedAt": "2026-04-28T12:34:56Z",
      "targetChecksum": "...",
      "candidateChecksum": "...",
      "status": "unresolved"
    }
  ],
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
| `adoptionConflicts` | Temporary unresolved entries created when first-time adoption leaves a pre-existing target active and writes the desired scaffold content to a sibling `*.scaffold-candidate.*` sidecar. This key is omitted once conflicts are resolved. |
| `files` | Authoritative log of scaffold-managed files. Each entry: `target` (path relative to project root), `source` (template name relative to `templateSource`), `category` (`config` / `agent` / `skill` / `workflow` / `beads` / `hook`), and `checksum` (the last scaffold-rendered content hash used for drift detection). |

## Accuracy Guarantee

`files` is built at runtime by `scripts/scaffold.sh` from the complete render
plan. Conditional branches (`AGENT_HARNESS` gates) contribute only the files
that the selected harness will manage.

Before the first target-side write, the command renders the complete desired
state into a temporary workspace outside the target and preflights every
replacement, adoption candidate, obsolete removal, exact file mode, migration
gate, generated JSON file, and generated shell file. It compares existing
scaffold-managed files with their recorded checksums and fails loud on local
drift. Unsafe, absolute, parent-traversing, and symlink-parent state paths are
blockers. Known deterministic blockers therefore leave all target files and
`.agent-scaffold.json` unchanged.

Before it reads any variables or ownership data, the command copies the
existing state into that temporary workspace and verifies the copy, the
`generatedBy` owner, and the required field types and checksums. A foreign or
schema-invalid `.agent-scaffold.json` is a blocker, not an adoption target.
Tracked Beads inputs used to infer prefix or bootstrap behavior are captured
and rechecked under the same no-write boundary.

Immediately before applying a successful plan, the command rechecks every
observed target checksum and mode. It writes the new state file only after all
planned managed-file writes and removals complete. Git hook configuration and
Beads bootstrap run after that file/state boundary.

This is preflight atomicity, not a filesystem transaction: an I/O failure,
process termination, or machine failure during the apply phase has no rollback
journal and can still leave a partial application.

When a target already exists but is not scaffold-managed, the command keeps the
active file in place, plans a sibling `*.scaffold-candidate.*` file, and records
an `adoptionConflicts` entry. The candidate and new state are created only after
the whole run passes preflight. Any later scaffold run fails until every
conflict is reviewed and explicitly resolved.

## Usage

### During Scaffold Application

The command generates the state file from the complete plan and installs it
last, after creating or refreshing scaffold-managed files. Projects should
commit it to version control.

Use the read-only check mode to inspect whether the same plan can apply:

```bash
scripts/scaffold.sh --check [target] [all|claude-code|codex|antigravity]
```

Check mode performs no target directory creation, file replacement, candidate
creation, removal, Git configuration, or Beads bootstrap. It exits nonzero and
reports all discovered blockers, or prints `Scaffold check passed.`.

### For Cleanup

To remove scaffold-managed files from a project:

```bash
jq -r '.files[].target' .agent-scaffold.json
```

Review that inventory, verify every entry is a checkout-relative managed file
with the recorded checksum, and remove approved paths explicitly. Do not pipe
state-provided paths into recursive deletion. Remove `.agent-scaffold.json`
only after the managed-file cleanup is complete.

Project-local working artifacts (`.claude/plans/`, `.claude/context/`,
`.claude/architecture/`, `.beads/issues.jsonl`) are intentionally not in the
scaffold state, so cleanup leaves them alone.

### For `/bootstrap`

The skill reads and updates `variables`, then refreshes scaffold-managed files that depend on those values. If unresolved `adoptionConflicts` exist, `/bootstrap` should stop and direct the user to `/resolve-adopted-artifacts` first.

### For Forward Refresh

Re-run `scripts/scaffold.sh`. It is the only forward refresh path for scaffold-managed files.

Run `scripts/scaffold.sh --check` first when assessing an older consumer. A
managed combined pre-commit hook, the retired `.githooks/pre-commit.local`
extension, or a managed clone contract using the legacy `issues.jsonl`
spelling is an explicit migration blocker rather than an automatically
rewritten artifact.

If unresolved `adoptionConflicts` exist, re-running `scripts/scaffold.sh` fails loudly until:
- the active pre-existing targets and scaffold-candidate sidecars are reviewed
- any legacy content that must remain is archived under `docs/legacy-agent-artifacts/` using mirrored relative paths
- the approved candidate content is installed at each managed target
- `adoptionConflicts` is removed from `.agent-scaffold.json`

## Notes

- The scaffold state is the source of truth.
- Commit the scaffold state to git.
- Do not edit it by hand unless you understand the consequences.
- The scaffold state file itself is not listed inside `files`; `rm .agent-scaffold.json` is a separate cleanup step.
