#!/usr/bin/env bash
set -euo pipefail

hook_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${hook_dir}/_common.sh"

cd "${repo_root}"
require_main_git_index "beads pre-commit validation"

if ! has_beads_path; then
  exit 0
fi

require_safe_beads_paths "beads pre-commit validation"
require_beads_cli

export_tmp="$(mktemp "${TMPDIR:-/tmp}/beads-pre-commit-export.XXXXXX")"
staged_tmp=""

cleanup_beads_validation() {
  [[ -z "${export_tmp}" ]] || rm -f -- "${export_tmp}"
  [[ -z "${staged_tmp}" ]] || rm -f -- "${staged_tmp}"
}
trap cleanup_beads_validation EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

staged_tmp="$(mktemp "${TMPDIR:-/tmp}/beads-pre-commit-staged.XXXXXX")"
export_beads_snapshot_to "${export_tmp}"

if [[ ! -f "${beads_snapshot_path}" ]]; then
  echo >&2 "beads: working snapshot is missing: ${beads_snapshot_relative}."
  echo >&2 "beads: run .githooks/prepare-commit, inspect the generated snapshot, then stage and review it."
  exit 1
fi

if ! cmp -s "${export_tmp}" "${beads_snapshot_path}"; then
  echo >&2 "beads: working ${beads_snapshot_relative} does not match the live tracker export."
  echo >&2 "beads: run .githooks/prepare-commit, inspect the refreshed snapshot, then stage and review it."
  exit 1
fi

if ! git cat-file blob ":${beads_snapshot_relative}" > "${staged_tmp}" 2>/dev/null; then
  echo >&2 "beads: ${beads_snapshot_relative} is missing from the Git index."
  echo >&2 "beads: run .githooks/prepare-commit, stage the snapshot, and review 'git diff --cached' before committing."
  exit 1
fi

if ! cmp -s "${export_tmp}" "${staged_tmp}"; then
  echo >&2 "beads: staged ${beads_snapshot_relative} does not match the live tracker export."
  echo >&2 "beads: run .githooks/prepare-commit, stage the refreshed snapshot, and review the exact cached diff before committing."
  exit 1
fi
