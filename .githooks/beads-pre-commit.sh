#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

cd "${repo_root}"

main_git_index_path() {
  env -u GIT_INDEX_FILE git rev-parse --git-path index
}

uses_partial_commit_index() {
  local default_index=""
  default_index="$(main_git_index_path)"
  [[ "${GIT_INDEX_FILE:-${default_index}}" != "${default_index}" ]]
}

main_index_has_beads_change() {
  local default_index=""
  default_index="$(main_git_index_path)"
  ! GIT_INDEX_FILE="${default_index}" git diff --cached --quiet --no-ext-diff -- .beads/issues.jsonl
}

current_commit_includes_beads_change() {
  ! git diff --cached --quiet --no-ext-diff -- .beads/issues.jsonl
}

abort_partial_commit_if_beads_would_leak() {
  if uses_partial_commit_index && ( main_index_has_beads_change || current_commit_includes_beads_change ); then
    echo >&2 "beads: .beads/issues.jsonl is involved in this commit, but git is using an explicit pathspec or partial index."
    echo >&2 "beads: rerun 'git commit' without pathspecs so the Beads snapshot can be included in the same commit."
    echo >&2 "beads: alternatively include .beads/issues.jsonl explicitly in the commit."
    exit 1
  fi
}

run_beads_hook pre-commit "$@"
if [[ -f "${repo_root}/.beads/issues.jsonl" ]]; then
  bd export --no-memories -o "${repo_root}/.beads/issues.jsonl"
  if ! git diff --quiet --no-ext-diff -- .beads/issues.jsonl || ! git diff --cached --quiet --no-ext-diff -- .beads/issues.jsonl; then
    git add .beads/issues.jsonl
  fi
  abort_partial_commit_if_beads_would_leak
fi
