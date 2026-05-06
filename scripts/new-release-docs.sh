#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/project-docs-common.sh"

usage="Usage: $(basename "$0") <target-project-path> <release-slug> [--force]"

project_docs_parse_args "$@"
if [[ "${PROJECT_DOCS_HELP}" == "true" ]]; then
  project_docs_usage "${usage}" 0
fi
if [[ "${#PROJECT_DOCS_POSITIONAL[@]}" -ne 2 ]]; then
  project_docs_usage "${usage}" 1
fi

release_slug="${PROJECT_DOCS_POSITIONAL[1]}"
project_docs_resolve_target_dir "${PROJECT_DOCS_POSITIONAL[0]}"
project_docs_validate_slug "release" "${release_slug}"

entries=(
  "release/release-notes.md.tmpl:docs/releases/${release_slug}/release-notes.md"
  "release/deployment-checklist.md.tmpl:docs/releases/${release_slug}/deployment-checklist.md"
  "release/rollback-plan.md.tmpl:docs/releases/${release_slug}/rollback-plan.md"
)

project_docs_copy_entries "${PROJECT_DOCS_FORCE}" "${entries[@]}"
project_docs_print_summary "Wrote release documentation files:"
