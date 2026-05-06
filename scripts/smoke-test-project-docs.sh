#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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

expect_failure_text() {
  local expected="$1"
  shift

  local err=""
  err="$(mktemp "${TMPDIR:-/tmp}/project-docs-smoke-err.XXXXXX")"
  if "$@" >/dev/null 2>"${err}"; then
    echo "command should have failed: $*" >&2
    exit 1
  fi
  require_text "${expected}" "${err}"
  rm -f "${err}"
}

tmp="$(mktemp -d -t project-docs-smoke-XXXX)"
trap 'rm -rf "${tmp:-}"' EXIT

target="${tmp}/target-project"
mkdir -p "${target}"

scripts/init-project-docs.sh "${target}" >"${tmp}/project-docs-init.out"
require_file "${target}/docs/project/brief.md"
require_file "${target}/docs/project/requirements.md"
require_file "${target}/docs/project/scope.md"
require_file "${target}/docs/project/architecture.md"
require_file "${target}/docs/project/risks.md"
require_file "${target}/docs/project/definition-of-done.md"
require_file "${target}/docs/sprints/README.md"
require_file "${target}/docs/releases/README.md"
require_text "# Project Brief" "${target}/docs/project/brief.md"
require_text "# Definition of Done" "${target}/docs/project/definition-of-done.md"

scripts/new-sprint-docs.sh "${target}" 2026-05-06-sprint-01 >"${tmp}/project-docs-sprint.out"
require_file "${target}/docs/sprints/2026-05-06-sprint-01/sprint-plan.md"
require_file "${target}/docs/sprints/2026-05-06-sprint-01/selected-work.md"
require_file "${target}/docs/sprints/2026-05-06-sprint-01/test-checklist.md"
require_file "${target}/docs/sprints/2026-05-06-sprint-01/release-checklist.md"
require_file "${target}/docs/sprints/2026-05-06-sprint-01/retro.md"

scripts/new-release-docs.sh "${target}" 0.1.0 >"${tmp}/project-docs-release.out"
require_file "${target}/docs/releases/0.1.0/release-notes.md"
require_file "${target}/docs/releases/0.1.0/deployment-checklist.md"
require_file "${target}/docs/releases/0.1.0/rollback-plan.md"

expect_failure_text "docs/project/brief.md already exists. Use --force to overwrite." \
  scripts/init-project-docs.sh "${target}"
expect_failure_text "docs/sprints/2026-05-06-sprint-01/sprint-plan.md already exists. Use --force to overwrite." \
  scripts/new-sprint-docs.sh "${target}" 2026-05-06-sprint-01
expect_failure_text "docs/releases/0.1.0/release-notes.md already exists. Use --force to overwrite." \
  scripts/new-release-docs.sh "${target}" 0.1.0
expect_failure_text "invalid sprint slug" \
  scripts/new-sprint-docs.sh "${target}" "bad/slug"

printf 'local edit\n' > "${target}/docs/project/brief.md"
scripts/init-project-docs.sh --force "${target}" >"${tmp}/project-docs-init-force.out"
require_text "# Project Brief" "${target}/docs/project/brief.md"

printf 'local edit\n' > "${target}/docs/sprints/2026-05-06-sprint-01/sprint-plan.md"
scripts/new-sprint-docs.sh "${target}" --force 2026-05-06-sprint-01 >"${tmp}/project-docs-sprint-force.out"
require_text "# Sprint Plan" "${target}/docs/sprints/2026-05-06-sprint-01/sprint-plan.md"

printf 'local edit\n' > "${target}/docs/releases/0.1.0/release-notes.md"
scripts/new-release-docs.sh "${target}" 0.1.0 --force >"${tmp}/project-docs-release-force.out"
require_text "# Release Notes" "${target}/docs/releases/0.1.0/release-notes.md"

partial="${tmp}/partial-target"
mkdir -p "${partial}/docs/project"
printf 'existing\n' > "${partial}/docs/project/brief.md"
expect_failure_text "docs/project/brief.md already exists. Use --force to overwrite." \
  scripts/init-project-docs.sh "${partial}"
[[ ! -e "${partial}/docs/project/requirements.md" ]] || {
  echo "init should fail before copying any files" >&2
  exit 1
}

echo "project docs smoke test passed"
