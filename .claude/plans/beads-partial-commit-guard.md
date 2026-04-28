# Beads Partial Commit Guard

## Problem

`git commit <pathspec>` uses a temporary commit index. The Beads pre-commit hook can export and stage `.beads/issues.jsonl`, but Git still excludes that file from the pathspec-limited commit and leaves it staged afterward. That creates the exact leak this repository is trying to prevent.

Separately, `scripts/scaffold.sh` currently attempts `bd bootstrap` even when the target directory is not yet a git worktree. That can leave behind half-initialized local Beads state and make later hook behavior unreliable in fresh scaffolded repos.

## Scope

- Detect partial/pathspec commits in the Beads pre-commit hook.
- Fail loudly when `.beads/issues.jsonl` changes during a partial commit, instead of letting the snapshot leak past the commit.
- Only auto-bootstrap Beads from `scripts/scaffold.sh` when the target is already a git worktree.
- Add regression coverage in the scaffold smoke test.

## Non-goals

- Auto-amending commits after they are created.
- Supporting pathspec commits that also silently include `.beads/issues.jsonl`.

## Acceptance Criteria

- A normal `git commit` that triggers a Beads export still includes `.beads/issues.jsonl` in that same commit.
- A pathspec commit that would leave `.beads/issues.jsonl` behind fails with a clear message telling the user how to proceed.
- Running `scripts/scaffold.sh` outside a git worktree does not attempt a local `bd bootstrap`.
- `scripts/smoke-test-scaffold.sh` covers the guarded partial-commit behavior.
