#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$(cd "${SCRIPT_DIR}/../bootstrap-templates/templates/universal" && pwd)"

if [[ ! -d "${TEMPLATE_DIR}" ]]; then
  echo "Error: Cannot find templates at ${TEMPLATE_DIR}"
  exit 1
fi

TARGET_DIR="${1:-.}"
AGENT_HARNESS="${2:-${AGENT_HARNESS:-all}}"
STATE_FILE=".agent-scaffold.json"
LEGACY_STATE_FILE=".claude/.bootstrap-manifest.json"

case "${AGENT_HARNESS}" in
  all|claude-code|codex|antigravity) ;;
  *)
    echo "Error: AGENT_HARNESS must be one of: all, claude-code, codex, antigravity"
    exit 1
    ;;
esac

cd "${TARGET_DIR}"

echo "Applying scaffold in $(pwd)..."

mkdir -p .claude/agents .claude/architecture .claude/context .claude/plans .claude/skills .claude/workflows
mkdir -p .codex/skills
mkdir -p .antigravity/skills
mkdir -p .beads
mkdir -p .githooks

existing_state_file=""
if [[ -f "${STATE_FILE}" ]]; then
  existing_state_file="${STATE_FILE}"
elif [[ -f "${LEGACY_STATE_FILE}" ]]; then
  existing_state_file="${LEGACY_STATE_FILE}"
fi

json_value() {
  local key="$1"
  local fallback="$2"
  local value=""

  if [[ -n "${existing_state_file}" ]]; then
    value="$(jq -r --arg key "${key}" '.variables[$key] // empty' "${existing_state_file}")"
  fi

  if [[ -n "${value}" ]]; then
    printf '%s\n' "${value}"
  else
    printf '%s\n' "${fallback}"
  fi
}

PROJECT_NAME="$(json_value "PROJECT_NAME" "__PROJECT_NAME__")"
PROJECT_DESCRIPTION="$(json_value "PROJECT_DESCRIPTION" "Project description pending /bootstrap.")"
TECH_STACK="$(json_value "TECH_STACK" "Unknown")"
MAIN_LANGUAGE="$(json_value "MAIN_LANGUAGE" "Unknown")"
BUILD_COMMAND="$(json_value "BUILD_COMMAND" "not configured")"
TYPECHECK_COMMAND="$(json_value "TYPECHECK_COMMAND" "not configured")"
LINT_COMMAND="$(json_value "LINT_COMMAND" "not configured")"
BROWSER_VERIFY_COMMAND="$(json_value "BROWSER_VERIFY_COMMAND" "not configured")"
TEST_COMMAND="$(json_value "TEST_COMMAND" "not configured")"
RUN_COMMAND="$(json_value "RUN_COMMAND" "not configured")"
SOURCE_DIR="$(json_value "SOURCE_DIR" "not configured")"
ARCHITECTURE_PATTERN="$(json_value "ARCHITECTURE_PATTERN" "not configured")"
BEADS_PREFIX="$(json_value "BEADS_PREFIX" "prj")"
BOOTSTRAP_DATE="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

export P_PROJECT_NAME="${PROJECT_NAME}"
export P_PROJECT_DESCRIPTION="${PROJECT_DESCRIPTION}"
export P_TECH_STACK="${TECH_STACK}"
export P_MAIN_LANGUAGE="${MAIN_LANGUAGE}"
export P_BUILD_COMMAND="${BUILD_COMMAND}"
export P_TYPECHECK_COMMAND="${TYPECHECK_COMMAND}"
export P_LINT_COMMAND="${LINT_COMMAND}"
export P_BROWSER_VERIFY_COMMAND="${BROWSER_VERIFY_COMMAND}"
export P_TEST_COMMAND="${TEST_COMMAND}"
export P_RUN_COMMAND="${RUN_COMMAND}"
export P_SOURCE_DIR="${SOURCE_DIR}"
export P_ARCHITECTURE_PATTERN="${ARCHITECTURE_PATTERN}"
export P_AGENT_HARNESS="${AGENT_HARNESS}"
export P_BEADS_PREFIX="${BEADS_PREFIX}"
export P_BOOTSTRAP_DATE="${BOOTSTRAP_DATE}"

replace_vars() {
  awk '
  function esc(s) {
    gsub(/\\/, "\\\\", s)
    gsub(/&/, "\\\\&", s)
    return s
  }
  {
    gsub(/\{\{PROJECT_NAME\}\}/, esc(ENVIRON["P_PROJECT_NAME"]))
    gsub(/\{\{PROJECT_DESCRIPTION\}\}/, esc(ENVIRON["P_PROJECT_DESCRIPTION"]))
    gsub(/\{\{TECH_STACK\}\}/, esc(ENVIRON["P_TECH_STACK"]))
    gsub(/\{\{MAIN_LANGUAGE\}\}/, esc(ENVIRON["P_MAIN_LANGUAGE"]))
    gsub(/\{\{BUILD_COMMAND\}\}/, esc(ENVIRON["P_BUILD_COMMAND"]))
    gsub(/\{\{TYPECHECK_COMMAND\}\}/, esc(ENVIRON["P_TYPECHECK_COMMAND"]))
    gsub(/\{\{LINT_COMMAND\}\}/, esc(ENVIRON["P_LINT_COMMAND"]))
    gsub(/\{\{BROWSER_VERIFY_COMMAND\}\}/, esc(ENVIRON["P_BROWSER_VERIFY_COMMAND"]))
    gsub(/\{\{TEST_COMMAND\}\}/, esc(ENVIRON["P_TEST_COMMAND"]))
    gsub(/\{\{RUN_COMMAND\}\}/, esc(ENVIRON["P_RUN_COMMAND"]))
    gsub(/\{\{SOURCE_DIR\}\}/, esc(ENVIRON["P_SOURCE_DIR"]))
    gsub(/\{\{ARCHITECTURE_PATTERN\}\}/, esc(ENVIRON["P_ARCHITECTURE_PATTERN"]))
    gsub(/\{\{AGENT_HARNESS\}\}/, esc(ENVIRON["P_AGENT_HARNESS"]))
    gsub(/\{\{BEADS_PREFIX\}\}/, esc(ENVIRON["P_BEADS_PREFIX"]))
    gsub(/\{\{BOOTSTRAP_DATE\}\}/, esc(ENVIRON["P_BOOTSTRAP_DATE"]))
    print
  }' "$1"
}

GENERATED_TARGETS=()
GENERATED_SOURCES=()
GENERATED_CATEGORIES=()
GENERATED_CHECKSUMS=()
OBSOLETE_TARGETS=()

record_generated() {
  GENERATED_TARGETS+=("$1")
  GENERATED_SOURCES+=("$2")
  GENERATED_CATEGORIES+=("$3")
  GENERATED_CHECKSUMS+=("$4")
}

file_checksum() {
  shasum -a 256 "$1" | awk '{print $1}'
}

state_file_checksum() {
  local target="$1"

  if [[ -z "${existing_state_file}" ]]; then
    return 0
  fi

  jq -r --arg target "${target}" '.files[] | select(.target == $target) | .checksum // empty' "${existing_state_file}"
}

ensure_safe_to_replace() {
  local target="$1"
  local expected_checksum=""
  local current_checksum=""

  if [[ ! -f "${target}" ]]; then
    return 0
  fi

  expected_checksum="$(state_file_checksum "${target}")"
  if [[ -z "${expected_checksum}" ]]; then
    return 0
  fi

  current_checksum="$(file_checksum "${target}")"
  if [[ "${current_checksum}" != "${expected_checksum}" ]]; then
    echo "Error: scaffold-managed file has local edits: ${target}" >&2
    echo "Refusing to overwrite drifted scaffold-managed files." >&2
    exit 1
  fi
}

write_from_tmp() {
  local tmp="$1"
  local dst="$2"
  local src="$3"
  local category="$4"
  local make_executable="${5:-false}"
  local checksum=""

  ensure_safe_to_replace "${dst}"
  mv "${tmp}" "${dst}"
  if [[ "${make_executable}" == "true" ]]; then
    chmod +x "${dst}"
  fi
  checksum="$(file_checksum "${dst}")"
  record_generated "${dst}" "${src}" "${category}" "${checksum}"
  echo "  ✓ ${dst}"
}

mark_obsolete_targets() {
  local target=""
  local found="false"

  if [[ -z "${existing_state_file}" ]]; then
    return 0
  fi

  while IFS= read -r target; do
    [[ -z "${target}" ]] && continue
    found="false"
    for generated in "${GENERATED_TARGETS[@]}"; do
      if [[ "${generated}" == "${target}" ]]; then
        found="true"
        break
      fi
    done
    if [[ "${found}" == "false" ]]; then
      OBSOLETE_TARGETS+=("${target}")
    fi
  done < <(jq -r '.files[].target' "${existing_state_file}")
}

prune_obsolete_targets() {
  local target=""

  if [[ ${#OBSOLETE_TARGETS[@]} -eq 0 ]]; then
    return 0
  fi

  for target in "${OBSOLETE_TARGETS[@]}"; do
    [[ ! -f "${target}" ]] && continue
    ensure_safe_to_replace "${target}"
    rm -f "${target}"
    echo "  ✓ removed obsolete ${target}"
  done
}

copy_template() {
  local src="$1"
  local dst="$2"
  local category="${3:-config}"
  local tmp=""
  tmp="$(mktemp "${TMPDIR:-/tmp}/scaffold-template.XXXXXX")"
  replace_vars "${TEMPLATE_DIR}/${src}" > "${tmp}"
  write_from_tmp "${tmp}" "${dst}" "${src}" "${category}"
}

copy_hook() {
  local src="$1"
  local dst="$2"
  local category="${3:-hook}"
  local tmp=""
  tmp="$(mktemp "${TMPDIR:-/tmp}/scaffold-hook.XXXXXX")"
  cp "${TEMPLATE_DIR}/${src}" "${tmp}"
  write_from_tmp "${tmp}" "${dst}" "${src}" "${category}" "true"
}

copy_raw() {
  local src="$1"
  local dst="$2"
  local category="${3:-config}"
  local tmp=""
  tmp="$(mktemp "${TMPDIR:-/tmp}/scaffold-raw.XXXXXX")"
  cp "${TEMPLATE_DIR}/${src}" "${tmp}"
  write_from_tmp "${tmp}" "${dst}" "${src}" "${category}"
}

copy_template "anti-patterns.md.tmpl" ".claude/anti-patterns.md" "config"
copy_template "agents/feature-implementation.md.tmpl" ".claude/agents/feature-implementation.md" "agent"
copy_template "agents/git-manager.md.tmpl" ".claude/agents/git-manager.md" "agent"

for skill in bootstrap grill-me ubiquitous-language improve-architecture tdd feature-start retro fabricate-beads-history; do
  copy_template "skills/${skill}.md.tmpl" ".claude/skills/${skill}.md" "skill"
done

copy_template "workflows/feature-workflow.md.tmpl" ".claude/workflows/feature-workflow.md" "workflow"

copy_template "beads/config.yaml.tmpl" ".beads/config.yaml" "beads"
copy_template "beads/clone-contract.json.tmpl" ".beads/clone-contract.json" "beads"
copy_raw "beads/gitignore" ".beads/.gitignore" "beads"

copy_hook "githooks/_common.sh" ".githooks/_common.sh" "hook"
copy_hook "githooks/beads-pre-commit.sh" ".githooks/beads-pre-commit.sh" "hook"
copy_hook "githooks/pre-commit" ".githooks/pre-commit" "hook"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git config core.hooksPath .githooks >/dev/null 2>&1 || true
fi

BEADS_BOOTSTRAP_STATUS="not_attempted"
if command -v bd >/dev/null 2>&1; then
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if bd bootstrap --yes --json >/dev/null 2>&1 && bd status --json >/dev/null 2>&1; then
      BEADS_BOOTSTRAP_STATUS="ok"
    else
      BEADS_BOOTSTRAP_STATUS="failed"
    fi
  else
    BEADS_BOOTSTRAP_STATUS="deferred"
  fi
fi

if [[ "${AGENT_HARNESS}" == "all" || "${AGENT_HARNESS}" == "codex" || "${AGENT_HARNESS}" == "antigravity" ]]; then
  copy_template "AGENTS.md.tmpl" "AGENTS.md" "config"
  for skill in bootstrap grill-me ubiquitous-language improve-architecture tdd feature-start retro fabricate-beads-history; do
    if [[ "${AGENT_HARNESS}" == "all" || "${AGENT_HARNESS}" == "codex" ]]; then
      copy_template "skills/${skill}.md.tmpl" ".codex/skills/${skill}.md" "skill"
    fi
    if [[ "${AGENT_HARNESS}" == "all" || "${AGENT_HARNESS}" == "antigravity" ]]; then
      copy_template "skills/${skill}.md.tmpl" ".antigravity/skills/${skill}.md" "skill"
    fi
  done
fi

if [[ "${AGENT_HARNESS}" == "all" || "${AGENT_HARNESS}" == "claude-code" ]]; then
  export P_OVERVIEW_SECTION=""
  export P_AGENTS_IMPORT=""

  if [[ "${AGENT_HARNESS}" == "all" ]]; then
    P_AGENTS_IMPORT="@AGENTS.md\n\n"
  else
    P_OVERVIEW_SECTION="\n## Project Overview\n\n${P_PROJECT_DESCRIPTION}\n\n- **Tech Stack:** ${P_TECH_STACK}\n- **Language:** ${P_MAIN_LANGUAGE}\n- **Source Directory:** ${P_SOURCE_DIR}\n- **Architecture:** ${P_ARCHITECTURE_PATTERN}\n\n## Essential Commands\n\n\`\`\`bash\n# Build\n${P_BUILD_COMMAND}\n\n# Typecheck (optional)\n${P_TYPECHECK_COMMAND}\n\n# Lint (optional)\n${P_LINT_COMMAND}\n\n# Browser verification (optional)\n${P_BROWSER_VERIFY_COMMAND}\n\n# Test\n${P_TEST_COMMAND}\n\n# Run\n${P_RUN_COMMAND}\n\`\`\`\n\n## Architecture & Key Patterns\n\n${P_ARCHITECTURE_PATTERN}\n\nRun \`/bootstrap\` after applying the scaffold so these values can be hydrated from the existing codebase.\n\n## Durable Artifacts\n\n- **Feature specs:** \`.claude/plans/<feature-slug>.md\`\n- **Ubiquitous language:** \`.claude/context/ubiquitous-language.md\`\n- **Module map:** \`.claude/architecture/module-map.md\`\n\nThese files are created or refreshed by the generated skills.\n\n## Code Style Guidelines\n\n- Match the style of surrounding code\n- Functions should do one thing\n- Name things for what they are, not how they're implemented\n- Validate at system boundaries (user input, external APIs) — trust internal code\n- No dead code, no commented-out blocks, no TODO left behind after a feature\n- Tests are not optional\n\n## Task Tracking — Beads\n\nThis project uses [beads](https://github.com/steveyegge/beads) (\`bd\`) for task tracking. Issue prefix: \`${P_BEADS_PREFIX}\`.\n\nBefore starting new work:\n    bd ready --json\n    bd update <id> --claim --json\n\nCreating a task:\n    bd create --title \"...\" -p 2 --json\n\nClosing a task:\n    bd close <id> --reason \"done\" --json\n\n\`.beads/issues.jsonl\` is the git-tracked snapshot; the pre-commit hook refreshes it via \`bd export --no-memories\` and auto-stages changes, so task state travels with commits. Do not edit \`.beads/issues.jsonl\` by hand. Do not bypass the hook (\`--no-verify\`).\n"
  fi

  tmp_claude="$(mktemp "${TMPDIR:-/tmp}/scaffold-claude.XXXXXX")"
  replace_vars "${TEMPLATE_DIR}/CLAUDE.md.tmpl" > "${tmp_claude}"

  awk '
  {
    if (index($0, "{{AGENTS_MD_IMPORT}}") > 0) {
      if (ENVIRON["P_AGENTS_IMPORT"] != "") {
        printf "@AGENTS.md\n\n"
      }
    } else if (index($0, "{{PROJECT_OVERVIEW_SECTION}}") > 0) {
      if (ENVIRON["P_OVERVIEW_SECTION"] != "") {
        print ENVIRON["P_OVERVIEW_SECTION"]
      }
    } else {
      print $0
    }
  }' "${tmp_claude}" > "${tmp_claude}.rendered"

  rm "${tmp_claude}"
  write_from_tmp "${tmp_claude}.rendered" ".claude/CLAUDE.md" "CLAUDE.md.tmpl" "config"
fi

mark_obsolete_targets
prune_obsolete_targets

{
  printf '{\n'
  printf '  "generatedBy": "agent-bootstrap",\n'
  printf '  "templateVersion": "1.2.0",\n'
  printf '  "generatedAt": "%s",\n' "${BOOTSTRAP_DATE}"
  printf '  "agentHarness": "%s",\n' "${AGENT_HARNESS}"
  printf '  "templateSource": "bootstrap-templates/templates/universal",\n'
  printf '  "variables": {\n'
  printf '    "PROJECT_NAME": "%s",\n' "${PROJECT_NAME}"
  printf '    "PROJECT_DESCRIPTION": "%s",\n' "${PROJECT_DESCRIPTION}"
  printf '    "TECH_STACK": "%s",\n' "${TECH_STACK}"
  printf '    "MAIN_LANGUAGE": "%s",\n' "${MAIN_LANGUAGE}"
  printf '    "BUILD_COMMAND": "%s",\n' "${BUILD_COMMAND}"
  printf '    "TYPECHECK_COMMAND": "%s",\n' "${TYPECHECK_COMMAND}"
  printf '    "LINT_COMMAND": "%s",\n' "${LINT_COMMAND}"
  printf '    "BROWSER_VERIFY_COMMAND": "%s",\n' "${BROWSER_VERIFY_COMMAND}"
  printf '    "TEST_COMMAND": "%s",\n' "${TEST_COMMAND}"
  printf '    "RUN_COMMAND": "%s",\n' "${RUN_COMMAND}"
  printf '    "SOURCE_DIR": "%s",\n' "${SOURCE_DIR}"
  printf '    "ARCHITECTURE_PATTERN": "%s",\n' "${ARCHITECTURE_PATTERN}"
  printf '    "AGENT_HARNESS": "%s",\n' "${AGENT_HARNESS}"
  printf '    "BEADS_PREFIX": "%s",\n' "${BEADS_PREFIX}"
  printf '    "BOOTSTRAP_DATE": "%s"\n' "${BOOTSTRAP_DATE}"
  printf '  },\n'
  printf '  "files": [\n'

  count="${#GENERATED_TARGETS[@]}"
  for ((i=0; i<count; i++)); do
    comma=","
    if [[ $i -eq $((count - 1)) ]]; then
      comma=""
    fi
    printf '    { "target": "%s", "source": "%s", "category": "%s", "checksum": "%s" }%s\n' \
      "${GENERATED_TARGETS[$i]}" "${GENERATED_SOURCES[$i]}" "${GENERATED_CATEGORIES[$i]}" "${GENERATED_CHECKSUMS[$i]}" "${comma}"
  done

  printf '  ]\n'
  printf '}\n'
} > "${STATE_FILE}"
echo "  ✓ ${STATE_FILE}"

if [[ -f "${LEGACY_STATE_FILE}" ]]; then
  rm -f "${LEGACY_STATE_FILE}"
fi

echo ""
echo "Scaffold applied."
if [[ "${BEADS_BOOTSTRAP_STATUS}" == "ok" ]]; then
  echo "Beads bootstrap verified."
elif [[ "${BEADS_BOOTSTRAP_STATUS}" == "failed" ]]; then
  echo "Warning: scaffold files were written, but 'bd bootstrap --yes --json' did not complete successfully."
  echo "Verify Beads readiness with: bd status --json"
elif [[ "${BEADS_BOOTSTRAP_STATUS}" == "deferred" ]]; then
  echo "Note: target is not a git worktree yet, so Beads bootstrap was deferred."
  echo "After git init or clone, verify Beads readiness with: bd bootstrap --yes --json"
elif [[ "${BEADS_BOOTSTRAP_STATUS}" == "not_attempted" ]]; then
  echo "Note: 'bd' was not found in PATH, so Beads readiness was not verified."
fi
echo "Next step: run /bootstrap in your agent harness to hydrate project-specific values from the codebase."
