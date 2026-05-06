#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/project-docs-common.sh"

usage="Usage: $(basename "$0") <target-project-path> <sprint-slug> [--force]"

project_docs_parse_args "$@"
if [[ "${PROJECT_DOCS_HELP}" == "true" ]]; then
  project_docs_usage "${usage}" 0
fi
if [[ "${#PROJECT_DOCS_POSITIONAL[@]}" -ne 2 ]]; then
  project_docs_usage "${usage}" 1
fi

sprint_slug="${PROJECT_DOCS_POSITIONAL[1]}"
project_docs_resolve_target_dir "${PROJECT_DOCS_POSITIONAL[0]}"
project_docs_validate_slug "sprint" "${sprint_slug}"

entries=(
  "sprint/sprint-plan.md.tmpl:docs/sprints/${sprint_slug}/sprint-plan.md"
  "sprint/selected-work.md.tmpl:docs/sprints/${sprint_slug}/selected-work.md"
  "sprint/test-checklist.md.tmpl:docs/sprints/${sprint_slug}/test-checklist.md"
  "sprint/release-checklist.md.tmpl:docs/sprints/${sprint_slug}/release-checklist.md"
  "sprint/retro.md.tmpl:docs/sprints/${sprint_slug}/retro.md"
)

project_docs_copy_entries "${PROJECT_DOCS_FORCE}" "${entries[@]}"
project_docs_print_summary "Wrote sprint documentation files:"
