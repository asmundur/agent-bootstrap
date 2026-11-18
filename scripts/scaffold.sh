#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$(cd "${SCRIPT_DIR}/../bootstrap-templates/templates/universal" && pwd)"

if [[ ! -d "${TEMPLATE_DIR}" ]]; then
  echo "Error: Cannot find templates at ${TEMPLATE_DIR}"
  exit 1
fi

CHECK_ONLY="false"
if [[ "${1:-}" == "--check" ]]; then
  CHECK_ONLY="true"
  shift
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
TARGET_ROOT="$(pwd -P)"
PLAN_BASE="${TMPDIR:-/tmp}"
if [[ "${TARGET_ROOT}" == "/" ]]; then
  echo "Error: refusing to scaffold the filesystem root." >&2
  exit 1
fi
if ! PLAN_BASE="$(cd "${PLAN_BASE}" 2>/dev/null && pwd -P)"; then
  echo "Error: TMPDIR is not an accessible directory: ${TMPDIR:-/tmp}" >&2
  exit 1
fi
case "${PLAN_BASE}" in
  "${TARGET_ROOT}"|"${TARGET_ROOT}"/*)
    echo "Error: TMPDIR must resolve outside the scaffold target for a zero-write preflight." >&2
    exit 1
    ;;
esac

PLAN_DIR="$(mktemp -d "${PLAN_BASE}/agent-scaffold-plan.XXXXXX")"

cleanup_plan() {
  rm -rf "${PLAN_DIR}"
}
trap cleanup_plan EXIT

if [[ "${CHECK_ONLY}" == "true" ]]; then
  echo "Checking scaffold in $(pwd)..."
else
  echo "Planning scaffold in $(pwd)..."
fi

CAPTURED_INPUT_CHECKSUM=""
CAPTURED_INPUT_MODE=""
capture_regular_input() {
  local source="$1"
  local destination="$2"
  local copied_checksum=""
  local source_checksum_after=""
  local source_mode_after=""

  if [[ ! -f "${source}" || -L "${source}" ]]; then
    echo "Error: scaffold input must remain a regular file while it is captured: ${source}" >&2
    return 1
  fi

  CAPTURED_INPUT_CHECKSUM="$(shasum -a 256 "${source}" | awk '{print $1}')"
  if stat -f '%Lp' "${source}" >/dev/null 2>&1; then
    CAPTURED_INPUT_MODE="$(stat -f '%Lp' "${source}")"
  else
    CAPTURED_INPUT_MODE="$(stat -c '%a' "${source}")"
  fi

  cp "${source}" "${destination}"
  copied_checksum="$(shasum -a 256 "${destination}" | awk '{print $1}')"
  if [[ ! -f "${source}" || -L "${source}" ]]; then
    echo "Error: scaffold input changed type while it was captured: ${source}" >&2
    return 1
  fi
  source_checksum_after="$(shasum -a 256 "${source}" | awk '{print $1}')"
  if stat -f '%Lp' "${source}" >/dev/null 2>&1; then
    source_mode_after="$(stat -f '%Lp' "${source}")"
  else
    source_mode_after="$(stat -c '%a' "${source}")"
  fi

  if [[ "${copied_checksum}" != "${CAPTURED_INPUT_CHECKSUM}" ]] \
  || [[ "${source_checksum_after}" != "${CAPTURED_INPUT_CHECKSUM}" ]] \
  || [[ "${source_mode_after}" != "${CAPTURED_INPUT_MODE}" ]]; then
    echo "Error: scaffold input changed while it was being captured: ${source}" >&2
    return 1
  fi
}

SNAPSHOT_KIND=""
SNAPSHOT_CHECKSUM=""
SNAPSHOT_MODE=""
snapshot_path_metadata() {
  local target="$1"

  SNAPSHOT_KIND="missing"
  SNAPSHOT_CHECKSUM=""
  SNAPSHOT_MODE=""

  if [[ -L "${target}" ]]; then
    SNAPSHOT_KIND="symlink"
    SNAPSHOT_CHECKSUM="$(readlink "${target}" | shasum -a 256 | awk '{print $1}')"
  elif [[ -f "${target}" ]]; then
    SNAPSHOT_KIND="file"
    SNAPSHOT_CHECKSUM="$(shasum -a 256 "${target}" | awk '{print $1}')"
  elif [[ -d "${target}" ]]; then
    SNAPSHOT_KIND="directory"
  elif [[ -e "${target}" ]]; then
    SNAPSHOT_KIND="other"
  fi

  if [[ "${SNAPSHOT_KIND}" != "missing" ]]; then
    if stat -f '%Lp' "${target}" >/dev/null 2>&1; then
      SNAPSHOT_MODE="$(stat -f '%Lp' "${target}")"
    else
      SNAPSHOT_MODE="$(stat -c '%a' "${target}")"
    fi
  fi
}

existing_state_file=""
existing_state_target=""
existing_state_checksum=""
existing_state_mode=""
initial_state_preflight_error=""
snapshot_path_metadata "${STATE_FILE}"
initial_state_kind="${SNAPSHOT_KIND}"
initial_state_checksum="${SNAPSHOT_CHECKSUM}"
initial_state_mode="${SNAPSHOT_MODE}"
snapshot_path_metadata "${LEGACY_STATE_FILE}"
initial_legacy_state_kind="${SNAPSHOT_KIND}"
initial_legacy_state_checksum="${SNAPSHOT_CHECKSUM}"
initial_legacy_state_mode="${SNAPSHOT_MODE}"

if [[ "${initial_state_kind}" == "file" ]]; then
  existing_state_target="${STATE_FILE}"
elif [[ "${initial_state_kind}" == "missing" && "${initial_legacy_state_kind}" == "file" && ! -L ".claude" ]]; then
  existing_state_target="${LEGACY_STATE_FILE}"
fi

if [[ -n "${existing_state_target}" ]]; then
  captured_state_file="${PLAN_DIR}/existing-state.json"
  if ! capture_regular_input "${existing_state_target}" "${captured_state_file}"; then
    exit 1
  fi
  existing_state_checksum="${CAPTURED_INPUT_CHECKSUM}"
  existing_state_mode="${CAPTURED_INPUT_MODE}"
  if [[ "${existing_state_target}" == "${STATE_FILE}" ]] \
  && { [[ "${existing_state_checksum}" != "${initial_state_checksum}" ]] \
    || [[ "${existing_state_mode}" != "${initial_state_mode}" ]]; }; then
    echo "Error: scaffold state changed before it could be captured: ${existing_state_target}" >&2
    exit 1
  fi
  if [[ "${existing_state_target}" == "${LEGACY_STATE_FILE}" ]] \
  && { [[ "${existing_state_checksum}" != "${initial_legacy_state_checksum}" ]] \
    || [[ "${existing_state_mode}" != "${initial_legacy_state_mode}" ]] \
    || [[ -L ".claude" ]]; }; then
    echo "Error: legacy scaffold state changed before it could be captured: ${existing_state_target}" >&2
    exit 1
  fi
  if ! jq empty "${captured_state_file}" >/dev/null 2>&1; then
    initial_state_preflight_error="scaffold state is not valid JSON: ${existing_state_target}"
  elif [[ "$(jq -r '.generatedBy // empty' "${captured_state_file}")" != "agent-bootstrap" ]]; then
    initial_state_preflight_error="scaffold state ownership could not be verified: ${existing_state_target}"
  elif ! jq -e '
    def digest:
      type == "string" and test("^[0-9a-f]{64}$");
    type == "object"
    and (.generatedBy == "agent-bootstrap")
    and (.variables | type == "object")
    and all(.variables | to_entries[]; .value | type == "string")
    and (.files | type == "array")
    and all(.files[];
      type == "object"
      and (.target | type == "string")
      and (.source | type == "string")
      and (.category | type == "string")
      and (.checksum | digest))
    and (([.files[].target] | unique | length) == (.files | length))
    and ((.adoptionConflicts // []) | type == "array")
    and all((.adoptionConflicts // [])[];
      type == "object"
      and (.target | type == "string")
      and ((.scaffoldCandidate // .preservedBackup) | type == "string")
      and (.detectedAt | type == "string")
      and ((.targetChecksum // .originalChecksum) | digest)
      and ((.candidateChecksum // .preservedChecksum) | digest)
      and ((.status // "unresolved") | type == "string"))
  ' "${captured_state_file}" >/dev/null 2>&1; then
    initial_state_preflight_error="scaffold state does not match the required schema: ${existing_state_target}"
  else
    existing_state_file="${captured_state_file}"
  fi
fi

captured_beads_config_file=""
captured_beads_config_checksum=""
captured_beads_config_mode=""
snapshot_path_metadata ".beads/config.yaml"
initial_beads_config_kind="${SNAPSHOT_KIND}"
initial_beads_config_checksum="${SNAPSHOT_CHECKSUM}"
initial_beads_config_mode="${SNAPSHOT_MODE}"
if [[ "${initial_beads_config_kind}" == "file" && ! -L ".beads" ]]; then
  captured_beads_config_file="${PLAN_DIR}/existing-beads-config.yaml"
  if ! capture_regular_input ".beads/config.yaml" "${captured_beads_config_file}"; then
    exit 1
  fi
  if [[ -L ".beads" ]]; then
    echo "Error: scaffold input parent changed to a symlink while it was captured: .beads/config.yaml" >&2
    exit 1
  fi
  captured_beads_config_checksum="${CAPTURED_INPUT_CHECKSUM}"
  captured_beads_config_mode="${CAPTURED_INPUT_MODE}"
  if [[ "${captured_beads_config_checksum}" != "${initial_beads_config_checksum}" ]] \
  || [[ "${captured_beads_config_mode}" != "${initial_beads_config_mode}" ]]; then
    echo "Error: scaffold input changed before it could be captured: .beads/config.yaml" >&2
    exit 1
  fi
fi

captured_clone_contract_file=""
captured_clone_contract_checksum=""
captured_clone_contract_mode=""
snapshot_path_metadata ".beads/clone-contract.json"
initial_clone_contract_kind="${SNAPSHOT_KIND}"
initial_clone_contract_checksum="${SNAPSHOT_CHECKSUM}"
initial_clone_contract_mode="${SNAPSHOT_MODE}"
if [[ "${initial_clone_contract_kind}" == "file" && ! -L ".beads" ]]; then
  captured_clone_contract_file="${PLAN_DIR}/existing-clone-contract.json"
  if ! capture_regular_input ".beads/clone-contract.json" "${captured_clone_contract_file}"; then
    exit 1
  fi
  if [[ -L ".beads" ]]; then
    echo "Error: scaffold input parent changed to a symlink while it was captured: .beads/clone-contract.json" >&2
    exit 1
  fi
  captured_clone_contract_checksum="${CAPTURED_INPUT_CHECKSUM}"
  captured_clone_contract_mode="${CAPTURED_INPUT_MODE}"
  if [[ "${captured_clone_contract_checksum}" != "${initial_clone_contract_checksum}" ]] \
  || [[ "${captured_clone_contract_mode}" != "${initial_clone_contract_mode}" ]]; then
    echo "Error: scaffold input changed before it could be captured: .beads/clone-contract.json" >&2
    exit 1
  fi
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

  if [[ -n "${captured_beads_config_file}" ]]; then
    value="$(awk -F: '
      /^[[:space:]]*issue-prefix[[:space:]]*:/ {
        value = $2
        sub(/^[[:space:]]*/, "", value)
        sub(/[[:space:]]*$/, "", value)
        print value
        exit
      }
    ' "${captured_beads_config_file}")"
    if [[ -n "${value}" ]]; then
      printf '%s\n' "${value}"
      return 0
    fi
  fi

  if [[ -n "${captured_clone_contract_file}" ]]; then
    value="$(jq -r '.issue_prefix // empty' "${captured_clone_contract_file}" 2>/dev/null || true)"
    if [[ -n "${value}" ]]; then
      printf '%s\n' "${value}"
      return 0
    fi
  fi

  printf 'prj\n'
}

inferred_beads_bootstrap_commands_json() {
  local value=""

  if [[ -n "${captured_clone_contract_file}" ]]; then
    value="$(jq -c '(.bootstrap_commands // empty) | select(type == "array" and length > 0)' "${captured_clone_contract_file}" 2>/dev/null || true)"
    if [[ -n "${value}" ]]; then
      printf '%s\n' "${value}"
      return 0
    fi
  fi

  printf '%s\n' '["bd bootstrap --yes --json","git config core.hooksPath .githooks"]'
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
PREFLIGHT_ERRORS=()
OBSERVED_PATHS=()
OBSERVED_KINDS=()
OBSERVED_CHECKSUMS=()
OBSERVED_MODES=()
PLANNED_CONTENTS=()
PLANNED_DESTINATIONS=()
PLANNED_EXECUTABLES=()
PLANNED_DESCRIPTIONS=()
PLANNED_REMOVALS=()
STATE_PLAN_PATH=""
EXISTING_STATE_PATHS_VALID="true"

OBSERVED_PATHS+=("${STATE_FILE}")
OBSERVED_KINDS+=("${initial_state_kind}")
OBSERVED_CHECKSUMS+=("${initial_state_checksum}")
OBSERVED_MODES+=("${initial_state_mode}")
OBSERVED_PATHS+=("${LEGACY_STATE_FILE}")
OBSERVED_KINDS+=("${initial_legacy_state_kind}")
OBSERVED_CHECKSUMS+=("${initial_legacy_state_checksum}")
OBSERVED_MODES+=("${initial_legacy_state_mode}")
if [[ -n "${initial_state_preflight_error}" ]]; then
  PREFLIGHT_ERRORS+=("${initial_state_preflight_error}")
fi
OBSERVED_PATHS+=(".beads/config.yaml")
OBSERVED_KINDS+=("${initial_beads_config_kind}")
OBSERVED_CHECKSUMS+=("${initial_beads_config_checksum}")
OBSERVED_MODES+=("${initial_beads_config_mode}")
OBSERVED_PATHS+=(".beads/clone-contract.json")
OBSERVED_KINDS+=("${initial_clone_contract_kind}")
OBSERVED_CHECKSUMS+=("${initial_clone_contract_checksum}")
OBSERVED_MODES+=("${initial_clone_contract_mode}")

record_preflight_error() {
  PREFLIGHT_ERRORS+=("$1")
}

is_safe_checkout_relative_path() {
  local target="$1"

  case "${target}" in
    ""|-*|/*|"."|".."|../*|*/../*|*/..|./*|*/./*|*/.|*//*|*$'\n'*|*$'\r'*|*$'\t'*)
      return 1
      ;;
  esac

  return 0
}

validate_existing_state_paths() {
  if [[ -z "${existing_state_file}" || "${EXISTING_STATE_PATHS_VALID}" != "true" ]]; then
    return 0
  fi

  if jq -e '
    def safe_path:
      type == "string"
      and length > 0
      and (startswith("-") | not)
      and (startswith("/") | not)
      and (contains("//") | not)
      and (test("(^|/)\\.\\.?(/|$)") | not)
      and (test("[\u0000-\u001F\u007F]") | not);
    (.files | type == "array")
    and all(.files[];
      type == "object"
      and (.target | safe_path)
      and ((.source // "") as $source
        | ($source == "" or ($source | safe_path))))
    and ((.adoptionConflicts // []) | type == "array")
    and all((.adoptionConflicts // [])[];
      type == "object"
      and (.target | safe_path)
      and ((.scaffoldCandidate // .preservedBackup // "") | safe_path))
  ' "${existing_state_file}" >/dev/null 2>&1; then
    return 0
  fi

  EXISTING_STATE_PATHS_VALID="false"
  record_preflight_error "scaffold state contains an invalid, unsafe, or non-checkout-relative managed path"
}

path_has_symlink_parent() {
  local target="$1"
  local parent=""
  local component=""
  local partial=""
  local -a components=()

  parent="$(dirname "${target}")"
  IFS='/' read -r -a components <<< "${parent}"
  for component in "${components[@]}"; do
    [[ -z "${component}" || "${component}" == "." ]] && continue
    partial="${partial:+${partial}/}${component}"
    if [[ -L "${partial}" ]]; then
      return 0
    fi
  done

  return 1
}

file_mode() {
  local target="$1"

  if stat -f '%Lp' "${target}" >/dev/null 2>&1; then
    stat -f '%Lp' "${target}"
  else
    stat -c '%a' "${target}"
  fi
}

symlink_checksum() {
  local target="$1"

  readlink "${target}" | shasum -a 256 | awk '{print $1}'
}

observe_path() {
  local target="$1"
  local kind="missing"
  local checksum=""
  local mode=""

  if [[ -L "${target}" ]]; then
    kind="symlink"
    checksum="$(symlink_checksum "${target}")"
    mode="$(file_mode "${target}")"
  elif [[ -f "${target}" ]]; then
    kind="file"
    checksum="$(file_checksum "${target}")"
    mode="$(file_mode "${target}")"
  elif [[ -d "${target}" ]]; then
    kind="directory"
    mode="$(file_mode "${target}")"
  elif [[ -e "${target}" ]]; then
    kind="other"
    mode="$(file_mode "${target}")"
  fi

  OBSERVED_PATHS+=("${target}")
  OBSERVED_KINDS+=("${kind}")
  OBSERVED_CHECKSUMS+=("${checksum}")
  OBSERVED_MODES+=("${mode}")
  LAST_OBSERVED_KIND="${kind}"
  LAST_OBSERVED_CHECKSUM="${checksum}"
  LAST_OBSERVED_MODE="${mode}"
}

plan_content_write() {
  local tmp="$1"
  local destination="$2"
  local executable="$3"
  local description="$4"
  local planned="${PLAN_DIR}/content-${#PLANNED_CONTENTS[@]}"

  mv "${tmp}" "${planned}"
  PLANNED_CONTENTS+=("${planned}")
  PLANNED_DESTINATIONS+=("${destination}")
  PLANNED_EXECUTABLES+=("${executable}")
  PLANNED_DESCRIPTIONS+=("${description}")
}

plan_removal() {
  PLANNED_REMOVALS+=("$1")
}

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

  if [[ -z "${existing_state_file}" || "${EXISTING_STATE_PATHS_VALID}" != "true" ]]; then
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
        record_preflight_error "scaffold variable ${name} has conflicting adopted values while reading ${target}; refusing to guess which value should win"
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

  values_file="$(mktemp "${PLAN_DIR}/scaffold-agents-values.XXXXXX")"
  normalized_file="$(mktemp "${PLAN_DIR}/scaffold-agents-normalized.XXXXXX")"
  agents_value_snapshot "${target}" "${values_file}" "${normalized_file}"
  normalized_checksum="$(file_checksum "${normalized_file}")"

  if [[ "${normalized_checksum}" == "${expected_checksum}" ]]; then
    record_adopted_values_from_file "${values_file}" "${target}"
    mark_value_drift_safe "${target}"
    rm -f "${values_file}" "${normalized_file}"
    return 0
  fi

  rm -f "${values_file}" "${normalized_file}"

  values_file="$(mktemp "${PLAN_DIR}/scaffold-agents-values.XXXXXX")"
  normalized_file="$(mktemp "${PLAN_DIR}/scaffold-agents-normalized.XXXXXX")"
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

  values_file="$(mktemp "${PLAN_DIR}/scaffold-template-values.XXXXXX")"
  normalized_file="$(mktemp "${PLAN_DIR}/scaffold-template-normalized.XXXXXX")"

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

  if [[ -z "${existing_state_file}" || "${EXISTING_STATE_PATHS_VALID}" != "true" ]]; then
    return 0
  fi

  while IFS=$'\t' read -r target source expected_checksum; do
    [[ -z "${target}" || -z "${expected_checksum}" ]] && continue
    if ! is_safe_checkout_relative_path "${target}"; then
      record_preflight_error "scaffold state contains an unsafe managed target: ${target}"
      continue
    fi
    if [[ -n "${source}" ]] && ! is_safe_checkout_relative_path "${source}"; then
      record_preflight_error "scaffold state contains an unsafe template source for ${target}: ${source}"
      continue
    fi
    if [[ -L "${target}" ]] || path_has_symlink_parent "${target}"; then
      record_preflight_error "scaffold-managed value source must not be a symlink or use a symlinked parent: ${target}"
      continue
    fi
    [[ -f "${target}" ]] || continue

    observe_path "${target}"
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

  if [[ ! -e "${target}" && ! -L "${target}" ]]; then
    return 0
  fi

  observe_path "${target}"
  preflight_destination_parent "${target}"
  if [[ ! -f "${target}" || -L "${target}" ]]; then
    record_preflight_error "obsolete scaffold target is not a regular file: ${target}"
    return 1
  fi

  expected_checksum="$(state_file_checksum "${target}")"
  if [[ -z "${expected_checksum}" ]]; then
    record_preflight_error "no scaffold checksum is recorded for obsolete file ${target}; refusing to remove it"
    return 1
  fi

  current_checksum="$(file_checksum "${target}")"
  if [[ "${current_checksum}" != "${expected_checksum}" ]]; then
    record_preflight_error "obsolete scaffold-managed file has local edits: ${target}. Refusing to remove drifted scaffold-managed files."
    return 1
  fi

  return 0
}

has_unresolved_adoption_conflicts() {
  if [[ -z "${existing_state_file}" ]]; then
    return 1
  fi

  jq -e '.adoptionConflicts | length > 0' "${existing_state_file}" >/dev/null 2>&1
}

verify_existing_adoption_conflicts() {
  local target=""
  local artifact=""
  local target_checksum=""
  local artifact_checksum=""
  local mode=""

  if [[ "${EXISTING_STATE_PATHS_VALID}" != "true" ]] \
  || ! has_unresolved_adoption_conflicts; then
    return 0
  fi

  while IFS=$'\t' read -r target artifact target_checksum artifact_checksum mode; do
    [[ -z "${target}" ]] && continue

    if ! is_safe_checkout_relative_path "${target}" \
    || ! is_safe_checkout_relative_path "${artifact}"; then
      record_preflight_error "adoption conflict contains an unsafe checkout-relative path: ${target} -> ${artifact}"
      continue
    fi
    if [[ -L "${target}" || -L "${artifact}" ]] \
    || path_has_symlink_parent "${target}" \
    || path_has_symlink_parent "${artifact}"; then
      record_preflight_error "adoption conflict paths must not be symlinks or use symlinked parents: ${target} -> ${artifact}"
      continue
    fi

    if [[ "${mode}" == "candidate" ]]; then
      if [[ ! -f "${target}" ]]; then
        record_preflight_error "active adoption-conflict target is missing: ${target}"
      else
        observe_path "${target}"
        if [[ "$(file_checksum "${target}")" != "${target_checksum}" ]]; then
          record_preflight_error "active adoption-conflict target changed since capture: ${target}"
        fi
      fi
    fi

    if [[ ! -f "${artifact}" ]]; then
      if [[ "${mode}" == "candidate" ]]; then
        record_preflight_error "scaffold adoption-conflict candidate is missing: ${artifact} (target ${target})"
      else
        record_preflight_error "preserved adoption-conflict backup is missing: ${artifact} (target ${target})"
      fi
    else
      observe_path "${artifact}"
      if [[ "$(file_checksum "${artifact}")" != "${artifact_checksum}" ]]; then
        if [[ "${mode}" == "candidate" ]]; then
          record_preflight_error "scaffold adoption-conflict candidate changed since capture: ${artifact} (target ${target})"
        else
          record_preflight_error "preserved adoption-conflict backup changed since capture: ${artifact} (target ${target})"
        fi
      fi
    fi
  done < <(jq -r '.adoptionConflicts[]? | [
    .target,
    (.scaffoldCandidate // .preservedBackup // ""),
    (.targetChecksum // .originalChecksum // ""),
    (.candidateChecksum // .preservedChecksum // ""),
    (if has("scaffoldCandidate") then "candidate" else "backup" end)
  ] | @tsv' "${existing_state_file}")

  record_preflight_error "scaffold has unresolved adoption conflicts; run /resolve-adopted-artifacts before refreshing"
}

validate_rendered_content() {
  local tmp="$1"
  local destination="$2"

  if [[ "${destination}" == *.json ]] && ! jq empty "${tmp}" >/dev/null 2>&1; then
    record_preflight_error "generated JSON is invalid: ${destination}"
  fi

  if [[ "${destination}" == .githooks/* || "${destination}" == *.sh ]]; then
    if ! bash -n "${tmp}" >/dev/null 2>&1; then
      record_preflight_error "generated shell is invalid: ${destination}"
    fi
  fi
}

preflight_destination_parent() {
  local destination="$1"
  local parent=""
  local previous=""

  parent="$(dirname "${destination}")"

  if ! is_safe_checkout_relative_path "${destination}"; then
    record_preflight_error "destination is not a safe checkout-relative path: ${destination}"
    return 0
  fi
  if path_has_symlink_parent "${destination}"; then
    record_preflight_error "destination parent contains a symlink: ${destination}"
    return 0
  fi

  while [[ ! -e "${parent}" ]]; do
    previous="${parent}"
    parent="$(dirname "${parent}")"
    if [[ "${parent}" == "${previous}" ]]; then
      break
    fi
  done

  if [[ ! -d "${parent}" ]]; then
    record_preflight_error "destination parent is not a directory for ${destination}: ${parent}"
  elif [[ ! -w "${parent}" ]]; then
    record_preflight_error "destination parent is not writable for ${destination}: ${parent}"
  elif [[ ! -x "${parent}" ]]; then
    record_preflight_error "destination parent is not searchable for ${destination}: ${parent}"
  fi
}

preflight_state_destination() {
  if [[ ! -e "${STATE_FILE}" && ! -L "${STATE_FILE}" ]]; then
    return 0
  fi

  if [[ -L "${STATE_FILE}" || ! -f "${STATE_FILE}" ]]; then
    record_preflight_error "scaffold state destination must be missing or a regular file: ${STATE_FILE}"
  fi
}

record_managed_migration_blockers() {
  local destination="$1"
  local tmp="$2"
  local expected_checksum="$3"
  local current_checksum="$4"

  if [[ "${current_checksum}" != "${expected_checksum}" ]]; then
    return 0
  fi

  if [[ "${destination}" == ".githooks/pre-commit" ]] \
  && grep -Fq "# Preserved from pre-existing .githooks/pre-commit during scaffold adoption." "${destination}"; then
    record_preflight_error "legacy managed combined hook requires explicit resolution: classify .githooks/pre-commit behavior into .githooks/pre-commit.validate or .githooks/prepare-commit.local"
  fi

  if [[ "${destination}" == ".beads/clone-contract.json" ]] \
  && [[ "$(jq -r '.jsonl_export // empty' "${destination}" 2>/dev/null || true)" == "issues.jsonl" ]] \
  && [[ "$(jq -r '.jsonl_export // empty' "${tmp}" 2>/dev/null || true)" == ".beads/issues.jsonl" ]]; then
    record_preflight_error ".beads/clone-contract.json requires explicit jsonl_export migration from issues.jsonl to .beads/issues.jsonl"
  fi
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

  if [[ "${make_executable}" == "true" ]]; then
    chmod 0755 "${tmp}"
  else
    chmod 0644 "${tmp}"
  fi
  validate_rendered_content "${tmp}" "${dst}"
  preflight_destination_parent "${dst}"
  checksum="$(file_checksum "${tmp}")"

  observe_path "${dst}"
  if [[ "${LAST_OBSERVED_KIND}" != "missing" ]]; then
    if [[ "${LAST_OBSERVED_KIND}" != "file" ]]; then
      record_preflight_error "scaffold target is not a regular file: ${dst}"
      rm -f "${tmp}"
      record_generated "${dst}" "${src}" "${category}" "${checksum}"
      return 0
    fi

    expected_checksum="$(state_file_checksum "${dst}")"
    if [[ -z "${expected_checksum}" ]]; then
      candidate="$(scaffold_candidate_path "${dst}")"
      preflight_destination_parent "${candidate}"
      observe_path "${candidate}"
      if [[ "${LAST_OBSERVED_KIND}" != "missing" ]]; then
        record_preflight_error "scaffold candidate path already exists: ${candidate}"
        rm -f "${tmp}"
      else
        target_checksum="$(file_checksum "${dst}")"
        record_adoption_conflict "${dst}" "${candidate}" "${BOOTSTRAP_DATE}" "${target_checksum}" "${checksum}"
        plan_content_write "${tmp}" "${candidate}" "${make_executable}" "keep ${dst}; create scaffold candidate ${candidate}"
      fi

      record_generated "${dst}" "${src}" "${category}" "${checksum}"
      return 0
    fi

    current_checksum="$(file_checksum "${dst}")"
    record_managed_migration_blockers "${dst}" "${tmp}" "${expected_checksum}" "${current_checksum}"
    if [[ "${current_checksum}" != "${expected_checksum}" ]]; then
      if cmp -s "${dst}" "${tmp}"; then
        :
      elif is_value_drift_safe "${dst}"; then
        :
      else
        record_preflight_error "scaffold-managed file has local edits: ${dst}. Refusing to overwrite drifted scaffold-managed files."
      fi
    fi
  fi

  plan_content_write "${tmp}" "${dst}" "${make_executable}" "write ${dst}"
  record_generated "${dst}" "${src}" "${category}" "${checksum}"
}

mark_obsolete_targets() {
  local target=""
  local found="false"

  if [[ -z "${existing_state_file}" || "${EXISTING_STATE_PATHS_VALID}" != "true" ]]; then
    return 0
  fi

  while IFS= read -r target; do
    [[ -z "${target}" ]] && continue
    if ! is_safe_checkout_relative_path "${target}"; then
      record_preflight_error "scaffold state contains an unsafe obsolete target: ${target}"
      continue
    fi
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

preflight_unique_plan_targets() {
  local i=0
  local j=0

  for ((i=0; i<${#GENERATED_TARGETS[@]}; i++)); do
    for ((j=i+1; j<${#GENERATED_TARGETS[@]}; j++)); do
      if [[ "${GENERATED_TARGETS[$i]}" == "${GENERATED_TARGETS[$j]}" ]]; then
        record_preflight_error "generated target appears more than once in the render plan: ${GENERATED_TARGETS[$i]}"
      fi
    done
  done

  for ((i=0; i<${#PLANNED_DESTINATIONS[@]}; i++)); do
    for ((j=i+1; j<${#PLANNED_DESTINATIONS[@]}; j++)); do
      if [[ "${PLANNED_DESTINATIONS[$i]}" == "${PLANNED_DESTINATIONS[$j]}" ]]; then
        record_preflight_error "destination appears more than once in the apply plan: ${PLANNED_DESTINATIONS[$i]}"
      fi
    done
  done
}

prune_obsolete_targets() {
  local target=""

  if [[ ${#OBSOLETE_TARGETS[@]} -eq 0 ]]; then
    return 0
  fi

  for target in "${OBSOLETE_TARGETS[@]}"; do
    observe_path "${target}"
    [[ "${LAST_OBSERVED_KIND}" == "missing" ]] && continue
    if ensure_safe_to_replace "${target}"; then
      plan_removal "${target}"
    fi
  done
}

generic_required_scaffold_values() {
  local joined=""

  [[ "${PROJECT_NAME}" == "__PROJECT_NAME__" ]] && joined="${joined}${joined:+, }PROJECT_NAME"
  [[ "${PROJECT_DESCRIPTION}" == "Project description pending /bootstrap." ]] && joined="${joined}${joined:+, }PROJECT_DESCRIPTION"
  [[ "${TECH_STACK}" == "Unknown" ]] && joined="${joined}${joined:+, }TECH_STACK"
  [[ "${MAIN_LANGUAGE}" == "Unknown" ]] && joined="${joined}${joined:+, }MAIN_LANGUAGE"
  [[ "${SOURCE_DIR}" == "not configured" ]] && joined="${joined}${joined:+, }SOURCE_DIR"
  [[ "${ARCHITECTURE_PATTERN}" == "not configured" ]] && joined="${joined}${joined:+, }ARCHITECTURE_PATTERN"

  printf '%s\n' "${joined}"
}

copy_template() {
  local src="$1"
  local dst="$2"
  local category="${3:-config}"
  local tmp=""
  tmp="$(mktemp "${PLAN_DIR}/scaffold-template.XXXXXX")"
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
  tmp="$(mktemp "${PLAN_DIR}/scaffold-hook.XXXXXX")"
  cp "${TEMPLATE_DIR}/${src}" "${tmp}"
  write_from_tmp "${tmp}" "${dst}" "${src}" "${category}" "true"
}

copy_raw() {
  local src="$1"
  local dst="$2"
  local category="${3:-config}"
  local tmp=""
  tmp="$(mktemp "${PLAN_DIR}/scaffold-raw.XXXXXX")"
  cp "${TEMPLATE_DIR}/${src}" "${tmp}"
  write_from_tmp "${tmp}" "${dst}" "${src}" "${category}"
}

copy_beads_clone_contract() {
  local tmp=""
  tmp="$(mktemp "${PLAN_DIR}/scaffold-clone-contract.XXXXXX")"
  if ! jq \
    --arg issue_prefix "${BEADS_PREFIX}" \
    --argjson bootstrap_commands "${BEADS_BOOTSTRAP_COMMANDS_JSON}" \
    '.issue_prefix = $issue_prefix
    | .bootstrap_commands = $bootstrap_commands' \
    "${TEMPLATE_DIR}/beads/clone-contract.json.tmpl" > "${tmp}"; then
    record_preflight_error "could not render generated JSON: .beads/clone-contract.json"
  fi
  write_from_tmp "${tmp}" ".beads/clone-contract.json" "beads/clone-contract.json.tmpl" "beads"
}

merge_agents_local_safety_constraints() {
  local tmp="$1"
  local existing="$2"
  local section=""
  local rendered=""

  if [[ ! -f "${existing}" ]]; then
    return 0
  fi
  if [[ -L "${existing}" ]] || path_has_symlink_parent "${existing}"; then
    record_preflight_error "AGENTS.md safety section source must not be a symlink or use a symlinked parent: ${existing}"
    return 0
  fi
  observe_path "${existing}"

  section="$(mktemp "${PLAN_DIR}/scaffold-agents-safety.XXXXXX")"
  rendered="$(mktemp "${PLAN_DIR}/scaffold-agents-rendered.XXXXXX")"

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

preflight_project_hook_extensions() {
  local extension=""

  observe_path ".githooks/pre-commit.local"
  if [[ "${LAST_OBSERVED_KIND}" != "missing" ]]; then
    record_preflight_error "legacy .githooks/pre-commit.local must be classified as pre-commit.validate or prepare-commit.local"
  fi

  for extension in ".githooks/pre-commit.validate" ".githooks/prepare-commit.local"; do
    observe_path "${extension}"
    if [[ "${LAST_OBSERVED_KIND}" != "missing" ]]; then
      if [[ "${LAST_OBSERVED_KIND}" != "file" ]]; then
        record_preflight_error "project hook extension is not a regular file: ${extension}"
      elif [[ ! -x "${extension}" ]]; then
        record_preflight_error "project hook extension must be executable: ${extension}"
      fi
    fi
  done
}

report_preflight_errors() {
  local error=""

  if [[ ${#PREFLIGHT_ERRORS[@]} -eq 0 ]]; then
    return 0
  fi

  echo "Scaffold preflight failed with ${#PREFLIGHT_ERRORS[@]} blocker(s):" >&2
  for error in "${PREFLIGHT_ERRORS[@]}"; do
    echo "  - ${error}" >&2
  done
  return 1
}

recheck_observed_paths() {
  local i=0
  local target=""
  local actual_checksum=""
  local actual_mode=""

  for ((i=0; i<${#OBSERVED_PATHS[@]}; i++)); do
    target="${OBSERVED_PATHS[$i]}"
    if [[ "${OBSERVED_KINDS[$i]}" == "missing" ]]; then
      if [[ -e "${target}" || -L "${target}" ]]; then
        record_preflight_error "target changed after preflight (expected missing): ${target}"
      fi
      continue
    fi

    if [[ ! -e "${target}" && ! -L "${target}" ]]; then
      record_preflight_error "target changed after preflight (now missing): ${target}"
      continue
    fi

    case "${OBSERVED_KINDS[$i]}" in
      file)
        if [[ ! -f "${target}" || -L "${target}" ]]; then
          record_preflight_error "target changed type after preflight: ${target}"
          continue
        fi
        actual_checksum="$(file_checksum "${target}")"
        ;;
      symlink)
        if [[ ! -L "${target}" ]]; then
          record_preflight_error "target changed type after preflight: ${target}"
          continue
        fi
        actual_checksum="$(symlink_checksum "${target}")"
        ;;
      directory)
        if [[ ! -d "${target}" || -L "${target}" ]]; then
          record_preflight_error "target changed type after preflight: ${target}"
          continue
        fi
        actual_checksum=""
        ;;
      *)
        if [[ -f "${target}" || -d "${target}" || -L "${target}" ]]; then
          record_preflight_error "target changed type after preflight: ${target}"
          continue
        fi
        actual_checksum=""
        ;;
    esac
    actual_mode="$(file_mode "${target}")"
    if [[ "${actual_checksum}" != "${OBSERVED_CHECKSUMS[$i]}" ]] \
    || [[ "${actual_mode}" != "${OBSERVED_MODES[$i]}" ]]; then
      record_preflight_error "target changed after preflight: ${target}"
    fi
  done
}

recheck_plan_destinations() {
  local destination=""

  if [[ ${#PLANNED_DESTINATIONS[@]} -gt 0 ]]; then
    for destination in "${PLANNED_DESTINATIONS[@]}"; do
      preflight_destination_parent "${destination}"
    done
  fi
  if [[ ${#PLANNED_REMOVALS[@]} -gt 0 ]]; then
    for destination in "${PLANNED_REMOVALS[@]}"; do
      preflight_destination_parent "${destination}"
    done
  fi
  preflight_destination_parent "${STATE_FILE}"
}

print_planned_actions() {
  local i=0

  for ((i=0; i<${#PLANNED_DESCRIPTIONS[@]}; i++)); do
    echo "  - ${PLANNED_DESCRIPTIONS[$i]}"
  done
  for ((i=0; i<${#PLANNED_REMOVALS[@]}; i++)); do
    echo "  - remove ${PLANNED_REMOVALS[$i]}"
  done
  echo "  - write ${STATE_FILE} last"
}

install_planned_file() {
  local source="$1"
  local destination="$2"
  local executable="$3"
  local parent=""
  local install_tmp=""

  if ! is_safe_checkout_relative_path "${destination}" \
  || path_has_symlink_parent "${destination}"; then
    echo "Error: planned destination became unsafe during apply: ${destination}" >&2
    return 1
  fi
  if [[ -L "${destination}" ]] \
  || { [[ -e "${destination}" ]] && [[ ! -f "${destination}" ]]; }; then
    echo "Error: planned destination is no longer a regular file or missing: ${destination}" >&2
    return 1
  fi

  parent="$(dirname "${destination}")"
  mkdir -p "${parent}"
  install_tmp="$(mktemp "${parent}/.agent-scaffold-install.XXXXXX")"
  cp "${source}" "${install_tmp}"
  if [[ "${executable}" == "true" ]]; then
    chmod 0755 "${install_tmp}"
  else
    chmod 0644 "${install_tmp}"
  fi
  mv "${install_tmp}" "${destination}"
}

apply_planned_changes() {
  local i=0

  for ((i=0; i<${#PLANNED_CONTENTS[@]}; i++)); do
    install_planned_file \
      "${PLANNED_CONTENTS[$i]}" \
      "${PLANNED_DESTINATIONS[$i]}" \
      "${PLANNED_EXECUTABLES[$i]}"
    echo "  ✓ ${PLANNED_DESCRIPTIONS[$i]}"
  done

  for ((i=0; i<${#PLANNED_REMOVALS[@]}; i++)); do
    rm -f -- "${PLANNED_REMOVALS[$i]}"
    echo "  ✓ removed ${PLANNED_REMOVALS[$i]}"
  done

  install_planned_file "${STATE_PLAN_PATH}" "${STATE_FILE}" "false"
  echo "  ✓ ${STATE_FILE}"
}

run_post_apply_operations() {
  BEADS_BOOTSTRAP_STATUS="not_attempted"

  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git config core.hooksPath .githooks >/dev/null 2>&1 || true
  fi

  if command -v bd >/dev/null 2>&1; then
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      if bd status --json >/dev/null 2>&1 \
      || (bd bootstrap --yes --json >/dev/null 2>&1 && bd status --json >/dev/null 2>&1); then
        BEADS_BOOTSTRAP_STATUS="ok"
      else
        BEADS_BOOTSTRAP_STATUS="failed"
      fi
    else
      BEADS_BOOTSTRAP_STATUS="deferred"
    fi
  fi
}

validate_existing_state_paths
verify_existing_adoption_conflicts
adopt_scaffold_value_drift
preflight_project_hook_extensions

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
copy_hook "githooks/prepare-commit" ".githooks/prepare-commit" "hook"
copy_hook "githooks/pre-commit" ".githooks/pre-commit" "hook"

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
    P_OVERVIEW_SECTION="\n## Project Overview\n\n${P_PROJECT_DESCRIPTION}\n\n- **Tech Stack:** ${P_TECH_STACK}\n- **Language:** ${P_MAIN_LANGUAGE}\n- **Source Directory:** ${P_SOURCE_DIR}\n- **Architecture:** ${P_ARCHITECTURE_PATTERN}\n\n## Essential Commands\n\n\`\`\`bash\n# Build\n${P_BUILD_COMMAND}\n\n# Typecheck (optional)\n${P_TYPECHECK_COMMAND}\n\n# Lint (optional)\n${P_LINT_COMMAND}\n\n# Browser verification (optional)\n${P_BROWSER_VERIFY_COMMAND}\n\n# Test\n${P_TEST_COMMAND}\n\n# Run\n${P_RUN_COMMAND}\n\`\`\`\n\n## Architecture & Key Patterns\n\n${P_ARCHITECTURE_PATTERN}\n\nRun \`/bootstrap\` after first scaffold adoption, or when these values need to be re-hydrated from the existing codebase.\n\n## Durable Artifacts\n\n- **Feature specs:** \`.agents/plans/<feature-slug>.md\`\n- **Ubiquitous language:** \`.agents/context/ubiquitous-language.md\`\n- **Module map:** \`.agents/architecture/module-map.md\`\n\nThese provider-neutral files are created or refreshed by the generated skills.\n\n## Code Style Guidelines\n\n- Match the style of surrounding code\n- Functions should do one thing\n- Name things for what they are, not how they're implemented\n- Validate at system boundaries (user input, external APIs) — trust internal code\n- No dead code, no commented-out blocks, no TODO left behind after a feature\n- Tests are not optional\n\n## Task Tracking — Beads\n\nThis project uses [beads](https://github.com/steveyegge/beads) (\`bd\`) for task tracking. Issue prefix: \`${P_BEADS_PREFIX}\`.\n\nBefore starting new work:\n    bd ready --json\n    bd update <id> --claim --json\n\nCreating a task:\n    bd create --title \"...\" -p 2 --json\n\nClosing a task:\n    bd close <id> --reason \"done\" --json\n\n\`.beads/issues.jsonl\` is the git-tracked issue-only snapshot. Before final staged review, run \`.githooks/prepare-commit\` to refresh it with the export syntax supported by the installed Beads version, then stage the approved snapshot explicitly. The pre-commit hook validates freshness and index stability only; it must not modify or stage files. Do not edit \`.beads/issues.jsonl\` by hand. Do not bypass the hook (\`--no-verify\`).\n"
  fi

  tmp_claude="$(mktemp "${PLAN_DIR}/scaffold-claude.XXXXXX")"
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

preflight_unique_plan_targets
mark_obsolete_targets
prune_obsolete_targets

state_files_json="$(mktemp "${PLAN_DIR}/scaffold-state-files.XXXXXX")"
state_conflicts_json="$(mktemp "${PLAN_DIR}/scaffold-state-conflicts.XXXXXX")"
state_tmp="$(mktemp "${PLAN_DIR}/scaffold-state.XXXXXX")"
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
    templateVersion: "1.3.0",
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

if ! jq empty "${state_tmp}" >/dev/null 2>&1; then
  record_preflight_error "generated scaffold state is invalid JSON"
fi
preflight_state_destination
preflight_destination_parent "${STATE_FILE}"
observe_path "${STATE_FILE}"
STATE_PLAN_PATH="${PLAN_DIR}/state.json"
mv "${state_tmp}" "${STATE_PLAN_PATH}"
rm -f "${state_files_json}" "${state_conflicts_json}"

if [[ -e "${LEGACY_STATE_FILE}" || -L "${LEGACY_STATE_FILE}" ]]; then
  observe_path "${LEGACY_STATE_FILE}"
  preflight_destination_parent "${LEGACY_STATE_FILE}"
  if [[ "${existing_state_target}" != "${LEGACY_STATE_FILE}" ]]; then
    record_preflight_error "legacy scaffold state exists alongside ${STATE_FILE}; refusing unverified removal: ${LEGACY_STATE_FILE}"
  elif [[ ! -f "${LEGACY_STATE_FILE}" || -L "${LEGACY_STATE_FILE}" ]]; then
    record_preflight_error "legacy scaffold state is not a regular file: ${LEGACY_STATE_FILE}"
  elif [[ -z "${existing_state_file}" ]] || ! jq -e '
    .generatedBy == "agent-bootstrap"
    and (.files | type == "array")
  ' "${existing_state_file}" >/dev/null 2>&1; then
    record_preflight_error "legacy scaffold state ownership could not be verified: ${LEGACY_STATE_FILE}"
  else
    plan_removal "${LEGACY_STATE_FILE}"
  fi
fi

if ! report_preflight_errors; then
  exit 1
fi

recheck_observed_paths
recheck_plan_destinations
if ! report_preflight_errors; then
  exit 1
fi

if [[ "${CHECK_ONLY}" == "true" ]]; then
  print_planned_actions
  echo "Scaffold check passed."
  exit 0
fi

echo "Applying scaffold..."
apply_planned_changes
run_post_apply_operations

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
  generic_values="$(generic_required_scaffold_values)"
  echo "Scaffold refresh complete."
  if [[ -n "${generic_values}" ]]; then
    echo "Project-specific scaffold values still look generic: ${generic_values}."
    echo "Next step: run /bootstrap in your agent harness to hydrate those values from the codebase."
  else
    echo "/bootstrap is not needed for this refresh."
  fi
fi
