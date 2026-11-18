#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
beads_snapshot_relative=".beads/issues.jsonl"
beads_snapshot_path="${repo_root}/${beads_snapshot_relative}"

main_git_index_path() {
  env -u GIT_INDEX_FILE git -C "${repo_root}" rev-parse --git-path index
}

absolute_git_path() {
  local path="$1"
  local parent=""

  if [[ "${path}" != /* ]]; then
    path="${repo_root}/${path}"
  fi

  parent="$(cd "$(dirname "${path}")" && pwd -P)"
  printf '%s/%s\n' "${parent}" "$(basename "${path}")"
}

uses_alternate_git_index() {
  local main_index=""
  local current_index=""

  main_index="$(absolute_git_path "$(main_git_index_path)")"
  current_index="$(absolute_git_path "${GIT_INDEX_FILE:-$(main_git_index_path)}")"
  [[ "${current_index}" != "${main_index}" ]]
}

require_main_git_index() {
  local operation="$1"

  if ! uses_alternate_git_index; then
    return 0
  fi

  echo >&2 "${operation}: alternate Git index detected; refusing to continue."
  echo >&2 "${operation}: commit without pathspecs, --only, --include, or -a so the reviewed main index remains authoritative."
  echo >&2 "${operation}: stage approved sources in the main index, run .githooks/prepare-commit, stage approved generated files, review 'git diff --cached', then run plain 'git commit'."
  return 1
}

git_index_tree() {
  local tree=""

  if ! tree="$(git -C "${repo_root}" write-tree)"; then
    echo >&2 "hooks: unable to capture the staged Git tree."
    echo >&2 "hooks: resolve any unmerged index entries before preparing or validating a commit."
    return 1
  fi

  printf '%s\n' "${tree}"
}

assert_git_index_tree_unchanged() {
  local expected_tree="$1"
  local actor="$2"
  local current_tree=""

  current_tree="$(git_index_tree)"
  if [[ "${current_tree}" == "${expected_tree}" ]]; then
    return 0
  fi

  echo >&2 "hooks: ${actor} modified the Git index; refusing to continue."
  echo >&2 "hooks: this phase must not stage, unstage, or otherwise alter the reviewed file set."
  echo >&2 "hooks: restore the approved staged sources, rerun .githooks/prepare-commit, then stage approved generated files and review the exact diff before committing."
  return 1
}

has_beads_repository() {
  [[ -d "${repo_root}/.beads" && ! -L "${repo_root}/.beads" ]]
}

has_beads_path() {
  [[ -e "${repo_root}/.beads" || -L "${repo_root}/.beads" ]]
}

require_safe_beads_paths() {
  local operation="$1"
  local beads_dir="${repo_root}/.beads"

  if [[ -L "${beads_dir}" || ! -d "${beads_dir}" ]]; then
    echo >&2 "${operation}: .beads must be a real directory inside the repository."
    echo >&2 "${operation}: replace the symlink or non-directory path before retrying."
    return 1
  fi
  if [[ -L "${beads_snapshot_path}" ]] \
  || { [[ -e "${beads_snapshot_path}" ]] && [[ ! -f "${beads_snapshot_path}" ]]; }; then
    echo >&2 "${operation}: ${beads_snapshot_relative} must be missing or a regular non-symlink file inside the repository."
    echo >&2 "${operation}: replace the unsafe path before retrying."
    return 1
  fi
}

require_beads_cli() {
  if command -v bd >/dev/null 2>&1; then
    return 0
  fi

  echo >&2 "beads: the 'bd' command is required to prepare or validate ${beads_snapshot_relative}."
  echo >&2 "beads: install Beads and bootstrap this checkout before retrying."
  return 1
}

require_executable_hook_extension() {
  local extension_path="$1"
  local dispatcher_name="$2"

  if [[ ! -e "${extension_path}" && ! -L "${extension_path}" ]]; then
    return 0
  fi
  if [[ -f "${extension_path}" && -x "${extension_path}" && ! -L "${extension_path}" ]]; then
    return 0
  fi

  echo >&2 "${dispatcher_name}: optional hook extension must be a regular executable file: ${extension_path}"
  echo >&2 "${dispatcher_name}: fix or remove the extension before retrying."
  return 1
}

run_beads_hook() {
  local hook_name="$1"
  shift || true

  if ! command -v bd >/dev/null 2>&1; then
    return 0
  fi

  local timeout_seconds="${BEADS_HOOK_TIMEOUT:-300}"
  local exit_code=0

  # Beads' pre-commit runner can export and stage its JSONL snapshot itself.
  # Keep that side effect disabled; the scaffold's preparation phase owns the
  # explicit working-tree export and its validation phase never stages files.
  if command -v timeout >/dev/null 2>&1; then
    BD_GIT_HOOK=1 \
    BD_EXPORT_AUTO=false \
    BD_EXPORT_GIT_ADD=false \
      timeout "${timeout_seconds}" bd hooks run "${hook_name}" "$@" || exit_code=$?
    if [[ "${exit_code}" -eq 124 ]]; then
      echo >&2 "beads: hook '${hook_name}' timed out after ${timeout_seconds}s - continuing without beads"
      return 0
    fi
  else
    BD_GIT_HOOK=1 \
    BD_EXPORT_AUTO=false \
    BD_EXPORT_GIT_ADD=false \
      bd hooks run "${hook_name}" "$@" || exit_code=$?
  fi

  if [[ "${exit_code}" -eq 3 ]]; then
    echo >&2 "beads: database not initialized - skipping hook '${hook_name}'"
    return 0
  fi

  if [[ "${exit_code}" -ne 0 ]]; then
    return "${exit_code}"
  fi
}

export_beads_snapshot_to() {
  local output_path="$1"
  local export_help=""
  local help_status=0
  local exit_code=0
  local -a export_args=(export)

  require_beads_cli
  export_help="$(
    BD_GIT_HOOK=1 \
    BD_EXPORT_AUTO=false \
    BD_EXPORT_GIT_ADD=false \
      bd export --help 2>&1
  )" || help_status=$?
  if [[ "${help_status}" -ne 0 ]]; then
    echo >&2 "beads: failed to inspect export capabilities."
    [[ -z "${export_help}" ]] || printf '%s\n' "${export_help}" >&2
    return "${help_status}"
  fi

  if [[ "${export_help}" == *"--no-memories"* ]]; then
    export_args+=(--no-memories)
  fi
  export_args+=(-o "${output_path}")

  BD_GIT_HOOK=1 \
  BD_EXPORT_AUTO=false \
  BD_EXPORT_GIT_ADD=false \
    bd "${export_args[@]}" || exit_code=$?
  if [[ "${exit_code}" -eq 0 ]]; then
    return 0
  fi

  echo >&2 "beads: failed to export the live tracker snapshot."
  echo >&2 "beads: verify 'bd status --json' succeeds and bootstrap the local database if required."
  return "${exit_code}"
}
