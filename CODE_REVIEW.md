# Code Review Findings

Review date: 2026-07-29

Reviewed change set: the 22-file uncommitted diff on `main` against `origin/main` (`499` insertions, `110` deletions). This review covered the renderer, smoke tests, hook dispatcher, clone contract, scaffold state, all rendered provider files, their universal template sources, and every repository under `../` that has evidence of scaffold adoption. `../bergmal` was excluded as requested.

Severity:

- **P1** — blocks safe rollout because it removes a guard, breaks a consumer contract, or can authorize an out-of-scope mutation.
- **P2** — material workflow or compatibility defect that should be resolved before rollout.
- **P3** — lower-impact but concrete contract/UX inconsistency.

## Findings

### P1 — Forward refresh silently removes existing repository safety hooks

**Locations:** `scripts/scaffold.sh:925-966,1034-1041`; `bootstrap-templates/templates/universal/skills/resolve-adopted-artifacts.md.tmpl:263`; `scripts/smoke-test-scaffold.sh:299-408`

The deleted `merge_pre_commit_local_commands` path handled more than first-time adoption: previous scaffold versions produced a managed `.githooks/pre-commit` containing both the scaffold dispatcher and preserved repository-specific commands. Those combined hooks are recorded in adopters' `.agent-scaffold.json` files as clean scaffold-managed content.

The new `copy_hook` passes the clean dispatcher directly to `write_from_tmp`. When the live combined hook still matches its recorded checksum, `write_from_tmp` considers it safe to replace and overwrites it without creating an adoption conflict or migrating its extra statements into `.githooks/pre-commit.local`. The new resolver prose cannot help: it is only reached for an `adoptionConflict`, while the affected adopters have zero conflicts.

Concrete downstream effects:

- `../innvardr/.githooks/pre-commit:13-14` invokes `.githooks/check-production-vault.sh`. That guard rejects missing or plaintext production vaults at `../innvardr/.githooks/check-production-vault.sh:54-73` and verifies staged deployment-contract changes at lines `75-94`. Innvardr has 39/39 managed hashes clean and no local hook. A temporary refresh with this renderer succeeded, changed the managed hook checksum from `6ac05f…` to `401293…`, and removed the vault invocation without creating `pre-commit.local`.
- `../gloggur-headquarters/.githooks/pre-commit:13-15` invokes `scripts/secrets-validate` and `scripts/lint --fix`; `../gloggur-headquarters/tests/test_git_beads_scripts.py:1024-1088` explicitly requires both calls. Its combined hook is also recorded as managed-clean and it has no local hook. Canonical GHQ currently aborts earlier because 12 generated files have committed manifest drift, so its literal next invocation does not yet reach the hook. Once that drift is reconciled, the same overwrite removes both checks.
- The hidden Innvardr and GHQ scaffold snapshots under `../.gloggur-workspace/repos/github/asmundur/` have the same combined-hook layout and the same eventual loss when their hidden scaffold source is updated.

The new smoke coverage proves only that a state-less first adoption keeps the active legacy hook and emits a clean candidate. It does not cover the upgrade path from the prior scaffold-managed combined-hook format, which is the path that loses data.

**Required resolution:** add an explicit managed-state migration for the former combined hook format. It should either extract the preserved block into an executable `pre-commit.local` before replacing the dispatcher or stop with a fail-loud migration conflict. Add a refresh regression fixture whose manifest checksum identifies a prior combined managed hook.

### P1 — Gloggur’s enforced clone contract rejects the refreshed path

**Locations:** `.beads/clone-contract.json:5`; `scripts/scaffold.sh:1054-1065`; `../gloggur/scripts/check_beads_clone_contract.py:10-15,130-140`

The reviewed generated contract changes `jsonl_export` from `issues.jsonl` to `.beads/issues.jsonl`, and the current renderer emits the root-qualified value. Gloggur’s managed-clean contract still uses `issues.jsonl`, and its repository-owned checker requires that exact value.

The actual Gloggur checker passes against its current checkout. After applying this renderer to a temporary copy, the same checker exits `1` with:

```text
beads_clone_contract_violation
jsonl_export: expected 'issues.jsonl', found '.beads/issues.jsonl'
```

The other four canonical consumers already store or enforce the root-qualified path, so this is specific to Gloggur and its hidden workspace snapshot.

Attribution detail: the renderer’s hard-coded path was introduced in existing commit `3eb8a1a`; the uncommitted diff refreshes this repository’s own generated contract and manifest to that value. It is nevertheless a current-renderer incompatibility exposed by this change set and must be coordinated before downstream refresh.

**Required resolution:** migrate the Gloggur validator and its expected contract in the same rollout, or temporarily accept both representations with one documented path-resolution rule.

### P1 — Monitoring guidance can turn a read-only watch request into repository fixes

**Locations:** `bootstrap-templates/templates/universal/anti-patterns.md.tmpl:48`; `bootstrap-templates/templates/universal/AGENTS.md.tmpl:175,186`

The new monitoring rule imperatively tells an agent to “Handle blockers and repo-side fixes,” and AGENTS says fixes should support the monitoring objective. A request to monitor, babysit, or follow a deployment establishes persistence, but does not itself authorize code, configuration, infrastructure, or external-state changes.

This directly conflicts with the same generated AGENTS contract at line `186` (“Never implement beyond what was agreed”). Different harnesses can therefore interpret the same monitor-only request either as read-only observation or as permission to patch the repository. The ambiguity is especially consequential in Innvardr and GHQ, which manage deployment and production surfaces.

**Required resolution:** state that fixes are performed only when the user separately authorized mutation; otherwise investigate read-only, report the named blocker, and continue or stop according to the monitoring request.

### P2 — Local-before-Beads ordering changes failure atomicity for Gloggur’s mutating hook

**Locations:** `bootstrap-templates/templates/universal/githooks/pre-commit:6-11`; `../gloggur/.githooks/pre-commit.local:7-31`; `bootstrap-templates/templates/universal/githooks/beads-pre-commit.sh:28-49`

The dispatcher now runs arbitrary repository-local behavior before the Beads hook. That is appropriate for fail-fast validators, but the local-hook contract does not require hooks to be non-mutating.

Gloggur’s existing executable local hook is mutating: when relevant staged files change, it regenerates `docs/semantic-search-embedding-breakdown-base.md` and runs `git add` on it. With the old order, a Beads hook/export/partial-index failure prevented that mutation. With the new order, the document is generated and staged first; a later Beads failure aborts the commit after the local side effect has already happened.

This is a concrete behavior change in an otherwise clean, refreshable consumer. The added smoke test covers local-hook failure suppressing Beads, but does not cover Beads failing after a successful mutating local hook.

**Required resolution:** define `.githooks/pre-commit.local` as a non-mutating preflight contract, or provide distinct pre-Beads validation and post-Beads mutation extension points. Cover the Beads-fails-after-local path.

### P2 — The dirty-worktree “baseline” is captured after implementation in the normal workflow

**Locations:** `bootstrap-templates/templates/universal/AGENTS.md.tmpl:131,182`; `bootstrap-templates/templates/universal/anti-patterns.md.tmpl:16`; `bootstrap-templates/templates/universal/agents/git-manager.md.tmpl:7-12`; `bootstrap-templates/templates/universal/agents/feature-implementation.md.tmpl:5-20`

The new general rule captures a “baseline” immediately before staging, and the Git-Manager first sees the worktree after implementation. By then, pre-existing changes and task changes are already mixed, so that snapshot cannot establish which files were dirty before the task.

The `/tdd` skill gets this right at `skills/tdd.md.tmpl:52` by capturing status before editing, but the default Feature-Implementation agent and general feature workflow have no equivalent pre-edit step. This is not theoretical in the current adopters: `ui-glitch-hunter`, `gloggur-headquarters`, and `sandkassinn` all currently have unrelated dirty tracked files.

**Required resolution:** capture and carry the dirty-worktree baseline before planning or implementation edits in every implementation entry path, then have Git-Manager compare against that original snapshot.

### P2 — Raw project names render invalid branch commands in two consumers

**Locations:** `bootstrap-templates/templates/universal/skills/feature-start.md.tmpl:87,94`

`{{PROJECT_NAME}}` is interpolated directly into a Git ref and an unquoted shell command. This renders as:

```text
feature/UI Glitch Hunter-<short-description>
feature/Agent Sandbox-<short-description>
```

in UI Glitch Hunter and Sandkassinn respectively, across all three provider skill copies. `git check-ref-format` rejects both names because Git refs cannot contain spaces; the shell command also splits the name into multiple arguments. Quoting alone would not fix the invalid ref.

The checkout command predates this working diff, but the newly added branch proposal repeats and presents the invalid value, so the refreshed workflow remains unusable for two of five canonical consumers.

**Required resolution:** render a validated branch-safe slug separate from the human project name, and test names containing whitespace and punctuation.

### P2 — Exact staged-set approval is invalidated inside `git commit`

**Locations:** `bootstrap-templates/templates/universal/agents/git-manager.md.tmpl:10-12,44-51`; `bootstrap-templates/templates/universal/AGENTS.md.tmpl:125,131`; `bootstrap-templates/templates/universal/githooks/beads-pre-commit.sh:37-49`

The new Git-Manager contract requires an exact staging plan, verifies it with `git diff --cached --name-status`, and says to stop if the staged scope broadens. The scaffold’s pre-commit hook then exports and auto-stages tracked `.beads/` files during `git commit`, after that final review.

All five canonical consumers track `.beads/issues.jsonl`. When live Beads state differs from the tracked export, the actual commit contains a file/version that was absent from the last cached-diff review. This makes the new exact-set guarantee impossible to satisfy through the documented workflow.

**Required resolution:** refresh and stage Beads state before the user’s final staged-diff approval, or redesign the hook so it validates a pre-refreshed snapshot instead of changing the index after approval.

### P2 — Infrastructure TDD treats live deployment as a test without a separate mutation gate

**Locations:** `bootstrap-templates/templates/universal/skills/tdd.md.tmpl:18-22,38-41,52`

The new section correctly says the red phase must reject unsafe state before mutation, but immediately lists a “failed deployment” as a useful red check and defines successful deployment as green. A real deployment can partially mutate hosts, cloud resources, DNS, databases, or secrets before it fails. The skill’s authorization sentence at line `52` says `/tdd` approval permits code/test edits and feedback loops; it does not establish permission for an external deployment.

This creates an actionable ambiguity for infrastructure consumers, especially Innvardr, whose hydrated metadata describes production VPS/IaC work and whose configured run command is `bash scripts/sync_vps.sh`.

**Required resolution:** distinguish non-mutating render/plan/preflight/dry-run checks from a live apply. Require separate, explicit deployment authorization before using an apply/deploy command as a green step.

### P3 — Phase 5 promises Stage 2, but Phase 6 inserts another mandatory gate with no declined-branch path

**Locations:** `bootstrap-templates/templates/universal/skills/feature-start.md.tmpl:68-97`; `bootstrap-templates/templates/universal/workflows/feature-workflow.md.tmpl:24-41`

Phase 5 asks the user to approve “continue to Stage 2.” The next action is instead a second mandatory stop for branch-switch approval, and the implementation handoff appears only after the branch command. The shared workflow still documents one Stage 1 approval leading to the Stage 2 handoff.

If implementation is approved but the separately scoped branch operation is declined, the skill does not say whether to proceed on the current branch or end the workflow. That is a concrete dead end introduced by separating the permissions without updating the workflow contract and prompt.

**Required resolution:** make the Phase 5 prompt accurately describe the next gate and define the branch-declined outcome; update the shared workflow to match.

## Consumer Compatibility Matrix

| Repository | Adoption evidence | Current managed state | Result with current renderer |
|---|---|---:|---|
| `../ui-glitch-hunter` | Tracked `.agent-scaffold.json`, generated provider skills/hooks, adoption history | 39/39 hashes clean; zero conflicts | Temporary refresh succeeds. Branch proposal/command is invalid because the project name contains spaces. |
| `../gloggur-headquarters` | Tracked state, generated artifacts, executable wrapper to sibling renderer | 12 committed manifest drifts; zero conflicts | Current invocation aborts at `.agents/anti-patterns.md` before hooks. After that drift is reconciled, its managed secrets/lint hook is removed unless explicitly migrated. |
| `../gloggur` | Tracked state, generated artifacts, sibling renderer command | 39/39 hashes clean; zero conflicts | Refresh succeeds, then its clone-contract checker fails. Existing mutating local hook moves before Beads. |
| `../sandkassinn` | Tracked state, generated artifacts, sibling renderer command | 39/39 hashes clean; zero conflicts | Temporary refresh succeeds. Branch proposal/command is invalid because the hydrated project name is `Agent Sandbox`. |
| `../innvardr` | Tracked state and generated artifacts | 39/39 hashes clean; zero conflicts | Temporary refresh succeeds but removes the production-vault hook. Its state advertises `scripts/scaffold.sh`, which does not exist; that is pre-existing and not introduced by this diff. |

All five canonical consumers have aligned state/config/contract Beads prefixes and `core.hooksPath=.githooks`.

Additional recursive inventory:

- `../.gloggur-workspace/repos/github/asmundur/{gloggur,gloggur-headquarters,innvardr,sandkassinn}` are scaffolded clone snapshots. They are driven by the hidden sibling `agent-bootstrap` clone rather than this working checkout, so the uncommitted patch does not reach them until that source clone updates. Hidden Innvardr and Gloggur reproduce the same hook and clone-contract risks. Hidden GHQ has committed `_common.sh` drift: the renderer updates earlier targets and then aborts there, leaving a partial refresh with the state file unadvanced.
- `../.gloggur-workspace/repos/github/asmundur/agent-bootstrap` is another scaffold source checkout, not a downstream consumer.
- `../b/gloggur-benchmarking` is not an agent-bootstrap consumer. It has no `.agent-scaffold.json`, generated provider skills, scaffold command, or history for those paths; its `AGENTS.md` and clone contract are older repository-owned Beads artifacts. Its nested subject repositories are benchmark fixtures.
- Top-level `deskdrawer`, `luggage`, and `tengill`, the remaining hidden workspace repositories, and the GHQ workspace snapshots have no scaffold state/history and are not consumers.

## Verification Performed

- `git diff --check` — passed.
- `bash -n scripts/scaffold.sh`, `bash -n scripts/smoke-test-scaffold.sh`, and `bash -n .githooks/pre-commit` — passed.
- `jq empty .agent-scaffold.json .beads/clone-contract.json` — passed.
- `bash scripts/smoke-test-scaffold.sh` — passed.
- Updated scaffold state — all 39 targets are unique and every recorded SHA-256 matches its current generated file.
- Provider parity — changed Claude, Codex, and Antigravity copies are byte-identical for `feature-start`, `grill-me`, `resolve-adopted-artifacts`, and `tdd`.
- Consumer refresh probes — performed only in temporary copies; no consumer checkout was modified.
- Gloggur contract checker — passes before refresh and fails after refresh solely on the reviewed path value when `bd` parity is deliberately skipped.
- Branch validation — `git check-ref-format` rejects the rendered UI Glitch Hunter and Agent Sandbox refs and accepts the rendered `gloggur-headquarters` control.

## Changed Areas With No Additional Finding

- `.agent-scaffold.json` is valid, has no duplicate targets or unresolved conflicts, and its checksum updates correspond to the rendered changes. The large line count is JSON reformatting plus checksum refresh, not duplicated state.
- The generated `.githooks/pre-commit` and universal hook template are byte-identical and executable.
- The new dispatcher correctly forwards arguments, propagates a local-hook nonzero status, and suppresses Beads when the local hook fails.
- First-time state-less adoption correctly keeps the active legacy hook unchanged and writes a clean scaffold candidate.
- The `grill-me` hypothesis guidance is consistent across AGENTS, anti-patterns, and all providers and introduces no downstream file-format conflict.
- The infrastructure guardrail language is consistent across providers; the finding above is specifically about live-deployment authorization, not provider drift.
- No malformed JSON, whitespace errors, provider-copy divergence, shell syntax error, checksum mismatch, duplicate state target, cleanup leak, or additional immediate consumer overwrite was found.
