#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

require_file() {
  local path="$1"
  [[ -f "${path}" ]] || {
    echo "missing required file: ${path}" >&2
    exit 1
  }
}

require_text() {
  local pattern="$1"
  local path="$2"
  rg -F --quiet -- "${pattern}" "${path}" || {
    echo "missing expected text in ${path}: ${pattern}" >&2
    exit 1
  }
}

forbid_text() {
  local pattern="$1"
  local path="$2"
  require_file "${path}"
  if rg -F --quiet -- "${pattern}" "${path}"; then
    echo "unexpected text in ${path}: ${pattern}" >&2
    exit 1
  fi
}

template_files=(
  "bootstrap-templates/templates/universal/AGENTS.md.tmpl"
  "bootstrap-templates/templates/universal/CLAUDE.md.tmpl"
  "bootstrap-templates/templates/universal/agents/feature-implementation.md.tmpl"
  "bootstrap-templates/templates/universal/skills/bootstrap.md.tmpl"
  "bootstrap-templates/templates/universal/skills/grill-me.md.tmpl"
  "bootstrap-templates/templates/universal/skills/ubiquitous-language.md.tmpl"
  "bootstrap-templates/templates/universal/skills/improve-architecture.md.tmpl"
  "bootstrap-templates/templates/universal/skills/tdd.md.tmpl"
  "bootstrap-templates/templates/universal/skills/feature-start.md.tmpl"
  "bootstrap-templates/templates/universal/skills/retro.md.tmpl"
  "bootstrap-templates/templates/universal/skills/resolve-adopted-artifacts.md.tmpl"
  "bootstrap-templates/templates/universal/skills/audit-beads-quality.md.tmpl"
  "bootstrap-templates/templates/universal/workflows/feature-workflow.md.tmpl"
)

local_files=(
  "AGENTS.md"
  ".agent-scaffold.json"
  ".agents/anti-patterns.md"
  ".agents/workflows/feature-workflow.md"
  ".claude/CLAUDE.md"
  ".claude/agents/feature-implementation.md"
  ".claude/agents/git-manager.md"
  ".claude/skills/bootstrap.md"
  ".claude/skills/grill-me.md"
  ".claude/skills/ubiquitous-language.md"
  ".claude/skills/improve-architecture.md"
  ".claude/skills/tdd.md"
  ".claude/skills/feature-start.md"
  ".claude/skills/retro.md"
  ".claude/skills/resolve-adopted-artifacts.md"
  ".claude/skills/audit-beads-quality.md"
  ".codex/skills/bootstrap.md"
  ".codex/skills/grill-me.md"
  ".codex/skills/ubiquitous-language.md"
  ".codex/skills/improve-architecture.md"
  ".codex/skills/tdd.md"
  ".codex/skills/feature-start.md"
  ".codex/skills/retro.md"
  ".codex/skills/resolve-adopted-artifacts.md"
  ".codex/skills/audit-beads-quality.md"
  ".antigravity/skills/bootstrap.md"
  ".antigravity/skills/grill-me.md"
  ".antigravity/skills/ubiquitous-language.md"
  ".antigravity/skills/improve-architecture.md"
  ".antigravity/skills/tdd.md"
  ".antigravity/skills/feature-start.md"
  ".antigravity/skills/retro.md"
  ".antigravity/skills/resolve-adopted-artifacts.md"
  ".antigravity/skills/audit-beads-quality.md"
)

for path in "${template_files[@]}"; do
  require_file "${path}"
done

for path in "${local_files[@]}"; do
  require_file "${path}"
done

require_text "/bootstrap" ".claude/CLAUDE.md"
require_text "\"generatedBy\": \"agent-bootstrap\"" ".agent-scaffold.json"
require_text "\"agentHarness\":" ".agent-scaffold.json"
require_text "\"templateSource\":" ".agent-scaffold.json"
require_text "\"checksum\":" ".agent-scaffold.json"
require_text "\"TYPECHECK_COMMAND\": \"not configured\"" ".agent-scaffold.json"
require_text "\"SCAFFOLD_COMMAND\": \"scripts/scaffold.sh\"" ".agent-scaffold.json"
require_text "\"target\": \".claude/skills/bootstrap.md\"" ".agent-scaffold.json"
require_text "\"target\": \".claude/skills/resolve-adopted-artifacts.md\"" ".agent-scaffold.json"
require_text "\"target\": \".codex/skills/feature-start.md\"" ".agent-scaffold.json"
require_text "\"target\": \".antigravity/skills/feature-start.md\"" ".agent-scaffold.json"
require_text "filling in the project-specific values" "bootstrap-templates/templates/universal/skills/bootstrap.md.tmpl"
require_text "resolve all unresolved scaffold adoption conflicts in one pass" "bootstrap-templates/templates/universal/skills/resolve-adopted-artifacts.md.tmpl"
require_text "extract what the upstream scaffold should learn" "bootstrap-templates/templates/universal/skills/resolve-adopted-artifacts.md.tmpl"
require_text "\`scripts/scaffold.sh\` for generation behavior" "bootstrap-templates/templates/universal/skills/resolve-adopted-artifacts.md.tmpl"
require_text "break or change existing behavior" "bootstrap-templates/templates/universal/skills/resolve-adopted-artifacts.md.tmpl"
require_text "line-item policy inventory" "bootstrap-templates/templates/universal/skills/resolve-adopted-artifacts.md.tmpl"
require_text "Scaffold variable or extension point" "bootstrap-templates/templates/universal/skills/resolve-adopted-artifacts.md.tmpl"
require_text "grill-me style adoption interview" "bootstrap-templates/templates/universal/skills/resolve-adopted-artifacts.md.tmpl"
require_text "Do not present a wide matrix covering every conflict" "bootstrap-templates/templates/universal/skills/resolve-adopted-artifacts.md.tmpl"
require_text "Do not lead with \"should I archive/install these files?\"" "bootstrap-templates/templates/universal/skills/resolve-adopted-artifacts.md.tmpl"
require_text "Would installing the scaffold candidate as-is break or weaken behavior" "bootstrap-templates/templates/universal/skills/resolve-adopted-artifacts.md.tmpl"
require_text "apply upstream source changes first" "bootstrap-templates/templates/universal/skills/resolve-adopted-artifacts.md.tmpl"
require_text "Do not compress a policy artifact into an umbrella phrase" "bootstrap-templates/templates/universal/skills/resolve-adopted-artifacts.md.tmpl"
require_text "For every bundled policy loss, split the bundle into concrete rule rows before the interview" "bootstrap-templates/templates/universal/skills/resolve-adopted-artifacts.md.tmpl"
require_text "the interview must be a continuation of the extraction, not a summary endpoint" "bootstrap-templates/templates/universal/skills/resolve-adopted-artifacts.md.tmpl"
require_text "Err on the side of a more complete questionnaire when multiple independent decisions are hiding under one artifact" "bootstrap-templates/templates/universal/skills/resolve-adopted-artifacts.md.tmpl"
require_text "no session-close git actions, no tracker push, generated instruction ownership, hook path ownership, stale Beads runtime recovery, and tracker-only work ledgers" "bootstrap-templates/templates/universal/skills/resolve-adopted-artifacts.md.tmpl"
require_text "Question: Should I preserve these locally?" "bootstrap-templates/templates/universal/skills/resolve-adopted-artifacts.md.tmpl"
require_text "Project-Specific Safety Constraints" "bootstrap-templates/templates/universal/AGENTS.md.tmpl"
require_text "Agents must not run \`git add\`, \`git commit\`, or \`git push\` as an automatic session-close workflow." "bootstrap-templates/templates/universal/AGENTS.md.tmpl"
require_text "If local Beads runtime state is stale" "bootstrap-templates/templates/universal/AGENTS.md.tmpl"
require_text "Do not create markdown TODO trackers or side ledgers for net-new work." "bootstrap-templates/templates/universal/AGENTS.md.tmpl"
require_text "A high-quality Beads task has a concrete title, scope-bearing description, design notes, observable acceptance criteria, evidence notes, estimate, and dependencies where relevant." "bootstrap-templates/templates/universal/AGENTS.md.tmpl"
require_text "classify each issue as keep, improve, create, delete-noise, or needs-user-decision" "bootstrap-templates/templates/universal/skills/audit-beads-quality.md.tmpl"
require_text "bd delete --dry-run" "bootstrap-templates/templates/universal/skills/audit-beads-quality.md.tmpl"
require_text "Do not adopt or preserve mandatory automatic git commit, git push, bd sync, or bd dolt push workflows." "bootstrap-templates/templates/universal/skills/audit-beads-quality.md.tmpl"
require_text "routine scaffold refreshes do not require \`/bootstrap\`" "bootstrap-templates/templates/universal/AGENTS.md.tmpl"
require_text "stale_runtime_recovery" "bootstrap-templates/templates/universal/beads/clone-contract.json.tmpl"
require_text "Stage 0 — Shared Design Alignment" "bootstrap-templates/templates/universal/workflows/feature-workflow.md.tmpl"
require_text 'Create or update `.agents/context/ubiquitous-language.md`' "bootstrap-templates/templates/universal/skills/ubiquitous-language.md.tmpl"
require_text "pre-commit.local" "bootstrap-templates/templates/universal/githooks/pre-commit"
require_text "git ls-files -- .beads/" "bootstrap-templates/templates/universal/githooks/beads-pre-commit.sh"
require_text "embeddeddolt/" "bootstrap-templates/templates/universal/beads/gitignore"
forbid_text "/sync-bootstrap" ".claude/CLAUDE.md"

run_scaffold() {
  local tmp="$1"
  local agent_harness="$2"
  mkdir -p "${tmp}"
  bash "${repo_root}/scripts/scaffold.sh" "${tmp}" "${agent_harness}" >/dev/null
}

assert_bootstrap_prompt_cadence() {
  local tmp="$1"
  mkdir -p "${tmp}"

  bash "${repo_root}/scripts/scaffold.sh" "${tmp}" "all" >/tmp/scaffold-cadence-first.out
  require_text "Next step: run /bootstrap in your agent harness to hydrate project-specific values from the codebase." /tmp/scaffold-cadence-first.out

  bash "${repo_root}/scripts/scaffold.sh" "${tmp}" "all" >/tmp/scaffold-cadence-refresh.out
  require_text "Scaffold refresh complete." /tmp/scaffold-cadence-refresh.out
  require_text "Run /bootstrap only if project-specific scaffold values need to be re-hydrated from the codebase." /tmp/scaffold-cadence-refresh.out
  forbid_text "Next step: run /bootstrap in your agent harness" /tmp/scaffold-cadence-refresh.out

  rm -f /tmp/scaffold-cadence-first.out /tmp/scaffold-cadence-refresh.out
}

assert_beads_readiness_message_matches_status() {
  if ! command -v bd >/dev/null 2>&1; then
    echo "bd not found; skipping Beads readiness message smoke test"
    return 0
  fi

  local tmp="$1"
  local out="/tmp/scaffold-beads-readiness.out"

  git -C "${tmp}" init -q
  bash "${repo_root}/scripts/scaffold.sh" "${tmp}" "all" > "${out}"

  if (cd "${tmp}" && bd status --json >/dev/null 2>&1); then
    require_text "Beads bootstrap verified." "${out}"
  else
    require_text "Warning: scaffold files were written, but 'bd bootstrap --yes --json' did not complete successfully." "${out}"
    require_text "Verify Beads readiness with: bd status --json" "${out}"
    forbid_text "Beads bootstrap verified." "${out}"
  fi

  rm -f "${out}"
}

assert_drift_fails_loud() {
  local tmp="$1"
  printf '\n# local edit\n' >> "${tmp}/AGENTS.md"
  if bash "${repo_root}/scripts/scaffold.sh" "${tmp}" "all" >/tmp/scaffold-drift.out 2>/tmp/scaffold-drift.err; then
    echo "scaffold should have failed on local drift" >&2
    exit 1
  fi
  require_text "Refusing to overwrite drifted scaffold-managed files." /tmp/scaffold-drift.err
  rm -f /tmp/scaffold-drift.out /tmp/scaffold-drift.err
}

assert_adoption_conflict_is_preserved() {
  local tmp="$1"
  local state="${tmp}/.agent-scaffold.json"

  mkdir -p "${tmp}/.claude"
  cat <<'EOF' > "${tmp}/AGENTS.md"
# Legacy AGENTS
Keep this around.
EOF

  bash "${repo_root}/scripts/scaffold.sh" "${tmp}" "all" >/tmp/scaffold-adoption.out

  require_text "# Legacy AGENTS" "${tmp}/AGENTS.md"
  require_file "${tmp}/AGENTS.scaffold-candidate.md"
  require_text "# " "${tmp}/AGENTS.scaffold-candidate.md"
  jq -e '.adoptionConflicts | length == 1' "${state}" >/dev/null
  require_text "\"target\": \"AGENTS.md\"" "${state}"
  require_text "\"scaffoldCandidate\": \"AGENTS.scaffold-candidate.md\"" "${state}"
  require_text "\"targetChecksum\":" "${state}"
  require_text "\"candidateChecksum\":" "${state}"
  require_text "\"status\": \"unresolved\"" "${state}"
  require_text "AGENTS.md remains active; scaffold candidate: AGENTS.scaffold-candidate.md" /tmp/scaffold-adoption.out
  require_text "Next step: run /resolve-adopted-artifacts before /bootstrap or another scaffold refresh." /tmp/scaffold-adoption.out
  forbid_text "Next step: run /bootstrap in your agent harness" /tmp/scaffold-adoption.out

  rm -f /tmp/scaffold-adoption.out
}

assert_adoption_conflict_blocks_rerun() {
  local tmp="$1"

  if bash "${repo_root}/scripts/scaffold.sh" "${tmp}" "all" >/tmp/scaffold-adoption-rerun.out 2>/tmp/scaffold-adoption-rerun.err; then
    echo "scaffold should have failed with unresolved adoption conflicts" >&2
    exit 1
  fi

  require_text "unresolved adoption conflict" /tmp/scaffold-adoption-rerun.err
  require_text "/resolve-adopted-artifacts" /tmp/scaffold-adoption-rerun.err
  rm -f /tmp/scaffold-adoption-rerun.out /tmp/scaffold-adoption-rerun.err
}

assert_adoption_conflict_drift_fails_loud() {
  local tmp="$1"

  printf '\nchanged after capture\n' >> "${tmp}/AGENTS.md"
  if bash "${repo_root}/scripts/scaffold.sh" "${tmp}" "all" >/tmp/scaffold-adoption-drift.out 2>/tmp/scaffold-adoption-drift.err; then
    echo "scaffold should have failed when active conflict targets drifted" >&2
    exit 1
  fi

  require_text "active adoption-conflict target changed since capture" /tmp/scaffold-adoption-drift.err
  rm -f /tmp/scaffold-adoption-drift.out /tmp/scaffold-adoption-drift.err
}

assert_adoption_conflict_resolution_unblocks_rerun() {
  local tmp="$1"
  local state="${tmp}/.agent-scaffold.json"

  mkdir -p "${tmp}/docs/legacy-agent-artifacts"
  mv "${tmp}/AGENTS.md" "${tmp}/docs/legacy-agent-artifacts/AGENTS.md"
  mv "${tmp}/AGENTS.scaffold-candidate.md" "${tmp}/AGENTS.md"
  jq 'del(.adoptionConflicts)' "${state}" > "${state}.next"
  mv "${state}.next" "${state}"

  bash "${repo_root}/scripts/scaffold.sh" "${tmp}" "all" >/tmp/scaffold-adoption-resolved.out
  [[ ! -e "${tmp}/AGENTS.scaffold-candidate.md" ]] || {
    echo "resolved scaffold run should not recreate AGENTS.scaffold-candidate.md" >&2
    exit 1
  }
  require_file "${tmp}/docs/legacy-agent-artifacts/AGENTS.md"
  jq -e 'has("adoptionConflicts") | not' "${tmp}/.agent-scaffold.json" >/dev/null
  rm -f /tmp/scaffold-adoption-resolved.out
}

assert_existing_beads_contract_is_inferred() {
  local tmp="$1"
  local state="${tmp}/.agent-scaffold.json"

  mkdir -p "${tmp}/.beads" "${tmp}/.githooks" "${tmp}/scripts" "${tmp}/bin"
  cat <<'EOF' > "${tmp}/.beads/config.yaml"
issue-prefix: ghq
EOF
  cat <<'EOF' > "${tmp}/.beads/clone-contract.json"
{
  "mode": "bootstrap_required",
  "backend": "dolt",
  "issue_prefix": "ghq",
  "jsonl_export": ".beads/issues.jsonl",
  "bootstrap_commands": [
    "bd init -p ghq --skip-agents --skip-hooks --json",
    "bd import .beads/issues.jsonl --json",
    "git config core.hooksPath .githooks"
  ],
  "read_probe": "bd status --json"
}
EOF
  cat <<'EOF' > "${tmp}/.githooks/beads-pre-commit.sh"
#!/usr/bin/env bash
set -euo pipefail
echo old beads hook
EOF
  chmod +x "${tmp}/.githooks/beads-pre-commit.sh"
  cat <<'EOF' > "${tmp}/.githooks/pre-commit"
#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

"$(cd "$(dirname "$0")" && pwd)/beads-pre-commit.sh" "$@"
"${repo_root}/scripts/secrets-validate" --mode pre-commit --repo-root "${repo_root}"
"${repo_root}/scripts/lint" --fix
if ! command -v bd >/dev/null 2>&1; then
  echo "Warning: bd command not found in PATH, skipping Beads pre-commit hook" >&2
  exit 0
fi
echo "Refreshing Beads tracker exports..."
bd export -o .beads/issues.jsonl >/dev/null
export BD_GIT_HOOK=1
BD_HOOK_EXIT=0
bd hooks run pre-commit "$@" || BD_HOOK_EXIT=$?
exit "${BD_HOOK_EXIT}"
EOF
  chmod +x "${tmp}/.githooks/pre-commit"
  cat <<'EOF' > "${tmp}/bin/bd"
#!/usr/bin/env bash
set -euo pipefail

if [[ "$*" == "config get issue_prefix --json" ]]; then
  printf '{"key":"issue_prefix","value":"live"}\n'
  exit 0
fi

exit 1
EOF
  chmod +x "${tmp}/bin/bd"

  PATH="${tmp}/bin:${PATH}" bash "${repo_root}/scripts/scaffold.sh" "${tmp}" "all" >/tmp/scaffold-existing-beads.out

  jq -e '.variables.BEADS_PREFIX == "live"' "${state}" >/dev/null
  require_file "${tmp}/.beads/config.scaffold-candidate.yaml"
  require_text "issue-prefix: live" "${tmp}/.beads/config.scaffold-candidate.yaml"

  require_file "${tmp}/.beads/clone-contract.scaffold-candidate.json"
  jq -e '.issue_prefix == "live"' "${tmp}/.beads/clone-contract.scaffold-candidate.json" >/dev/null
  jq -e '.jsonl_export == ".beads/issues.jsonl"' "${tmp}/.beads/clone-contract.scaffold-candidate.json" >/dev/null
  jq -e '.bootstrap_commands == [
    "bd bootstrap --yes --json",
    "git config core.hooksPath .githooks"
  ]' "${tmp}/.beads/clone-contract.scaffold-candidate.json" >/dev/null
  jq -e '.stale_runtime_recovery.local_pins | index(".beads/dolt-server.port")' "${tmp}/.beads/clone-contract.scaffold-candidate.json" >/dev/null

  require_file "${tmp}/.githooks/pre-commit.scaffold-candidate"
  require_text "pre-commit.local" "${tmp}/.githooks/pre-commit.scaffold-candidate"
  require_text "Preserved from pre-existing .githooks/pre-commit" "${tmp}/.githooks/pre-commit.scaffold-candidate"
  require_text 'scripts/secrets-validate' "${tmp}/.githooks/pre-commit.scaffold-candidate"
  require_text 'scripts/lint' "${tmp}/.githooks/pre-commit.scaffold-candidate"
  forbid_text "Refreshing Beads tracker exports" "${tmp}/.githooks/pre-commit.scaffold-candidate"
  forbid_text "bd export -o .beads/issues.jsonl" "${tmp}/.githooks/pre-commit.scaffold-candidate"
  forbid_text "BD_HOOK_EXIT" "${tmp}/.githooks/pre-commit.scaffold-candidate"

  require_file "${tmp}/.githooks/beads-pre-commit.scaffold-candidate.sh"
  require_text "git ls-files -- .beads/" "${tmp}/.githooks/beads-pre-commit.scaffold-candidate.sh"
  require_text "tracked .beads/ files are involved" "${tmp}/.githooks/beads-pre-commit.scaffold-candidate.sh"

  jq -e '.adoptionConflicts | map(.target) |
    index(".beads/config.yaml") and
    index(".beads/clone-contract.json") and
    index(".githooks/pre-commit") and
    index(".githooks/beads-pre-commit.sh")' "${state}" >/dev/null

  rm -f /tmp/scaffold-existing-beads.out
}

assert_state_accurate() {
  local tmp="$1"
  local agent_harness="$2"
  local state="${tmp}/.agent-scaffold.json"

  [[ -f "${state}" ]] || { echo "state file missing in ${tmp}" >&2; exit 1; }

  local generatedBy
  generatedBy=$(jq -r '.generatedBy' "${state}")
  [[ "${generatedBy}" == "agent-bootstrap" ]] || {
    echo "expected generatedBy=agent-bootstrap, got ${generatedBy}" >&2; exit 1; }

  jq -e '.templateVersion' "${state}" >/dev/null
  jq -e '.templateSource' "${state}" >/dev/null
  jq -e '.variables' "${state}" >/dev/null

  while IFS= read -r target; do
    [[ -f "${tmp}/${target}" ]] || {
      echo "state file claims ${target} but file is missing in ${tmp}" >&2
      exit 1
    }
  done < <(jq -r '.files[].target' "${state}")

  if [[ "${agent_harness}" == "claude-code" ]]; then
    local extras
    extras=$(jq -r '.files[].target' "${state}" \
      | grep -E '^(AGENTS\.md|\.codex/|\.antigravity/)' || true)
    if [[ -n "${extras}" ]]; then
      echo "claude-code state leaked entries:" >&2
      echo "${extras}" >&2
      exit 1
    fi
  fi

  local listed
  listed=$(jq -r '.files[].target' "${state}" | sort -u)
  while IFS= read -r found; do
    [[ -z "${found}" ]] && continue
    local rel="${found#${tmp}/}"
    case "${rel}" in
      .claude/plans/*|.claude/context/*|.claude/architecture/*) continue ;;
      .agent-scaffold.json) continue ;;
      .beads/issues.jsonl) continue ;;
      .beads/README.md|.beads/metadata.json|.beads/export-state.json|.beads/push-state.json|.beads/interactions.jsonl) continue ;;
      .beads/embeddeddolt/*) continue ;;
    esac
    if ! grep -Fxq "${rel}" <<< "${listed}"; then
      echo "file ${rel} exists in ${tmp} but is not in state file" >&2
      exit 1
    fi
  done < <(find "${tmp}/.claude" "${tmp}/.codex" "${tmp}/.antigravity" \
                  "${tmp}/.beads" "${tmp}/.githooks" \
                  "${tmp}/AGENTS.md" \
                  -type f 2>/dev/null)

  git -C "${tmp}" init -q
  : > "${tmp}/.beads/export-state.json"
  mkdir -p "${tmp}/.beads/embeddeddolt/beads/.dolt"
  : > "${tmp}/.beads/embeddeddolt/beads/.dolt/config.json"
  if ! git -C "${tmp}" check-ignore -q .beads/export-state.json; then
    echo ".beads/export-state.json should be ignored in ${tmp}" >&2
    exit 1
  fi
  if ! git -C "${tmp}" check-ignore -q .beads/embeddeddolt/beads/.dolt/config.json; then
    echo ".beads/embeddeddolt should be ignored in ${tmp}" >&2
    exit 1
  fi

  if git -C "${tmp}" check-ignore -q .beads/issues.jsonl; then
    echo ".beads/issues.jsonl should remain trackable in ${tmp}" >&2
    exit 1
  fi

  if [[ -f "${tmp}/AGENTS.md" ]]; then
    require_text "Project-Specific Safety Constraints" "${tmp}/AGENTS.md"
    require_text "Agents must not run \`git add\`, \`git commit\`, or \`git push\` as an automatic session-close workflow." "${tmp}/AGENTS.md"
    require_text "If local Beads runtime state is stale" "${tmp}/AGENTS.md"
    require_text "Do not create markdown TODO trackers or side ledgers for net-new work." "${tmp}/AGENTS.md"
    require_text "A high-quality Beads task has a concrete title, scope-bearing description, design notes, observable acceptance criteria, evidence notes, estimate, and dependencies where relevant." "${tmp}/AGENTS.md"
    require_file "${tmp}/.codex/skills/audit-beads-quality.md"
    require_file "${tmp}/.antigravity/skills/audit-beads-quality.md"
    forbid_text "fabricate-beads-history" "${tmp}/.agent-scaffold.json"
    require_text "routine scaffold refreshes do not require \`/bootstrap\`" "${tmp}/AGENTS.md"
    forbid_text "{{BUILD_COMMAND}}" "${tmp}/AGENTS.md"
    forbid_text "{{LINT_COMMAND}}" "${tmp}/AGENTS.md"
    forbid_text "{{SCAFFOLD_COMMAND}}" "${tmp}/AGENTS.md"
  fi
  jq -e '.stale_runtime_recovery.retry_probes | index("bd status --json") and index("bd ready --json")' "${tmp}/.beads/clone-contract.json" >/dev/null
  jq -e '.jsonl_export == ".beads/issues.jsonl"' "${tmp}/.beads/clone-contract.json" >/dev/null
  forbid_text "{{LINT_COMMAND}}" "${tmp}/.agents/anti-patterns.md"
}

assert_agents_local_safety_constraints_survive_refresh() {
  local tmp="$1"
  local state="${tmp}/.agent-scaffold.json"
  local checksum=""

  awk '
    {
      print
    }
    /^## Project-Specific Safety Constraints[[:space:]]*$/ {
      print ""
      print "- Local smoke constraint: preserve project-specific safety guidance across scaffold refreshes."
    }
  ' "${tmp}/AGENTS.md" > "${tmp}/AGENTS.md.next"
  mv "${tmp}/AGENTS.md.next" "${tmp}/AGENTS.md"

  checksum="$(shasum -a 256 "${tmp}/AGENTS.md" | awk '{print $1}')"
  jq --arg checksum "${checksum}" '
    .files |= map(if .target == "AGENTS.md" then .checksum = $checksum else . end)
  ' "${state}" > "${state}.next"
  mv "${state}.next" "${state}"

  bash "${repo_root}/scripts/scaffold.sh" "${tmp}" "all" >/tmp/scaffold-agents-local-safety.out
  require_text "Local smoke constraint: preserve project-specific safety guidance across scaffold refreshes." "${tmp}/AGENTS.md"
  rm -f /tmp/scaffold-agents-local-safety.out
}

assert_agents_value_drift_refreshes() {
  local tmp="$1"
  local state="${tmp}/.agent-scaffold.json"
  local checksum=""

  awk '
    /^- \*\*Source Directory:\*\* / {
      print "- **Source Directory:** cmd/..."
      next
    }
    /^# Build$/ {
      print
      getline
      print "go build ./cmd/agent-sandbox"
      next
    }
    /^# Test$/ {
      print
      getline
      print "go test ./..."
      next
    }
    /^# Run$/ {
      print
      getline
      print "go run ./cmd/agent-sandbox --help"
      next
    }
    /^- \*\*Typecheck:\*\* `/ {
      print "- **Typecheck:** `go test ./...`"
      next
    }
    {
      print
    }
  ' "${tmp}/AGENTS.md" > "${tmp}/AGENTS.md.next"
  mv "${tmp}/AGENTS.md.next" "${tmp}/AGENTS.md"

  bash "${repo_root}/scripts/scaffold.sh" "${tmp}" "all" >/tmp/scaffold-agents-value-drift.out

  require_text "- **Source Directory:** cmd/..." "${tmp}/AGENTS.md"
  require_text "go build ./cmd/agent-sandbox" "${tmp}/AGENTS.md"
  require_text "go test ./..." "${tmp}/AGENTS.md"
  require_text "go run ./cmd/agent-sandbox --help" "${tmp}/AGENTS.md"
  jq -e '.variables.SOURCE_DIR == "cmd/..."' "${state}" >/dev/null
  jq -e '.variables.BUILD_COMMAND == "go build ./cmd/agent-sandbox"' "${state}" >/dev/null
  jq -e '.variables.TEST_COMMAND == "go test ./..."' "${state}" >/dev/null
  jq -e '.variables.RUN_COMMAND == "go run ./cmd/agent-sandbox --help"' "${state}" >/dev/null
  jq -e '.variables.TYPECHECK_COMMAND == "go test ./..."' "${state}" >/dev/null
  checksum="$(shasum -a 256 "${tmp}/AGENTS.md" | awk '{print $1}')"
  jq -e --arg checksum "${checksum}" '.files[] | select(.target == "AGENTS.md") | .checksum == $checksum' "${state}" >/dev/null

  rm -f /tmp/scaffold-agents-value-drift.out
}

assert_state_first_value_hydration_refreshes() {
  local tmp="$1"
  local state="${tmp}/.agent-scaffold.json"

  jq '
    .variables.BUILD_COMMAND = "printf \"build ok\"" |
    .variables.RUN_COMMAND = "printf \"run ok\""
  ' "${state}" > "${state}.next"
  mv "${state}.next" "${state}"

  bash "${repo_root}/scripts/scaffold.sh" "${tmp}" "all" >/tmp/scaffold-state-first-hydration.out

  require_text 'printf "build ok"' "${tmp}/AGENTS.md"
  require_text 'printf "run ok"' "${tmp}/AGENTS.md"
  jq -e '.variables.BUILD_COMMAND == "printf \"build ok\""' "${state}" >/dev/null
  jq -e '.variables.RUN_COMMAND == "printf \"run ok\""' "${state}" >/dev/null

  rm -f /tmp/scaffold-state-first-hydration.out
}

assert_state_advanced_partial_agents_refreshes() {
  local tmp="$1"
  local state="${tmp}/.agent-scaffold.json"

  jq '
    .variables.SOURCE_DIR = "cmd/agent-sandbox and internal packages" |
    .variables.BUILD_COMMAND = "go build ./cmd/agent-sandbox" |
    .variables.TYPECHECK_COMMAND = "go test ./..." |
    .variables.TEST_COMMAND = "go test ./..." |
    .variables.RUN_COMMAND = "go run ./cmd/agent-sandbox --help"
  ' "${state}" > "${state}.next"
  mv "${state}.next" "${state}"

  awk '
    /^# Build$/ {
      print
      getline
      print "go build ./cmd/agent-sandbox"
      next
    }
    /^# Test$/ {
      print
      getline
      print "go test ./..."
      next
    }
    /^# Run$/ {
      print
      getline
      print "go run ./cmd/agent-sandbox --help"
      next
    }
    /^- \*\*Typecheck:\*\* `/ {
      print "- **Typecheck:** `go test ./...`"
      next
    }
    {
      print
    }
  ' "${tmp}/AGENTS.md" > "${tmp}/AGENTS.md.next"
  mv "${tmp}/AGENTS.md.next" "${tmp}/AGENTS.md"

  bash "${repo_root}/scripts/scaffold.sh" "${tmp}" "all" >/tmp/scaffold-state-advanced-partial-agents.out

  require_text "- **Source Directory:** cmd/agent-sandbox and internal packages" "${tmp}/AGENTS.md"
  require_text "go build ./cmd/agent-sandbox" "${tmp}/AGENTS.md"
  require_text "go test ./..." "${tmp}/AGENTS.md"
  require_text "go run ./cmd/agent-sandbox --help" "${tmp}/AGENTS.md"
  jq -e '.variables.SOURCE_DIR == "cmd/agent-sandbox and internal packages"' "${state}" >/dev/null
  jq -e '.variables.BUILD_COMMAND == "go build ./cmd/agent-sandbox"' "${state}" >/dev/null

  rm -f /tmp/scaffold-state-advanced-partial-agents.out
}

assert_beads_partial_commit_guard() {
  if ! command -v bd >/dev/null 2>&1; then
    echo "bd not found; skipping Beads partial-commit smoke test"
    return 0
  fi

  local tmp
  local repo
  tmp=$(mktemp -d -t scaffold-smoke-beads-XXXX)
  repo="${tmp}/repo"

  git clone -q "${repo_root}" "${repo}"
  cp -R "${repo_root}/.githooks/." "${repo}/.githooks/"
  git -C "${repo}" config user.name "Scaffold Smoke"
  git -C "${repo}" config user.email "scaffold-smoke@example.com"
  git -C "${repo}" config beads.role maintainer
  git -C "${repo}" config core.hooksPath .githooks
  chmod 700 "${repo}/.beads"

  (cd "${repo}" && bd bootstrap --yes --json >/dev/null)
  if ! git -C "${repo}" diff --quiet -- .githooks; then
    git -C "${repo}" add .githooks
    git -C "${repo}" commit -m "test: sync hook under test" >/dev/null
  fi

  (cd "${repo}" && bd create "Smoke test partial commit guard" \
    --type task \
    --priority 1 \
    --description "Verify the scaffolded Beads hook blocks pathspec commits when the exported issue snapshot is involved, so the snapshot cannot be left behind in the main index." \
    --design "Create a task, modify README.md, attempt a pathspec commit, require a fail-loud message, then retry with a full commit and verify a clean result." \
    --acceptance "- Pathspec commit fails loudly\n- Full commit succeeds and includes .beads/issues.jsonl\n- No staged Beads snapshot remains afterward" \
    --notes "Smoke-test coverage for scaffolded hook behavior with explicit pathspec commits." \
    --estimate 5 \
    --json >/dev/null)

  printf 'smoke test\n' >> "${repo}/README.md"
  git -C "${repo}" add README.md

  local commit_err
  commit_err=$(mktemp "${TMPDIR:-/tmp}/scaffold-pathspec-commit.XXXXXX")
  if git -C "${repo}" commit README.md -m "test partial commit" > /dev/null 2> "${commit_err}"; then
    echo "pathspec commit should have failed when Beads snapshot was involved in ${repo}" >&2
    exit 1
  fi
  require_text "beads: tracked .beads/ files are involved in this commit" "${commit_err}"

  git -C "${repo}" commit -m "test full commit" >/dev/null

  if [[ -n "$(git -C "${repo}" status --short)" ]]; then
    echo "full commit should not leave Beads changes behind in ${repo}" >&2
    exit 1
  fi

  git -C "${repo}" show --stat --oneline HEAD -- .beads/issues.jsonl README.md > "${commit_err}.head"
  require_text ".beads/issues.jsonl" "${commit_err}.head"
  require_text "README.md" "${commit_err}.head"

  rm -f "${commit_err}" "${commit_err}.head"
  rm -rf "${tmp}"
}

tmp_all=$(mktemp -d -t scaffold-smoke-all-XXXX)
tmp_cadence=$(mktemp -d -t scaffold-smoke-cadence-XXXX)
tmp_beads_readiness=$(mktemp -d -t scaffold-smoke-beads-readiness-XXXX)
trap 'rm -rf "${tmp_all:-}" "${tmp_cadence:-}" "${tmp_beads_readiness:-}" "${tmp_value_drift:-}" "${tmp_state_hydration:-}" "${tmp_state_advanced_partial:-}" "${tmp_cc:-}" "${tmp_adopt:-}" "${tmp_existing_beads:-}" "${tmp_resolved:-}"' EXIT
assert_bootstrap_prompt_cadence "${tmp_cadence}"
assert_beads_readiness_message_matches_status "${tmp_beads_readiness}"
run_scaffold "${tmp_all}" "all"
assert_state_accurate "${tmp_all}" "all"
assert_agents_local_safety_constraints_survive_refresh "${tmp_all}"
assert_drift_fails_loud "${tmp_all}"

tmp_value_drift=$(mktemp -d -t scaffold-smoke-value-drift-XXXX)
run_scaffold "${tmp_value_drift}" "all"
assert_agents_value_drift_refreshes "${tmp_value_drift}"

tmp_state_hydration=$(mktemp -d -t scaffold-smoke-state-hydration-XXXX)
run_scaffold "${tmp_state_hydration}" "all"
assert_state_first_value_hydration_refreshes "${tmp_state_hydration}"

tmp_state_advanced_partial=$(mktemp -d -t scaffold-smoke-state-advanced-partial-XXXX)
run_scaffold "${tmp_state_advanced_partial}" "all"
assert_state_advanced_partial_agents_refreshes "${tmp_state_advanced_partial}"

tmp_cc=$(mktemp -d -t scaffold-smoke-cc-XXXX)
run_scaffold "${tmp_cc}" "claude-code"
assert_state_accurate "${tmp_cc}" "claude-code"

tmp_adopt=$(mktemp -d -t scaffold-smoke-adopt-XXXX)
assert_adoption_conflict_is_preserved "${tmp_adopt}"
assert_adoption_conflict_blocks_rerun "${tmp_adopt}"
assert_adoption_conflict_drift_fails_loud "${tmp_adopt}"

tmp_existing_beads=$(mktemp -d -t scaffold-smoke-existing-beads-XXXX)
assert_existing_beads_contract_is_inferred "${tmp_existing_beads}"

tmp_resolved=$(mktemp -d -t scaffold-smoke-resolved-XXXX)
assert_adoption_conflict_is_preserved "${tmp_resolved}"
assert_adoption_conflict_resolution_unblocks_rerun "${tmp_resolved}"

assert_beads_partial_commit_guard

echo "scaffold smoke test passed"
