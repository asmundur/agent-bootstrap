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

mkdir -p .agents/architecture .agents/context .agents/plans .agents/workflows
mkdir -p .claude/agents .claude/skills
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

inferred_beads_prefix() {
  local value=""

  if [[ -n "${LIVE_BEADS_PREFIX:-}" ]]; then
    printf '%s\n' "${LIVE_BEADS_PREFIX}"
    return 0
  fi

  if [[ -f ".beads/config.yaml" ]]; then
    value="$(awk -F: '
      /^[[:space:]]*issue-prefix[[:space:]]*:/ {
        value = $2
        sub(/^[[:space:]]*/, "", value)
        sub(/[[:space:]]*$/, "", value)
        print value
        exit
      }
    ' ".beads/config.yaml")"
    if [[ -n "${value}" ]]; then
      printf '%s\n' "${value}"
      return 0
    fi
  fi

  if [[ -f ".beads/clone-contract.json" ]]; then
    value="$(jq -r '.issue_prefix // empty' ".beads/clone-contract.json" 2>/dev/null || true)"
    if [[ -n "${value}" ]]; then
      printf '%s\n' "${value}"
      return 0
    fi
  fi

  printf 'prj\n'
}

inferred_live_beads_prefix() {
  local value=""

  if ! command -v bd >/dev/null 2>&1; then
    return 0
  fi

  value="$(bd config get issue_prefix --json 2>/dev/null | jq -r '.value // empty' 2>/dev/null || true)"
  if [[ -n "${value}" && "${value}" != "null" ]]; then
    printf '%s\n' "${value}"
  fi
}

inferred_beads_bootstrap_commands_json() {
  local value=""

  if [[ -n "${LIVE_BEADS_PREFIX:-}" ]]; then
    printf '%s\n' '["bd bootstrap --yes --json","git config core.hooksPath .githooks"]'
    return 0
  fi

  if [[ -f ".beads/clone-contract.json" ]]; then
    value="$(jq -c '(.bootstrap_commands // empty) | select(type == "array" and length > 0)' ".beads/clone-contract.json" 2>/dev/null || true)"
    if [[ -n "${value}" ]]; then
      printf '%s\n' "${value}"
      return 0
    fi
  fi

  printf '%s\n' '["bd bootstrap --yes --json","git config core.hooksPath .githooks"]'
}

LIVE_BEADS_PREFIX="$(inferred_live_beads_prefix)"
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
SCAFFOLD_COMMAND="$(json_value "SCAFFOLD_COMMAND" "scripts/scaffold.sh")"
BEADS_PREFIX="$(json_value "BEADS_PREFIX" "$(inferred_beads_prefix)")"
BOOTSTRAP_DATE="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

refresh_scaffold_env() {
  BEADS_BOOTSTRAP_COMMANDS_JSON="$(inferred_beads_bootstrap_commands_json)"
  BEADS_BOOTSTRAP_COMMANDS="$(jq -r '.[]' <<< "${BEADS_BOOTSTRAP_COMMANDS_JSON}")"
  if ! grep -Fxq "bd status --json" <<< "${BEADS_BOOTSTRAP_COMMANDS}"; then
    BEADS_BOOTSTRAP_COMMANDS="${BEADS_BOOTSTRAP_COMMANDS}"$'\n'"bd status --json"
  fi

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
  export P_SCAFFOLD_COMMAND="${SCAFFOLD_COMMAND}"
  export P_AGENT_HARNESS="${AGENT_HARNESS}"
  export P_BEADS_PREFIX="${BEADS_PREFIX}"
  export P_BEADS_BOOTSTRAP_COMMANDS="${BEADS_BOOTSTRAP_COMMANDS}"
  export P_BOOTSTRAP_DATE="${BOOTSTRAP_DATE}"
}

refresh_scaffold_env

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
    gsub(/\{\{SCAFFOLD_COMMAND\}\}/, esc(ENVIRON["P_SCAFFOLD_COMMAND"]))
    gsub(/\{\{AGENT_HARNESS\}\}/, esc(ENVIRON["P_AGENT_HARNESS"]))
    gsub(/\{\{BEADS_PREFIX\}\}/, esc(ENVIRON["P_BEADS_PREFIX"]))
    gsub(/\{\{BEADS_BOOTSTRAP_COMMANDS\}\}/, esc(ENVIRON["P_BEADS_BOOTSTRAP_COMMANDS"]))
    gsub(/\{\{BOOTSTRAP_DATE\}\}/, esc(ENVIRON["P_BOOTSTRAP_DATE"]))
    print
  }' "$1"
}

GENERATED_TARGETS=()
GENERATED_SOURCES=()
GENERATED_CATEGORIES=()
GENERATED_CHECKSUMS=()
OBSOLETE_TARGETS=()
ADOPTION_CONFLICT_TARGETS=()
ADOPTION_CONFLICT_CANDIDATES=()
ADOPTION_CONFLICT_DETECTED_AT=()
ADOPTION_CONFLICT_TARGET_CHECKSUMS=()
ADOPTION_CONFLICT_CANDIDATE_CHECKSUMS=()
ADOPTION_CONFLICT_STATUSES=()
VALUE_DRIFT_SAFE_TARGETS=()
ADOPTED_VALUE_NAMES=()
ADOPTED_VALUE_VALUES=()

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

is_known_scaffold_value() {
  case "$1" in
    PROJECT_NAME|PROJECT_DESCRIPTION|TECH_STACK|MAIN_LANGUAGE|BUILD_COMMAND|TYPECHECK_COMMAND|LINT_COMMAND|BROWSER_VERIFY_COMMAND|TEST_COMMAND|RUN_COMMAND|SOURCE_DIR|ARCHITECTURE_PATTERN|SCAFFOLD_COMMAND|BEADS_PREFIX)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

current_scaffold_value() {
  case "$1" in
    PROJECT_NAME) printf '%s\n' "${PROJECT_NAME}" ;;
    PROJECT_DESCRIPTION) printf '%s\n' "${PROJECT_DESCRIPTION}" ;;
    TECH_STACK) printf '%s\n' "${TECH_STACK}" ;;
    MAIN_LANGUAGE) printf '%s\n' "${MAIN_LANGUAGE}" ;;
    BUILD_COMMAND) printf '%s\n' "${BUILD_COMMAND}" ;;
    TYPECHECK_COMMAND) printf '%s\n' "${TYPECHECK_COMMAND}" ;;
    LINT_COMMAND) printf '%s\n' "${LINT_COMMAND}" ;;
    BROWSER_VERIFY_COMMAND) printf '%s\n' "${BROWSER_VERIFY_COMMAND}" ;;
    TEST_COMMAND) printf '%s\n' "${TEST_COMMAND}" ;;
    RUN_COMMAND) printf '%s\n' "${RUN_COMMAND}" ;;
    SOURCE_DIR) printf '%s\n' "${SOURCE_DIR}" ;;
    ARCHITECTURE_PATTERN) printf '%s\n' "${ARCHITECTURE_PATTERN}" ;;
    SCAFFOLD_COMMAND) printf '%s\n' "${SCAFFOLD_COMMAND}" ;;
    BEADS_PREFIX) printf '%s\n' "${BEADS_PREFIX}" ;;
    *) return 1 ;;
  esac
}

set_scaffold_value() {
  local name="$1"
  local value="$2"

  case "${name}" in
    PROJECT_NAME) PROJECT_NAME="${value}" ;;
    PROJECT_DESCRIPTION) PROJECT_DESCRIPTION="${value}" ;;
    TECH_STACK) TECH_STACK="${value}" ;;
    MAIN_LANGUAGE) MAIN_LANGUAGE="${value}" ;;
    BUILD_COMMAND) BUILD_COMMAND="${value}" ;;
    TYPECHECK_COMMAND) TYPECHECK_COMMAND="${value}" ;;
    LINT_COMMAND) LINT_COMMAND="${value}" ;;
    BROWSER_VERIFY_COMMAND) BROWSER_VERIFY_COMMAND="${value}" ;;
    TEST_COMMAND) TEST_COMMAND="${value}" ;;
    RUN_COMMAND) RUN_COMMAND="${value}" ;;
    SOURCE_DIR) SOURCE_DIR="${value}" ;;
    ARCHITECTURE_PATTERN) ARCHITECTURE_PATTERN="${value}" ;;
    SCAFFOLD_COMMAND) SCAFFOLD_COMMAND="${value}" ;;
    BEADS_PREFIX) BEADS_PREFIX="${value}" ;;
    *) return 1 ;;
  esac
}

mark_value_drift_safe() {
  local target="$1"
  local existing=""

  if [[ ${#VALUE_DRIFT_SAFE_TARGETS[@]} -gt 0 ]]; then
    for existing in "${VALUE_DRIFT_SAFE_TARGETS[@]}"; do
      if [[ "${existing}" == "${target}" ]]; then
        return 0
      fi
    done
  fi

  VALUE_DRIFT_SAFE_TARGETS+=("${target}")
}

is_value_drift_safe() {
  local target="$1"
  local existing=""

  if [[ ${#VALUE_DRIFT_SAFE_TARGETS[@]} -gt 0 ]]; then
    for existing in "${VALUE_DRIFT_SAFE_TARGETS[@]}"; do
      if [[ "${existing}" == "${target}" ]]; then
        return 0
      fi
    done
  fi

  return 1
}

record_adopted_value() {
  local name="$1"
  local value="$2"
  local target="$3"
  local i=0

  if ! is_known_scaffold_value "${name}"; then
    return 0
  fi

  for ((i = 0; i < ${#ADOPTED_VALUE_NAMES[@]}; i++)); do
    if [[ "${ADOPTED_VALUE_NAMES[$i]}" == "${name}" ]]; then
      if [[ "${ADOPTED_VALUE_VALUES[$i]}" != "${value}" ]]; then
        echo "Error: scaffold variable ${name} has conflicting adopted values while reading ${target}" >&2
        echo "Refusing to guess which scaffold value should win." >&2
        exit 1
      fi
      return 0
    fi
  done

  ADOPTED_VALUE_NAMES+=("${name}")
  ADOPTED_VALUE_VALUES+=("${value}")
}

record_adopted_values_from_file() {
  local values_file="$1"
  local target="$2"
  local name=""
  local value=""

  while IFS=$'\t' read -r name value; do
    [[ -z "${name}" ]] && continue
    record_adopted_value "${name}" "${value}" "${target}"
  done < "${values_file}"
}

legacy_default_value() {
  case "$1" in
    BUILD_COMMAND|TYPECHECK_COMMAND|TEST_COMMAND|RUN_COMMAND)
      printf '%s\n' "not configured"
      ;;
    *)
      return 1
      ;;
  esac
}

record_default_based_adopted_values_from_file() {
  local values_file="$1"
  local target="$2"
  local name=""
  local value=""
  local baseline=""

  while IFS=$'\t' read -r name value; do
    [[ -z "${name}" ]] && continue
    baseline="$(legacy_default_value "${name}" || true)"
    [[ -n "${baseline}" ]] || continue
    if [[ "$(current_scaffold_value "${name}")" == "${baseline}" ]]; then
      record_adopted_value "${name}" "${value}" "${target}"
    fi
  done < "${values_file}"
}

apply_adopted_values() {
  local i=0

  for ((i = 0; i < ${#ADOPTED_VALUE_NAMES[@]}; i++)); do
    set_scaffold_value "${ADOPTED_VALUE_NAMES[$i]}" "${ADOPTED_VALUE_VALUES[$i]}"
  done
}

agents_value_snapshot() {
  local target="$1"
  local values_file="$2"
  local normalized_file="$3"

  : > "${values_file}"
  awk \
    -v values_path="${values_file}" \
    -v old_PROJECT_NAME="${PROJECT_NAME}" \
    -v old_PROJECT_DESCRIPTION="${PROJECT_DESCRIPTION}" \
    -v old_TECH_STACK="${TECH_STACK}" \
    -v old_MAIN_LANGUAGE="${MAIN_LANGUAGE}" \
    -v old_BUILD_COMMAND="${BUILD_COMMAND}" \
    -v old_TYPECHECK_COMMAND="${TYPECHECK_COMMAND}" \
    -v old_LINT_COMMAND="${LINT_COMMAND}" \
    -v old_BROWSER_VERIFY_COMMAND="${BROWSER_VERIFY_COMMAND}" \
    -v old_TEST_COMMAND="${TEST_COMMAND}" \
    -v old_RUN_COMMAND="${RUN_COMMAND}" \
    -v old_SOURCE_DIR="${SOURCE_DIR}" \
    -v old_ARCHITECTURE_PATTERN="${ARCHITECTURE_PATTERN}" \
    -v old_SCAFFOLD_COMMAND="${SCAFFOLD_COMMAND}" \
    -v old_BEADS_PREFIX="${BEADS_PREFIX}" '
      function old_value(name) {
        if (name == "PROJECT_NAME") return old_PROJECT_NAME
        if (name == "PROJECT_DESCRIPTION") return old_PROJECT_DESCRIPTION
        if (name == "TECH_STACK") return old_TECH_STACK
        if (name == "MAIN_LANGUAGE") return old_MAIN_LANGUAGE
        if (name == "BUILD_COMMAND") return old_BUILD_COMMAND
        if (name == "TYPECHECK_COMMAND") return old_TYPECHECK_COMMAND
        if (name == "LINT_COMMAND") return old_LINT_COMMAND
        if (name == "BROWSER_VERIFY_COMMAND") return old_BROWSER_VERIFY_COMMAND
        if (name == "TEST_COMMAND") return old_TEST_COMMAND
        if (name == "RUN_COMMAND") return old_RUN_COMMAND
        if (name == "SOURCE_DIR") return old_SOURCE_DIR
        if (name == "ARCHITECTURE_PATTERN") return old_ARCHITECTURE_PATTERN
        if (name == "SCAFFOLD_COMMAND") return old_SCAFFOLD_COMMAND
        if (name == "BEADS_PREFIX") return old_BEADS_PREFIX
        return ""
      }
      function emit(name, value) {
        print name "\t" value >> values_path
      }
      function after_prefix(line, prefix) {
        return substr(line, length(prefix) + 1)
      }
      function strip_suffix(value, suffix) {
        return substr(value, 1, length(value) - length(suffix))
      }
      function starts_with(line, prefix) {
        return substr(line, 1, length(prefix)) == prefix
      }
      function ends_with(line, suffix) {
        return substr(line, length(line) - length(suffix) + 1) == suffix
      }
      {
        line = $0

        if (next_command != "") {
          emit(next_command, line)
          line = old_value(next_command)
          next_command = ""
        } else if (NR == 1 && starts_with(line, "# ")) {
          emit("PROJECT_NAME", after_prefix(line, "# "))
          line = "# " old_value("PROJECT_NAME")
        } else if (line == "## Project Overview") {
          in_overview = 1
        } else if (in_overview == 1 && line == "") {
          in_overview = 2
        } else if (in_overview == 2) {
          emit("PROJECT_DESCRIPTION", line)
          line = old_value("PROJECT_DESCRIPTION")
          in_overview = 0
        } else if (starts_with(line, "- **Tech Stack:** ")) {
          emit("TECH_STACK", after_prefix(line, "- **Tech Stack:** "))
          line = "- **Tech Stack:** " old_value("TECH_STACK")
        } else if (starts_with(line, "- **Language:** ")) {
          emit("MAIN_LANGUAGE", after_prefix(line, "- **Language:** "))
          line = "- **Language:** " old_value("MAIN_LANGUAGE")
        } else if (starts_with(line, "- **Source Directory:** ")) {
          emit("SOURCE_DIR", after_prefix(line, "- **Source Directory:** "))
          line = "- **Source Directory:** " old_value("SOURCE_DIR")
        } else if (starts_with(line, "- **Architecture:** ")) {
          emit("ARCHITECTURE_PATTERN", after_prefix(line, "- **Architecture:** "))
          line = "- **Architecture:** " old_value("ARCHITECTURE_PATTERN")
        } else if (line == "# Apply or refresh scaffold") {
          next_command = "SCAFFOLD_COMMAND"
        } else if (line == "# Build") {
          next_command = "BUILD_COMMAND"
        } else if (line == "# Test") {
          next_command = "TEST_COMMAND"
        } else if (line == "# Run") {
          next_command = "RUN_COMMAND"
        } else if (starts_with(line, "- **Typecheck:** `") && ends_with(line, "`")) {
          value = after_prefix(line, "- **Typecheck:** `")
          value = strip_suffix(value, "`")
          emit("TYPECHECK_COMMAND", value)
          line = "- **Typecheck:** `" old_value("TYPECHECK_COMMAND") "`"
        } else if (starts_with(line, "- **Lint:** `") && ends_with(line, "`")) {
          value = after_prefix(line, "- **Lint:** `")
          value = strip_suffix(value, "`")
          emit("LINT_COMMAND", value)
          line = "- **Lint:** `" old_value("LINT_COMMAND") "`"
        } else if (starts_with(line, "- **Browser verification:** `") && ends_with(line, "`")) {
          value = after_prefix(line, "- **Browser verification:** `")
          value = strip_suffix(value, "`")
          emit("BROWSER_VERIFY_COMMAND", value)
          line = "- **Browser verification:** `" old_value("BROWSER_VERIFY_COMMAND") "`"
        } else if (starts_with(line, "Re-run `") && line ~ /^Re-run `[^`]+` whenever /) {
          value = after_prefix(line, "Re-run `")
          sub(/` whenever .*/, "", value)
          emit("SCAFFOLD_COMMAND", value)
          sub("`" value "`", "`" old_value("SCAFFOLD_COMMAND") "`", line)
        } else if (line ~ /Issue prefix: `[^`]+`\./) {
          value = line
          sub(/^.*Issue prefix: `/, "", value)
          sub(/`\..*$/, "", value)
          current_beads_prefix = value
          emit("BEADS_PREFIX", value)
          sub("`" value "`", "`" old_value("BEADS_PREFIX") "`", line)
        }

        if (current_beads_prefix != "") {
          gsub(current_beads_prefix "-xxx", old_value("BEADS_PREFIX") "-xxx", line)
          gsub(current_beads_prefix "-123", old_value("BEADS_PREFIX") "-123", line)
          gsub("discovered-from:" current_beads_prefix, "discovered-from:" old_value("BEADS_PREFIX"), line)
        }

        print line
      }
    ' "${target}" > "${normalized_file}"
}

agents_legacy_command_snapshot() {
  local target="$1"
  local values_file="$2"
  local normalized_file="$3"

  : > "${values_file}"
  awk -v values_path="${values_file}" '
    function emit(name, value) {
      print name "\t" value >> values_path
    }
    function after_prefix(line, prefix) {
      return substr(line, length(prefix) + 1)
    }
    function strip_suffix(value, suffix) {
      return substr(value, 1, length(value) - length(suffix))
    }
    function starts_with(line, prefix) {
      return substr(line, 1, length(prefix)) == prefix
    }
    function ends_with(line, suffix) {
      return substr(line, length(line) - length(suffix) + 1) == suffix
    }
    {
      line = $0

      if (next_command != "") {
        emit(next_command, line)
        line = "not configured"
        next_command = ""
      } else if (line == "# Build") {
        next_command = "BUILD_COMMAND"
      } else if (line == "# Test") {
        next_command = "TEST_COMMAND"
      } else if (line == "# Run") {
        next_command = "RUN_COMMAND"
      } else if (starts_with(line, "- **Typecheck:** `") && ends_with(line, "`")) {
        value = after_prefix(line, "- **Typecheck:** `")
        value = strip_suffix(value, "`")
        emit("TYPECHECK_COMMAND", value)
        line = "- **Typecheck:** `not configured`"
      }

      print line
    }
  ' "${target}" > "${normalized_file}"
}

adopt_agents_value_drift() {
  local target="$1"
  local expected_checksum="$2"
  local values_file=""
  local normalized_file=""
  local normalized_checksum=""

  values_file="$(mktemp "${TMPDIR:-/tmp}/scaffold-agents-values.XXXXXX")"
  normalized_file="$(mktemp "${TMPDIR:-/tmp}/scaffold-agents-normalized.XXXXXX")"
  agents_value_snapshot "${target}" "${values_file}" "${normalized_file}"
  normalized_checksum="$(file_checksum "${normalized_file}")"

  if [[ "${normalized_checksum}" == "${expected_checksum}" ]]; then
    record_adopted_values_from_file "${values_file}" "${target}"
    mark_value_drift_safe "${target}"
    rm -f "${values_file}" "${normalized_file}"
    return 0
  fi

  rm -f "${values_file}" "${normalized_file}"

  values_file="$(mktemp "${TMPDIR:-/tmp}/scaffold-agents-values.XXXXXX")"
  normalized_file="$(mktemp "${TMPDIR:-/tmp}/scaffold-agents-normalized.XXXXXX")"
  agents_legacy_command_snapshot "${target}" "${values_file}" "${normalized_file}"
  normalized_checksum="$(file_checksum "${normalized_file}")"

  if [[ "${normalized_checksum}" == "${expected_checksum}" ]]; then
    record_default_based_adopted_values_from_file "${values_file}" "${target}"
    mark_value_drift_safe "${target}"
    rm -f "${values_file}" "${normalized_file}"
    return 0
  fi

  rm -f "${values_file}" "${normalized_file}"
  return 1
}

template_value_snapshot() {
  local target="$1"
  local source="$2"
  local values_file="$3"
  local normalized_file="$4"
  local template="${TEMPLATE_DIR}/${source}"

  : > "${values_file}"
  awk \
    -v values_path="${values_file}" \
    -v old_PROJECT_NAME="${PROJECT_NAME}" \
    -v old_PROJECT_DESCRIPTION="${PROJECT_DESCRIPTION}" \
    -v old_TECH_STACK="${TECH_STACK}" \
    -v old_MAIN_LANGUAGE="${MAIN_LANGUAGE}" \
    -v old_BUILD_COMMAND="${BUILD_COMMAND}" \
    -v old_TYPECHECK_COMMAND="${TYPECHECK_COMMAND}" \
    -v old_LINT_COMMAND="${LINT_COMMAND}" \
    -v old_BROWSER_VERIFY_COMMAND="${BROWSER_VERIFY_COMMAND}" \
    -v old_TEST_COMMAND="${TEST_COMMAND}" \
    -v old_RUN_COMMAND="${RUN_COMMAND}" \
    -v old_SOURCE_DIR="${SOURCE_DIR}" \
    -v old_ARCHITECTURE_PATTERN="${ARCHITECTURE_PATTERN}" \
    -v old_SCAFFOLD_COMMAND="${SCAFFOLD_COMMAND}" \
    -v old_BEADS_PREFIX="${BEADS_PREFIX}" '
      function old_value(name) {
        if (name == "PROJECT_NAME") return old_PROJECT_NAME
        if (name == "PROJECT_DESCRIPTION") return old_PROJECT_DESCRIPTION
        if (name == "TECH_STACK") return old_TECH_STACK
        if (name == "MAIN_LANGUAGE") return old_MAIN_LANGUAGE
        if (name == "BUILD_COMMAND") return old_BUILD_COMMAND
        if (name == "TYPECHECK_COMMAND") return old_TYPECHECK_COMMAND
        if (name == "LINT_COMMAND") return old_LINT_COMMAND
        if (name == "BROWSER_VERIFY_COMMAND") return old_BROWSER_VERIFY_COMMAND
        if (name == "TEST_COMMAND") return old_TEST_COMMAND
        if (name == "RUN_COMMAND") return old_RUN_COMMAND
        if (name == "SOURCE_DIR") return old_SOURCE_DIR
        if (name == "ARCHITECTURE_PATTERN") return old_ARCHITECTURE_PATTERN
        if (name == "SCAFFOLD_COMMAND") return old_SCAFFOLD_COMMAND
        if (name == "BEADS_PREFIX") return old_BEADS_PREFIX
        return ""
      }
      function known(name) {
        return name == "PROJECT_NAME" || name == "PROJECT_DESCRIPTION" || name == "TECH_STACK" || name == "MAIN_LANGUAGE" || name == "BUILD_COMMAND" || name == "TYPECHECK_COMMAND" || name == "LINT_COMMAND" || name == "BROWSER_VERIFY_COMMAND" || name == "TEST_COMMAND" || name == "RUN_COMMAND" || name == "SOURCE_DIR" || name == "ARCHITECTURE_PATTERN" || name == "SCAFFOLD_COMMAND" || name == "BEADS_PREFIX"
      }
      function emit(name, value) {
        print name "\t" value >> values_path
      }
      NR == FNR {
        template[FNR] = $0
        template_count = FNR
        next
      }
      {
        target_count = FNR
        tmpl = template[FNR]
        line = $0

        first_start = index(tmpl, "{{")
        if (first_start == 0) {
          if (line != tmpl) failed = 1
          print line
          next
        }

        before = substr(tmpl, 1, first_start - 1)
        after_start = index(substr(tmpl, first_start + 2), "}}")
        if (after_start == 0) {
          failed = 1
          print line
          next
        }

        name = substr(tmpl, first_start + 2, after_start - 1)
        rest = substr(tmpl, first_start + after_start + 3)
        if (index(rest, "{{") > 0 || ! known(name)) {
          failed = 1
          print line
          next
        }

        if (substr(line, 1, length(before)) != before || substr(line, length(line) - length(rest) + 1) != rest) {
          failed = 1
          print line
          next
        }

        value = substr(line, length(before) + 1, length(line) - length(before) - length(rest))
        emit(name, value)
        print before old_value(name) rest
      }
      END {
        if (target_count != template_count || failed) {
          exit 1
        }
      }
    ' "${template}" "${target}" > "${normalized_file}"
}

adopt_template_value_drift() {
  local target="$1"
  local source="$2"
  local expected_checksum="$3"
  local values_file=""
  local normalized_file=""
  local normalized_checksum=""

  [[ "${source}" == *.tmpl ]] || return 1
  [[ -f "${TEMPLATE_DIR}/${source}" ]] || return 1

  values_file="$(mktemp "${TMPDIR:-/tmp}/scaffold-template-values.XXXXXX")"
  normalized_file="$(mktemp "${TMPDIR:-/tmp}/scaffold-template-normalized.XXXXXX")"

  if ! template_value_snapshot "${target}" "${source}" "${values_file}" "${normalized_file}"; then
    rm -f "${values_file}" "${normalized_file}"
    return 1
  fi

  normalized_checksum="$(file_checksum "${normalized_file}")"
  if [[ "${normalized_checksum}" == "${expected_checksum}" ]]; then
    record_adopted_values_from_file "${values_file}" "${target}"
    mark_value_drift_safe "${target}"
    rm -f "${values_file}" "${normalized_file}"
    return 0
  fi

  rm -f "${values_file}" "${normalized_file}"
  return 1
}

adopt_scaffold_value_drift() {
  local target=""
  local source=""
  local expected_checksum=""
  local current_checksum=""

  if [[ -z "${existing_state_file}" ]]; then
    return 0
  fi

  while IFS=$'\t' read -r target source expected_checksum; do
    [[ -z "${target}" || -z "${expected_checksum}" ]] && continue
    [[ -f "${target}" ]] || continue

    current_checksum="$(file_checksum "${target}")"
    if [[ "${current_checksum}" == "${expected_checksum}" ]]; then
      continue
    fi

    if [[ "${target}" == "AGENTS.md" ]]; then
      adopt_agents_value_drift "${target}" "${expected_checksum}" || true
    else
      adopt_template_value_drift "${target}" "${source}" "${expected_checksum}" || true
    fi
  done < <(jq -r '.files[]? | [.target, .source, .checksum] | @tsv' "${existing_state_file}")

  apply_adopted_values
  refresh_scaffold_env
}

scaffold_candidate_path() {
  local target="$1"
  local dir=""
  local base=""
  local stem=""
  local ext=""
  local prefix=""

  dir="$(dirname "${target}")"
  base="$(basename "${target}")"
  if [[ "${dir}" == "." ]]; then
    prefix=""
  else
    prefix="${dir}/"
  fi

  if [[ "${base}" == .* && "${base#*.}" != *.* ]]; then
    printf '%s%s.scaffold-candidate\n' "${prefix}" "${base}"
    return 0
  fi

  if [[ "${base}" == *.* && "${base}" != .* ]]; then
    stem="${base%.*}"
    ext="${base##*.}"
    printf '%s%s.scaffold-candidate.%s\n' "${prefix}" "${stem}" "${ext}"
    return 0
  fi

  if [[ "${base}" == .* && "${base#*.}" == *.* ]]; then
    stem="${base%.*}"
    ext="${base##*.}"
    printf '%s%s.scaffold-candidate.%s\n' "${prefix}" "${stem}" "${ext}"
    return 0
  fi

  printf '%s%s.scaffold-candidate\n' "${prefix}" "${base}"
}

record_adoption_conflict() {
  ADOPTION_CONFLICT_TARGETS+=("$1")
  ADOPTION_CONFLICT_CANDIDATES+=("$2")
  ADOPTION_CONFLICT_DETECTED_AT+=("$3")
  ADOPTION_CONFLICT_TARGET_CHECKSUMS+=("$4")
  ADOPTION_CONFLICT_CANDIDATE_CHECKSUMS+=("$5")
  ADOPTION_CONFLICT_STATUSES+=("unresolved")
}

ensure_safe_to_replace() {
  local target="$1"
  local expected_checksum=""
  local current_checksum=""

  if [[ ! -e "${target}" ]]; then
    return 0
  fi

  expected_checksum="$(state_file_checksum "${target}")"
  if [[ -z "${expected_checksum}" ]]; then
    echo "Error: no scaffold checksum is recorded for existing file: ${target}" >&2
    echo "Refusing to treat an untracked file as scaffold-managed." >&2
    exit 1
  fi

  current_checksum="$(file_checksum "${target}")"
  if [[ "${current_checksum}" != "${expected_checksum}" ]]; then
    echo "Error: scaffold-managed file has local edits: ${target}" >&2
    echo "Refusing to overwrite drifted scaffold-managed files." >&2
    exit 1
  fi
}

has_unresolved_adoption_conflicts() {
  if [[ -z "${existing_state_file}" ]]; then
    return 1
  fi

  jq -e '.adoptionConflicts | length > 0' "${existing_state_file}" >/dev/null 2>&1
}

verify_existing_adoption_conflicts() {
  local count=""
  local target=""
  local artifact=""
  local target_checksum=""
  local artifact_checksum=""
  local mode=""

  if ! has_unresolved_adoption_conflicts; then
    return 0
  fi

  while IFS=$'\t' read -r target artifact target_checksum artifact_checksum mode; do
    [[ -z "${target}" ]] && continue

    if [[ "${mode}" == "candidate" ]]; then
      if [[ ! -f "${target}" ]]; then
        echo "Error: active adoption-conflict target is missing: ${target}" >&2
        exit 1
      fi

      if [[ "$(file_checksum "${target}")" != "${target_checksum}" ]]; then
        echo "Error: active adoption-conflict target changed since capture: ${target}" >&2
        exit 1
      fi
    fi

    if [[ ! -f "${artifact}" ]]; then
      if [[ "${mode}" == "candidate" ]]; then
        echo "Error: scaffold adoption-conflict candidate is missing: ${artifact}" >&2
      else
        echo "Error: preserved adoption-conflict backup is missing: ${artifact}" >&2
      fi
      echo "Target still awaiting resolution: ${target}" >&2
      exit 1
    fi

    if [[ "$(file_checksum "${artifact}")" != "${artifact_checksum}" ]]; then
      if [[ "${mode}" == "candidate" ]]; then
        echo "Error: scaffold adoption-conflict candidate changed since capture: ${artifact}" >&2
      else
        echo "Error: preserved adoption-conflict backup changed since capture: ${artifact}" >&2
      fi
      echo "Target still awaiting resolution: ${target}" >&2
      exit 1
    fi
  done < <(jq -r '.adoptionConflicts[]? | [
    .target,
    (.scaffoldCandidate // .preservedBackup // ""),
    (.targetChecksum // .originalChecksum // ""),
    (.candidateChecksum // .preservedChecksum // ""),
    (if has("scaffoldCandidate") then "candidate" else "backup" end)
  ] | @tsv' "${existing_state_file}")

  count="$(jq -r '.adoptionConflicts | length' "${existing_state_file}")"
  echo "Error: scaffold has ${count} unresolved adoption conflict(s)." >&2
  jq -r '.adoptionConflicts[] |
    if has("scaffoldCandidate") then
      "  - " + .target + " (scaffold candidate at " + .scaffoldCandidate + ")"
    else
      "  - " + .target + " (preserved at " + .preservedBackup + ")"
    end' "${existing_state_file}" >&2
  echo "Run /resolve-adopted-artifacts before re-running scaffold." >&2
  exit 1
}

write_from_tmp() {
  local tmp="$1"
  local dst="$2"
  local src="$3"
  local category="$4"
  local make_executable="${5:-false}"
  local checksum=""
  local expected_checksum=""
  local current_checksum=""
  local candidate=""
  local target_checksum=""

  if [[ -e "${dst}" ]]; then
    expected_checksum="$(state_file_checksum "${dst}")"
    if [[ -z "${expected_checksum}" ]]; then
      candidate="$(scaffold_candidate_path "${dst}")"
      if [[ -e "${candidate}" ]]; then
        echo "Error: scaffold candidate path already exists: ${candidate}" >&2
        echo "Resolve or remove the stale scaffold candidate before re-running scaffold." >&2
        exit 1
      fi

      if [[ "${make_executable}" == "true" ]]; then
        chmod +x "${tmp}"
      fi
      target_checksum="$(file_checksum "${dst}")"
      checksum="$(file_checksum "${tmp}")"
      mv "${tmp}" "${candidate}"
      record_adoption_conflict "${dst}" "${candidate}" "${BOOTSTRAP_DATE}" "${target_checksum}" "${checksum}"
      record_generated "${dst}" "${src}" "${category}" "${checksum}"
      echo "  ! kept active pre-existing ${dst}; wrote scaffold candidate ${candidate}"
      return 0
    fi

    current_checksum="$(file_checksum "${dst}")"
    if [[ "${current_checksum}" != "${expected_checksum}" ]]; then
      if cmp -s "${dst}" "${tmp}"; then
        :
      elif is_value_drift_safe "${dst}"; then
        :
      else
        echo "Error: scaffold-managed file has local edits: ${dst}" >&2
        echo "Refusing to overwrite drifted scaffold-managed files." >&2
        exit 1
      fi
    fi
  fi

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
  if [[ "${dst}" == "AGENTS.md" ]]; then
    merge_agents_local_safety_constraints "${tmp}" "${dst}"
  fi
  write_from_tmp "${tmp}" "${dst}" "${src}" "${category}"
}

copy_hook() {
  local src="$1"
  local dst="$2"
  local category="${3:-hook}"
  local tmp=""
  tmp="$(mktemp "${TMPDIR:-/tmp}/scaffold-hook.XXXXXX")"
  cp "${TEMPLATE_DIR}/${src}" "${tmp}"
  if [[ "${dst}" == ".githooks/pre-commit" ]]; then
    merge_pre_commit_local_commands "${tmp}" "${dst}"
  fi
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

copy_beads_clone_contract() {
  local tmp=""
  tmp="$(mktemp "${TMPDIR:-/tmp}/scaffold-clone-contract.XXXXXX")"
  jq -n \
    --arg issue_prefix "${BEADS_PREFIX}" \
    --argjson bootstrap_commands "${BEADS_BOOTSTRAP_COMMANDS_JSON}" \
    '{
      mode: "bootstrap_required",
      backend: "dolt",
      issue_prefix: $issue_prefix,
      jsonl_export: "issues.jsonl",
      bootstrap_commands: $bootstrap_commands,
      read_probe: "bd status --json",
      stale_runtime_recovery: {
        verify_hooks_path: "git config --get core.hooksPath",
        local_pins: [
          ".beads/dolt-server.port"
        ],
        clear_when_unowned: [
          ".beads/dolt-server.pid",
          ".beads/dolt-server.log",
          ".beads/dolt-server.lock",
          ".beads/dolt-server.activity"
        ],
        retry_probes: [
          "bd status --json",
          "bd ready --json"
        ]
      }
    }' > "${tmp}"
  write_from_tmp "${tmp}" ".beads/clone-contract.json" "beads/clone-contract.json.tmpl" "beads"
}

merge_pre_commit_local_commands() {
  local tmp="$1"
  local existing="$2"
  local extra=""

  if [[ ! -f "${existing}" ]]; then
    return 0
  fi

  extra="$(mktemp "${TMPDIR:-/tmp}/scaffold-pre-commit-extra.XXXXXX")"
  awk '
    NR == FNR {
      seen[$0] = 1
      next
    }
    /^#!/ { next }
    /^[[:space:]]*set[[:space:]]+-euo[[:space:]]+pipefail[[:space:]]*$/ { next }
    /^[[:space:]]*$/ { next }
    /_common\.sh/ && /source/ { next }
    /beads-pre-commit\.sh/ { next }
    /^# Preserved from pre-existing \.githooks\/pre-commit during scaffold adoption\./ { next }
    /^[[:space:]]*if[[:space:]]+![[:space:]]+command[[:space:]]+-v[[:space:]]+bd[[:space:]]*>/ {
      skipping_legacy_beads = 1
      next
    }
    skipping_legacy_beads {
      if ($0 ~ /^[[:space:]]*exit[[:space:]]+"?\$\{?BD_HOOK_EXIT\}?"?[[:space:]]*$/) {
        skipping_legacy_beads = 0
      }
      next
    }
    seen[$0] { next }
    { print }
  ' "${tmp}" "${existing}" > "${extra}"

  if [[ -s "${extra}" ]]; then
    {
      printf '\n'
      printf '# Preserved from pre-existing .githooks/pre-commit during scaffold adoption.\n'
      cat "${extra}"
    } >> "${tmp}"
  fi

  rm -f "${extra}"
}

merge_agents_local_safety_constraints() {
  local tmp="$1"
  local existing="$2"
  local section=""
  local rendered=""

  if [[ ! -f "${existing}" ]]; then
    return 0
  fi

  section="$(mktemp "${TMPDIR:-/tmp}/scaffold-agents-safety.XXXXXX")"
  rendered="$(mktemp "${TMPDIR:-/tmp}/scaffold-agents-rendered.XXXXXX")"

  awk '
    /^## Project-Specific Safety Constraints[[:space:]]*$/ {
      in_section = 1
      next
    }
    in_section && /^## / {
      in_section = 0
    }
    in_section {
      print
    }
  ' "${existing}" > "${section}"

  if [[ -s "${section}" ]]; then
    awk -v section_path="${section}" '
      BEGIN {
        while ((getline line < section_path) > 0) {
          section = section line ORS
        }
        close(section_path)
      }
      /^## Project-Specific Safety Constraints[[:space:]]*$/ {
        print
        printf "%s", section
        skipping = 1
        next
      }
      skipping && /^## / {
        skipping = 0
        print
        next
      }
      skipping {
        next
      }
      {
        print
      }
    ' "${tmp}" > "${rendered}"
    mv "${rendered}" "${tmp}"
  else
    rm -f "${rendered}"
  fi

  rm -f "${section}"
}

verify_existing_adoption_conflicts
adopt_scaffold_value_drift

copy_template "anti-patterns.md.tmpl" ".agents/anti-patterns.md" "config"
copy_template "agents/feature-implementation.md.tmpl" ".claude/agents/feature-implementation.md" "agent"
copy_template "agents/git-manager.md.tmpl" ".claude/agents/git-manager.md" "agent"

for skill in bootstrap grill-me ubiquitous-language improve-architecture tdd feature-start retro resolve-adopted-artifacts audit-beads-quality; do
  copy_template "skills/${skill}.md.tmpl" ".claude/skills/${skill}.md" "skill"
done

copy_template "workflows/feature-workflow.md.tmpl" ".agents/workflows/feature-workflow.md" "workflow"

copy_template "beads/config.yaml.tmpl" ".beads/config.yaml" "beads"
copy_beads_clone_contract
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
  for skill in bootstrap grill-me ubiquitous-language improve-architecture tdd feature-start retro resolve-adopted-artifacts audit-beads-quality; do
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
    P_OVERVIEW_SECTION="\n## Project Overview\n\n${P_PROJECT_DESCRIPTION}\n\n- **Tech Stack:** ${P_TECH_STACK}\n- **Language:** ${P_MAIN_LANGUAGE}\n- **Source Directory:** ${P_SOURCE_DIR}\n- **Architecture:** ${P_ARCHITECTURE_PATTERN}\n\n## Essential Commands\n\n\`\`\`bash\n# Build\n${P_BUILD_COMMAND}\n\n# Typecheck (optional)\n${P_TYPECHECK_COMMAND}\n\n# Lint (optional)\n${P_LINT_COMMAND}\n\n# Browser verification (optional)\n${P_BROWSER_VERIFY_COMMAND}\n\n# Test\n${P_TEST_COMMAND}\n\n# Run\n${P_RUN_COMMAND}\n\`\`\`\n\n## Architecture & Key Patterns\n\n${P_ARCHITECTURE_PATTERN}\n\nRun \`/bootstrap\` after first scaffold adoption, or when these values need to be re-hydrated from the existing codebase.\n\n## Durable Artifacts\n\n- **Feature specs:** \`.agents/plans/<feature-slug>.md\`\n- **Ubiquitous language:** \`.agents/context/ubiquitous-language.md\`\n- **Module map:** \`.agents/architecture/module-map.md\`\n\nThese provider-neutral files are created or refreshed by the generated skills.\n\n## Code Style Guidelines\n\n- Match the style of surrounding code\n- Functions should do one thing\n- Name things for what they are, not how they're implemented\n- Validate at system boundaries (user input, external APIs) — trust internal code\n- No dead code, no commented-out blocks, no TODO left behind after a feature\n- Tests are not optional\n\n## Task Tracking — Beads\n\nThis project uses [beads](https://github.com/steveyegge/beads) (\`bd\`) for task tracking. Issue prefix: \`${P_BEADS_PREFIX}\`.\n\nBefore starting new work:\n    bd ready --json\n    bd update <id> --claim --json\n\nCreating a task:\n    bd create --title \"...\" -p 2 --json\n\nClosing a task:\n    bd close <id> --reason \"done\" --json\n\n\`.beads/issues.jsonl\` is the git-tracked snapshot; the pre-commit hook refreshes it via \`bd export --no-memories\` and auto-stages changes, so task state travels with commits. Do not edit \`.beads/issues.jsonl\` by hand. Do not bypass the hook (\`--no-verify\`).\n"
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

state_files_json="$(mktemp "${TMPDIR:-/tmp}/scaffold-state-files.XXXXXX")"
state_conflicts_json="$(mktemp "${TMPDIR:-/tmp}/scaffold-state-conflicts.XXXXXX")"
state_tmp="$(mktemp "${TMPDIR:-/tmp}/scaffold-state.XXXXXX")"
: > "${state_files_json}"
: > "${state_conflicts_json}"

count="${#GENERATED_TARGETS[@]}"
for ((i=0; i<count; i++)); do
  jq -nc \
    --arg target "${GENERATED_TARGETS[$i]}" \
    --arg source "${GENERATED_SOURCES[$i]}" \
    --arg category "${GENERATED_CATEGORIES[$i]}" \
    --arg checksum "${GENERATED_CHECKSUMS[$i]}" \
    '{ target: $target, source: $source, category: $category, checksum: $checksum }' >> "${state_files_json}"
done

count="${#ADOPTION_CONFLICT_TARGETS[@]}"
for ((i=0; i<count; i++)); do
  jq -nc \
    --arg target "${ADOPTION_CONFLICT_TARGETS[$i]}" \
    --arg scaffoldCandidate "${ADOPTION_CONFLICT_CANDIDATES[$i]}" \
    --arg detectedAt "${ADOPTION_CONFLICT_DETECTED_AT[$i]}" \
    --arg targetChecksum "${ADOPTION_CONFLICT_TARGET_CHECKSUMS[$i]}" \
    --arg candidateChecksum "${ADOPTION_CONFLICT_CANDIDATE_CHECKSUMS[$i]}" \
    --arg status "${ADOPTION_CONFLICT_STATUSES[$i]}" \
    '{
      target: $target,
      scaffoldCandidate: $scaffoldCandidate,
      detectedAt: $detectedAt,
      targetChecksum: $targetChecksum,
      candidateChecksum: $candidateChecksum,
      status: $status
    }' >> "${state_conflicts_json}"
done

jq -n \
  --arg generatedAt "${BOOTSTRAP_DATE}" \
  --arg agentHarness "${AGENT_HARNESS}" \
  --arg PROJECT_NAME "${PROJECT_NAME}" \
  --arg PROJECT_DESCRIPTION "${PROJECT_DESCRIPTION}" \
  --arg TECH_STACK "${TECH_STACK}" \
  --arg MAIN_LANGUAGE "${MAIN_LANGUAGE}" \
  --arg BUILD_COMMAND "${BUILD_COMMAND}" \
  --arg TYPECHECK_COMMAND "${TYPECHECK_COMMAND}" \
  --arg LINT_COMMAND "${LINT_COMMAND}" \
  --arg BROWSER_VERIFY_COMMAND "${BROWSER_VERIFY_COMMAND}" \
  --arg TEST_COMMAND "${TEST_COMMAND}" \
  --arg RUN_COMMAND "${RUN_COMMAND}" \
  --arg SOURCE_DIR "${SOURCE_DIR}" \
  --arg ARCHITECTURE_PATTERN "${ARCHITECTURE_PATTERN}" \
  --arg SCAFFOLD_COMMAND "${SCAFFOLD_COMMAND}" \
  --arg AGENT_HARNESS "${AGENT_HARNESS}" \
  --arg BEADS_PREFIX "${BEADS_PREFIX}" \
  --arg BOOTSTRAP_DATE "${BOOTSTRAP_DATE}" \
  --slurpfile files "${state_files_json}" \
  --slurpfile adoptionConflicts "${state_conflicts_json}" \
  '{
    generatedBy: "agent-bootstrap",
    templateVersion: "1.2.0",
    generatedAt: $generatedAt,
    agentHarness: $agentHarness,
    templateSource: "bootstrap-templates/templates/universal",
    variables: {
      PROJECT_NAME: $PROJECT_NAME,
      PROJECT_DESCRIPTION: $PROJECT_DESCRIPTION,
      TECH_STACK: $TECH_STACK,
      MAIN_LANGUAGE: $MAIN_LANGUAGE,
      BUILD_COMMAND: $BUILD_COMMAND,
      TYPECHECK_COMMAND: $TYPECHECK_COMMAND,
      LINT_COMMAND: $LINT_COMMAND,
      BROWSER_VERIFY_COMMAND: $BROWSER_VERIFY_COMMAND,
      TEST_COMMAND: $TEST_COMMAND,
      RUN_COMMAND: $RUN_COMMAND,
      SOURCE_DIR: $SOURCE_DIR,
      ARCHITECTURE_PATTERN: $ARCHITECTURE_PATTERN,
      SCAFFOLD_COMMAND: $SCAFFOLD_COMMAND,
      AGENT_HARNESS: $AGENT_HARNESS,
      BEADS_PREFIX: $BEADS_PREFIX,
      BOOTSTRAP_DATE: $BOOTSTRAP_DATE
    }
  }
  + (if ($adoptionConflicts | length) > 0 then { adoptionConflicts: $adoptionConflicts } else {} end)
  + { files: $files }' > "${state_tmp}"
mv "${state_tmp}" "${STATE_FILE}"
rm -f "${state_files_json}" "${state_conflicts_json}"
echo "  ✓ ${STATE_FILE}"

if [[ -f "${LEGACY_STATE_FILE}" ]]; then
  rm -f "${LEGACY_STATE_FILE}"
fi

echo ""
echo "Scaffold applied."
if [[ ${#ADOPTION_CONFLICT_TARGETS[@]} -gt 0 ]]; then
  echo "Adoption conflicts preserved during this run:"
  for ((i=0; i<${#ADOPTION_CONFLICT_TARGETS[@]}; i++)); do
    echo "  - ${ADOPTION_CONFLICT_TARGETS[$i]} remains active; scaffold candidate: ${ADOPTION_CONFLICT_CANDIDATES[$i]}"
  done
fi
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
if [[ ${#ADOPTION_CONFLICT_TARGETS[@]} -gt 0 ]]; then
  echo "Next step: run /resolve-adopted-artifacts before /bootstrap or another scaffold refresh."
elif [[ -z "${existing_state_file}" ]]; then
  echo "Next step: run /bootstrap in your agent harness to hydrate project-specific values from the codebase."
else
  echo "Scaffold refresh complete."
  echo "Run /bootstrap only if project-specific scaffold values need to be re-hydrated from the codebase."
fi
