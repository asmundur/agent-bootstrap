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
  "bootstrap-templates/templates/universal/skills/sync-bootstrap.md.tmpl"
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
  ".claude/skills/sync-bootstrap.md"
  ".claude/skills/fabricate-beads-history.md"
  ".claude/workflows/feature-workflow.md"
  ".codex/skills/bootstrap.md"
  ".codex/skills/grill-me.md"
  ".codex/skills/ubiquitous-language.md"
  ".codex/skills/improve-architecture.md"
  ".codex/skills/tdd.md"
  ".codex/skills/feature-start.md"
  ".codex/skills/retro.md"
  ".codex/skills/sync-bootstrap.md"
  ".codex/skills/fabricate-beads-history.md"
  ".antigravity/skills/bootstrap.md"
  ".antigravity/skills/grill-me.md"
  ".antigravity/skills/ubiquitous-language.md"
  ".antigravity/skills/improve-architecture.md"
  ".antigravity/skills/tdd.md"
  ".antigravity/skills/feature-start.md"
  ".antigravity/skills/retro.md"
  ".antigravity/skills/sync-bootstrap.md"
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
require_text "\"TYPECHECK_COMMAND\": \"not configured\"" ".agent-scaffold.json"
require_text "\"target\": \".claude/skills/bootstrap.md\"" ".agent-scaffold.json"
require_text "\"target\": \".codex/skills/sync-bootstrap.md\"" ".agent-scaffold.json"
require_text "\"target\": \".antigravity/skills/sync-bootstrap.md\"" ".agent-scaffold.json"
require_text "filling in the project-specific values" "bootstrap-templates/templates/universal/skills/bootstrap.md.tmpl"
require_text "Stage 0 — Shared Design Alignment" "bootstrap-templates/templates/universal/workflows/feature-workflow.md.tmpl"
require_text 'Create or update `.claude/context/ubiquitous-language.md`' "bootstrap-templates/templates/universal/skills/ubiquitous-language.md.tmpl"

run_scaffold() {
  local tmp="$1"
  local agent_harness="$2"
  mkdir -p "${tmp}"
  bash "${repo_root}/scripts/scaffold.sh" "${tmp}" "${agent_harness}" >/dev/null
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

  forbid_text "{{BUILD_COMMAND}}" "${tmp}/AGENTS.md"
  forbid_text "{{LINT_COMMAND}}" "${tmp}/AGENTS.md"
  forbid_text "{{LINT_COMMAND}}" "${tmp}/.claude/anti-patterns.md"
}

tmp_all=$(mktemp -d -t scaffold-smoke-all-XXXX)
trap 'rm -rf "${tmp_all:-}" "${tmp_cc:-}"' EXIT
run_scaffold "${tmp_all}" "all"
assert_state_accurate "${tmp_all}" "all"

tmp_cc=$(mktemp -d -t scaffold-smoke-cc-XXXX)
run_scaffold "${tmp_cc}" "claude-code"
assert_state_accurate "${tmp_cc}" "claude-code"

echo "scaffold smoke test passed"
