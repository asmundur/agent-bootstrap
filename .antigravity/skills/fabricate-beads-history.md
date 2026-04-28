---
name: fabricate-beads-history
description: Retroactively creates high-quality beads tasks for every existing git commit from the beginning of the repository's history.
---

# Fabricate Beads History Skill

You are executing the `fabricate-beads-history` skill. Your objective is to backfill tasks in the beads (`bd`) task tracker for every existing git commit in the repository. This is typically run when a project with an existing commit history adopts the beads task tracking system.

## Your Goal

Walk through the git commit history from the oldest commit to the newest one. For each commit, analyze its changes to understand what work was done, and create a corresponding highest-quality beads task. The task MUST be backdated to match the timestamp of the git commit exactly, and flagged as a retroactive task (`retcon`).

Before starting, verify that the local Beads store is actually operational:

```bash
bd status --json
```

If that fails because Beads has not been bootstrapped yet, run the non-destructive setup path first:

```bash
bd bootstrap --yes --json
bd status --json
```

Do not assume that the presence of `.beads/` files means the local database is ready.

## Step 1: Retrieve the Commit History

Run the following command to get the full list of commits in chronological order (oldest first):

```bash
git log --reverse --format="%H|%cI|%s"
```

This will give you lines containing the commit hash, the strict ISO 8601 commit date, and the commit subject.

## Step 2: Process Each Commit Iteratively

For each commit in the list, perform the following steps sequentially:

### 2a: Analyze the Commit

Run `git show <commit_hash>` to see the full commit message and the diff.
Carefully analyze the changes. What problem was this commit solving? What feature was it adding? What bug was it fixing?

### 2b: Formulate the Task Description

Based on your analysis, construct a high-quality task title and description. You MUST put significant effort into the quality, depth, and accuracy of the task description. It should represent the original intent of the task as if it was thoughtfully written *before* the work was started, avoiding just lazily copying the commit message. The quality of this information is paramount.

### 2c: Create the Task

Create the task in beads:
```bash
bd create --title "<high_quality_task_title>" -p 2 --json
```
(If `bd create` requires a description, add it. If you need to add a description later, use the `bd` edit commands).
Capture the newly created task's ID from the JSON output.

### 2d: Backdate and Tag the Task (MANDATORY)

You MUST modify the task so its timestamps match the git commit timestamp exactly. This critically involves backdating BOTH the creation time AND the closing time. Also, tag the task as `retcon` to indicate it was retroactively generated.

Preferred path when `bd sql` is supported by the active backend:

```bash
bd sql "UPDATE issues SET created_at = '<commit_timestamp>', updated_at = '<commit_timestamp>' WHERE id = '<task_id>';"
```
```bash
bd sql "INSERT INTO issue_labels (issue_id, label) VALUES ('<task_id>', 'retcon');"
```

Since the commit represents the completion of the work, you MUST close the task immediately. Critically, after closing it, you MUST run a second SQL command to backdate the `closed_at` timestamp to match the commit timestamp exactly, because `bd close` will overwrite it with the current time:

```bash
bd close <task_id> --reason "done" --json
bd sql "UPDATE issues SET updated_at = '<commit_timestamp>', closed_at = '<commit_timestamp>' WHERE id = '<task_id>';"
```

Fallback when `bd sql` is unavailable for the active backend:

- export or construct JSONL entries that include the exact `created_at`, `updated_at`, `closed_at`, `close_reason`, and `labels`
- import those entries with `bd import <file> --json`
- prefer stable explicit IDs when bulk-importing retroactive tasks

In other words: exact timestamp fidelity is mandatory, but the mechanism may vary by backend. Do not assume embedded backends support `bd sql`.

## Step 3: Loop

Proceed to the next commit and repeat Step 2. Do this for EVERY commit up to the most recent one.

## Step 4: Finalize

Once all commits have been processed, summarize the total number of retroactive tasks created and present a brief report to the user.
