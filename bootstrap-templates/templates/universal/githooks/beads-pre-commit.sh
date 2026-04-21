#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

run_beads_hook pre-commit "$@"
if [[ -f "${repo_root}/.beads/issues.jsonl" ]]; then
  bd export --no-memories -o "${repo_root}/.beads/issues.jsonl"
  if ! git diff --quiet --no-ext-diff -- .beads/issues.jsonl || ! git diff --cached --quiet --no-ext-diff -- .beads/issues.jsonl; then
    git add .beads/issues.jsonl
  fi
fi
