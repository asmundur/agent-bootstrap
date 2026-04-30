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
  rg -F --quiet "${pattern}" "${path}" || {
    echo "missing expected text in ${path}: ${pattern}" >&2
    exit 1
  }
}

forbid_text() {
  local pattern="$1"
  local path="$2"
  if rg -F --quiet "${pattern}" "${path}"; then
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
  "bootstrap-templates/templates/universal/workflows/feature-workflow.md.tmpl"
)

local_files=(
  "AGENTS.md"
  ".agent-scaffold.json"
  ".claude/CLAUDE.md"
  ".claude/anti-patterns.md"
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
  ".claude/skills/fabricate-beads-history.md"
  ".claude/workflows/feature-workflow.md"
  ".codex/skills/bootstrap.md"
  ".codex/skills/grill-me.md"
  ".codex/skills/ubiquitous-language.md"
  ".codex/skills/improve-architecture.md"
  ".codex/skills/tdd.md"
  ".codex/skills/feature-start.md"
  ".codex/skills/retro.md"
  ".codex/skills/resolve-adopted-artifacts.md"
  ".codex/skills/fabricate-beads-history.md"
  ".antigravity/skills/bootstrap.md"
  ".antigravity/skills/grill-me.md"
  ".antigravity/skills/ubiquitous-language.md"
  ".antigravity/skills/improve-architecture.md"
  ".antigravity/skills/tdd.md"
  ".antigravity/skills/feature-start.md"
  ".antigravity/skills/retro.md"
  ".antigravity/skills/resolve-adopted-artifacts.md"
  ".antigravity/skills/fabricate-beads-history.md"
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
require_text "\"target\": \".claude/skills/bootstrap.md\"" ".agent-scaffold.json"
require_text "\"target\": \".claude/skills/resolve-adopted-artifacts.md\"" ".agent-scaffold.json"
require_text "\"target\": \".codex/skills/feature-start.md\"" ".agent-scaffold.json"
require_text "\"target\": \".antigravity/skills/feature-start.md\"" ".agent-scaffold.json"
require_text "filling in the project-specific values" "bootstrap-templates/templates/universal/skills/bootstrap.md.tmpl"
require_text "resolve all unresolved scaffold adoption conflicts in one pass" "bootstrap-templates/templates/universal/skills/resolve-adopted-artifacts.md.tmpl"
require_text "line-item policy inventory" "bootstrap-templates/templates/universal/skills/resolve-adopted-artifacts.md.tmpl"
require_text "Project-Specific Safety Constraints" "bootstrap-templates/templates/universal/AGENTS.md.tmpl"
require_text "Stage 0 — Shared Design Alignment" "bootstrap-templates/templates/universal/workflows/feature-workflow.md.tmpl"
require_text 'Create or update `.claude/context/ubiquitous-language.md`' "bootstrap-templates/templates/universal/skills/ubiquitous-language.md.tmpl"
forbid_text "/sync-bootstrap" ".claude/CLAUDE.md"

run_scaffold() {
  local tmp="$1"
  local agent_harness="$2"
  mkdir -p "${tmp}"
  bash "${repo_root}/scripts/scaffold.sh" "${tmp}" "${agent_harness}" >/dev/null
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
  if ! git -C "${tmp}" check-ignore -q .beads/export-state.json; then
    echo ".beads/export-state.json should be ignored in ${tmp}" >&2
    exit 1
  fi

  if git -C "${tmp}" check-ignore -q .beads/issues.jsonl; then
    echo ".beads/issues.jsonl should remain trackable in ${tmp}" >&2
    exit 1
  fi

  if [[ -f "${tmp}/AGENTS.md" ]]; then
    require_text "Project-Specific Safety Constraints" "${tmp}/AGENTS.md"
    forbid_text "{{BUILD_COMMAND}}" "${tmp}/AGENTS.md"
    forbid_text "{{LINT_COMMAND}}" "${tmp}/AGENTS.md"
  fi
  forbid_text "{{LINT_COMMAND}}" "${tmp}/.claude/anti-patterns.md"
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
  require_text "beads: .beads/issues.jsonl is involved in this commit" "${commit_err}"

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
trap 'rm -rf "${tmp_all:-}" "${tmp_cc:-}"' EXIT
run_scaffold "${tmp_all}" "all"
assert_state_accurate "${tmp_all}" "all"
assert_drift_fails_loud "${tmp_all}"

tmp_cc=$(mktemp -d -t scaffold-smoke-cc-XXXX)
run_scaffold "${tmp_cc}" "claude-code"
assert_state_accurate "${tmp_cc}" "claude-code"

tmp_adopt=$(mktemp -d -t scaffold-smoke-adopt-XXXX)
assert_adoption_conflict_is_preserved "${tmp_adopt}"
assert_adoption_conflict_blocks_rerun "${tmp_adopt}"
assert_adoption_conflict_drift_fails_loud "${tmp_adopt}"

tmp_resolved=$(mktemp -d -t scaffold-smoke-resolved-XXXX)
assert_adoption_conflict_is_preserved "${tmp_resolved}"
assert_adoption_conflict_resolution_unblocks_rerun "${tmp_resolved}"

assert_beads_partial_commit_guard

echo "scaffold smoke test passed"
