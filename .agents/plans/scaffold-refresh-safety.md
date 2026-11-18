# Upstream Scaffold Safety Remediation

## Summary

Fix the nine findings recorded in `CODE_REVIEW.md` in `agent-bootstrap` only.
Canonical consumers and hidden workspace clones remain untouched. Older
consumers that require migration must be detected during preflight and blocked
before any checkout file, scaffold state, Git configuration, or Beads runtime
is changed.

Build on the existing working diff, preserve `CODE_REVIEW.md`, bump the scaffold
template to `1.3.0`, and regenerate all provider copies from universal
templates.

## Public Contracts

| Surface | Contract |
|---|---|
| `scripts/scaffold.sh --check [target] [harness]` | Render and validate the complete refresh without modifying the target, Git config, or Beads runtime. Exit nonzero with all blockers reported. |
| `.githooks/prepare-commit` | Scaffold-managed, manually invoked preparation command. Run project generation and Beads export before final review without staging files. |
| `.githooks/prepare-commit.local` | Optional project-owned generator/fixer. It may update the worktree but must not modify the index. |
| `.githooks/pre-commit.validate` | Optional project-owned read-only validator. Its failure aborts before Beads validation. |
| `.githooks/pre-commit.local` | Retired legacy interface. Its presence blocks refresh until explicitly classified and migrated. |
| `.beads/clone-contract.json` | Keep `jsonl_export: ".beads/issues.jsonl"` as a repository-root-relative reference to the tracked recovery snapshot. |
| Feature branches | Use validated `feature/<feature-slug>` names; never interpolate `PROJECT_NAME`. An explicitly declined branch switch continues implementation on the current branch. |

Do not introduce an approval-token system or a new completion-test metadata
field.

## Implementation

### Whole-run scaffold preflight

- Refactor the renderer into render, preflight, and apply phases.
- Render every desired file, mode, checksum, adoption candidate, obsolete
  removal, and proposed state into one temporary workspace.
- Perform no target-side directory creation, candidate creation, replacement,
  deletion, Git configuration, or Beads bootstrap during render or preflight.
- Collect all unresolved adoption conflicts, managed drift, candidate
  collisions, unsafe obsolete removals, invalid generated JSON or shell, hook
  extension errors, and migration blockers before failing.
- Recheck observed target checksums immediately before applying.
- Apply planned files and modes, remove verified obsolete targets, write
  `.agent-scaffold.json` last, then run Git hook configuration and Beads
  bootstrap.
- Document that deterministic preflight failures are zero-write, while
  filesystem failure during apply has no rollback journal.

Block with zero target writes when:

- a state-managed `.githooks/pre-commit` still matches its recorded checksum
  and contains the former preserved-command marker;
- `.githooks/pre-commit.local` remains;
- a managed-clean clone contract would change from `issues.jsonl` to
  `.beads/issues.jsonl`.

`/resolve-adopted-artifacts` must require explicit classification into
validation or preparation, remove embedded Beads/export duplication, install
the clean dispatcher, and rerun `--check`. It must not parse or relocate
arbitrary shell automatically.

State-less adoption continues to preserve active files and create scaffold
candidates, but only after the whole run passes preflight.

### Preparation and exact commit review

Use this sequence:

1. Compare the worktree with the original pre-edit baseline.
2. Present intended preparation and staging paths for approval.
3. Stage approved source paths individually.
4. Run `.githooks/prepare-commit`.
5. Inspect preparation output and stop if it expands beyond approved scope.
6. Stage each approved generated file, including `.beads/issues.jsonl`,
   individually.
7. Present the full cached diff, cached name/status list, current HEAD, and
   `git write-tree` fingerprint.
8. Obtain approval for that exact HEAD and tree.
9. Recheck both immediately before `git commit`.
10. Verify `HEAD^{tree}` equals the approved tree after commit.

The preparation command rejects alternate indexes, forwards arguments to
`prepare-commit.local`, rejects local index mutation, runs Beads preparation,
and exports the issue-only `.beads/issues.jsonl` snapshot with syntax supported
by the installed Beads version without staging it.

The automatic pre-commit path rejects alternate indexes, captures the entry
tree, runs `pre-commit.validate`, rejects validator index mutation, compares a
temporary Beads export with the staged `.beads/issues.jsonl`, and verifies that
the exit tree equals the entry tree. It never rewrites or stages the recovery
snapshot.

Any staged-tree or base-HEAD change invalidates approval and returns to final
review.

### Workflow and authorization guidance

- Capture branch, HEAD, staged/unstaged/untracked paths, and overlapping dirty
  patches before the first mutation, including task claim/create, feature-spec
  creation, or branch switching.
- Carry the original baseline and an in-session task-owned change ledger
  through `/grill-me`, `/feature-start`, `/tdd`, implementation, and Git-manager
  handoffs.
- Generate branch names from the feature-spec slug, validate them with
  `git check-ref-format --branch`, and request branch-switch approval. An
  explicit refusal continues on the current branch.
- Make Phase 5 accurately lead to the branch decision and then Stage 2.
- Define monitoring as persistence plus read-only observation. Retries,
  restarts, repository fixes, deployments, external writes, and messages need
  separately established authority.
- Restrict infrastructure TDD red/green loops to render, parse, lint, policy,
  plan, preflight, or guaranteed no-apply dry runs. Live deployment is release
  verification requiring explicit operation and environment authorization.
- Keep repository-specific affected-versus-full test policy in the preserved
  `AGENTS.md` safety section; do not add a scaffold field or permit managed
  workflow drift.

## Acceptance Tests

- Legacy combined hooks, legacy local hooks, non-executable explicit
  extensions, legacy clone-contract paths, late drift, candidate collisions,
  unsafe obsolete removals, and invalid generated artifacts all fail before
  target mutation.
- State-less adoption still creates candidates on successful apply.
- Explicitly resolved hooks refresh to the clean dispatcher while project-owned
  extensions remain byte-identical.
- Preparation runs local generation before Beads preparation/export and does
  not stage files; index-mutating preparation fails.
- Validator failure suppresses Beads validation; validator index mutation
  fails.
- Stale Beads export fails without modifying file or index; a prepared export
  passes.
- Alternate indexes and pathspec commits are rejected.
- The committed tree equals the reviewed fingerprint.
- Names containing spaces and punctuation render valid feature refs.
- Provider copies and standalone/combined guidance remain consistent.
- Generated targets are unique, modes are correct, and state checksums match.

Run:

- `bash -n` over managed hook and scaffold scripts;
- `jq empty` over generated JSON;
- `git diff --check`;
- `bash scripts/smoke-test-scaffold.sh`;
- self-refresh followed by a clean `scripts/scaffold.sh --check`.

Any compatibility inspection outside this repository is read-only. No consumer
repository receives edits, refreshes, tasks, commits, or synchronization.

## Boundaries

- Only `agent-bootstrap` is modified.
- Gloggur's tracked recovery file remains `.beads/issues.jsonl`.
- No automated shell extraction, rollback journal, approval token, or
  downstream migration is included.
- Existing working-tree changes are reconciled in place and `CODE_REVIEW.md`
  remains unchanged.
- Branch creation, staging, commit, and push require separate approval.
