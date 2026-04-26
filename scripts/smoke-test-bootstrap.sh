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

template_files=(
  "bootstrap-templates/templates/universal/AGENTS.md.tmpl"
  "bootstrap-templates/templates/universal/CLAUDE.md.tmpl"
  "bootstrap-templates/templates/universal/agents/feature-implementation.md.tmpl"
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
  ".claude/CLAUDE.md"
  ".claude/anti-patterns.md"
  ".claude/agents/feature-implementation.md"
  ".claude/agents/git-manager.md"
  ".claude/skills/grill-me.md"
  ".claude/skills/ubiquitous-language.md"
  ".claude/skills/improve-architecture.md"
  ".claude/skills/tdd.md"
  ".claude/skills/feature-start.md"
  ".claude/skills/retro.md"
  ".claude/skills/sync-bootstrap.md"
  ".claude/skills/fabricate-beads-history.md"
  ".claude/workflows/feature-workflow.md"
  ".claude/.bootstrap-manifest.json"
  ".codex/skills/grill-me.md"
  ".codex/skills/ubiquitous-language.md"
  ".codex/skills/improve-architecture.md"
  ".codex/skills/tdd.md"
  ".codex/skills/fabricate-beads-history.md"
  ".antigravity/skills/grill-me.md"
  ".antigravity/skills/ubiquitous-language.md"
  ".antigravity/skills/improve-architecture.md"
  ".antigravity/skills/tdd.md"
  ".antigravity/skills/fabricate-beads-history.md"
)

for path in "${template_files[@]}"; do
  require_file "${path}"
done

for path in "${local_files[@]}"; do
  require_file "${path}"
done

require_text "/grill-me" ".claude/CLAUDE.md"
require_text "/ubiquitous-language" ".claude/CLAUDE.md"
require_text "/improve-architecture" ".claude/CLAUDE.md"
require_text "/tdd" ".claude/CLAUDE.md"
require_text "\"generatedBy\": \"agent-bootstrap\"" ".claude/.bootstrap-manifest.json"
require_text "\"templateVersion\":" ".claude/.bootstrap-manifest.json"
require_text "\"templateSource\":" ".claude/.bootstrap-manifest.json"
require_text "\"TYPECHECK_COMMAND\": \"not configured\"" ".claude/.bootstrap-manifest.json"
require_text "\"target\": \".claude/skills/grill-me.md\"" ".claude/.bootstrap-manifest.json"
require_text "\"target\": \".codex/skills/tdd.md\"" ".claude/.bootstrap-manifest.json"
require_text "\"target\": \".antigravity/skills/tdd.md\"" ".claude/.bootstrap-manifest.json"
require_text "Implement the feature in small red/green/refactor steps" "bootstrap-templates/templates/universal/agents/feature-implementation.md.tmpl"
require_text "Stage 0 — Shared Design Alignment" "bootstrap-templates/templates/universal/workflows/feature-workflow.md.tmpl"
require_text 'Create or update `.claude/context/ubiquitous-language.md`' "bootstrap-templates/templates/universal/skills/ubiquitous-language.md.tmpl"

# --- End-to-end bootstrap into a temp dir, with manifest accuracy assertions ---

run_bootstrap() {
  local tmp="$1"
  local tool_target="$2"
  mkdir -p "${tmp}"
  # Feed empty answers so each prompt takes its default. Only TOOL_TARGET
  # needs an explicit value (its default is "all", but we want to vary it).
  # 14 reads in bootstrap.sh: project name, description, tech stack, main lang,
  # build, typecheck, lint, browser, test, run, source dir, arch pattern,
  # tool target, beads prefix.
  {
    printf '\n'        # PROJECT_NAME
    printf '\n'        # PROJECT_DESCRIPTION
    printf '\n'        # TECH_STACK
    printf '\n'        # MAIN_LANGUAGE
    printf '\n'        # BUILD_COMMAND
    printf '\n'        # TYPECHECK_COMMAND
    printf '\n'        # LINT_COMMAND
    printf '\n'        # BROWSER_VERIFY_COMMAND
    printf '\n'        # TEST_COMMAND
    printf '\n'        # RUN_COMMAND
    printf '\n'        # SOURCE_DIR
    printf '\n'        # ARCHITECTURE_PATTERN
    printf '%s\n' "${tool_target}"   # TOOL_TARGET
    printf '\n'        # BEADS_PREFIX
  } | bash "${repo_root}/scripts/bootstrap.sh" "${tmp}" >/dev/null
}

assert_manifest_accurate() {
  local tmp="$1"
  local tool_target="$2"
  local manifest="${tmp}/.claude/.bootstrap-manifest.json"

  [[ -f "${manifest}" ]] || { echo "manifest missing in ${tmp}" >&2; exit 1; }

  local generatedBy
  generatedBy=$(jq -r '.generatedBy' "${manifest}")
  [[ "${generatedBy}" == "agent-bootstrap" ]] || {
    echo "expected generatedBy=agent-bootstrap, got ${generatedBy}" >&2; exit 1; }

  jq -e '.templateVersion' "${manifest}" >/dev/null
  jq -e '.templateSource' "${manifest}" >/dev/null
  jq -e '.variables' "${manifest}" >/dev/null

  # 1. every listed target exists on disk
  while IFS= read -r target; do
    [[ -f "${tmp}/${target}" ]] || {
      echo "manifest claims ${target} but file is missing in ${tmp}" >&2
      exit 1
    }
  done < <(jq -r '.files[].target' "${manifest}")

  # 2. claude-code mode must NOT list AGENTS.md, .codex/, or .antigravity/
  if [[ "${tool_target}" == "claude-code" ]]; then
    local extras
    extras=$(jq -r '.files[].target' "${manifest}" \
      | grep -E '^(AGENTS\.md|\.codex/|\.antigravity/)' || true)
    if [[ -n "${extras}" ]]; then
      echo "claude-code manifest leaked entries:" >&2
      echo "${extras}" >&2
      exit 1
    fi
  fi

  # 3. every actually-generated file under known dirs must appear in manifest
  #    (skip user-owned runtime artifact dirs)
  local listed
  listed=$(jq -r '.files[].target' "${manifest}" | sort -u)
  while IFS= read -r found; do
    [[ -z "${found}" ]] && continue
    local rel="${found#${tmp}/}"
    case "${rel}" in
      .claude/plans/*|.claude/context/*|.claude/architecture/*) continue ;;
      .claude/.bootstrap-manifest.json) continue ;;
      .beads/issues.jsonl) continue ;;
    esac
    if ! grep -Fxq "${rel}" <<< "${listed}"; then
      echo "file ${rel} exists in ${tmp} but is not in manifest" >&2
      exit 1
    fi
  done < <(find "${tmp}/.claude" "${tmp}/.codex" "${tmp}/.antigravity" \
                  "${tmp}/.beads" "${tmp}/.githooks" \
                  "${tmp}/AGENTS.md" \
                  -type f 2>/dev/null)
}

tmp_all=$(mktemp -d -t bootstrap-smoke-all-XXXX)
trap 'rm -rf "${tmp_all:-}" "${tmp_cc:-}"' EXIT
run_bootstrap "${tmp_all}" "all"
assert_manifest_accurate "${tmp_all}" "all"

tmp_cc=$(mktemp -d -t bootstrap-smoke-cc-XXXX)
run_bootstrap "${tmp_cc}" "claude-code"
assert_manifest_accurate "${tmp_cc}" "claude-code"

echo "bootstrap smoke test passed"
