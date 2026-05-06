#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/project-docs-common.sh"

usage="Usage: $(basename "$0") <target-project-path> [--force]"

project_docs_parse_args "$@"
if [[ "${PROJECT_DOCS_HELP}" == "true" ]]; then
  project_docs_usage "${usage}" 0
fi
if [[ "${#PROJECT_DOCS_POSITIONAL[@]}" -ne 1 ]]; then
  project_docs_usage "${usage}" 1
fi

project_docs_resolve_target_dir "${PROJECT_DOCS_POSITIONAL[0]}"

entries=(
  "project/brief.md.tmpl:docs/project/brief.md"
  "project/requirements.md.tmpl:docs/project/requirements.md"
  "project/scope.md.tmpl:docs/project/scope.md"
  "project/architecture.md.tmpl:docs/project/architecture.md"
  "project/risks.md.tmpl:docs/project/risks.md"
  "project/definition-of-done.md.tmpl:docs/project/definition-of-done.md"
  "sprints/README.md.tmpl:docs/sprints/README.md"
  "releases/README.md.tmpl:docs/releases/README.md"
)

project_docs_copy_entries "${PROJECT_DOCS_FORCE}" "${entries[@]}"
project_docs_print_summary "Wrote project documentation files:"
