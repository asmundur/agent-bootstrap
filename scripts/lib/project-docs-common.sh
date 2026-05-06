#!/usr/bin/env bash

project_docs_common_dir="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_docs_repo_root="$(cd -- "${project_docs_common_dir}/../.." && pwd)"
PROJECT_DOCS_TEMPLATE_ROOT="${project_docs_repo_root}/bootstrap-templates/templates/universal/project-docs"

PROJECT_DOCS_FORCE=false
PROJECT_DOCS_HELP=false
PROJECT_DOCS_POSITIONAL=()
PROJECT_DOCS_WRITTEN=()
PROJECT_DOCS_TARGET_DIR=""

project_docs_die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

project_docs_usage() {
  local usage="$1"
  local exit_code="${2:-0}"

  printf '%s\n' "${usage}"
  exit "${exit_code}"
}

project_docs_parse_args() {
  local arg=""

  PROJECT_DOCS_FORCE=false
  PROJECT_DOCS_HELP=false
  PROJECT_DOCS_POSITIONAL=()

  for arg in "$@"; do
    case "${arg}" in
      --force)
        PROJECT_DOCS_FORCE=true
        ;;
      -h|--help)
        PROJECT_DOCS_HELP=true
        ;;
      --*)
        project_docs_die "unknown option: ${arg}"
        ;;
      *)
        PROJECT_DOCS_POSITIONAL+=("${arg}")
        ;;
    esac
  done
}

project_docs_require_template_root() {
  [[ -d "${PROJECT_DOCS_TEMPLATE_ROOT}" ]] || {
    project_docs_die "cannot find project docs templates at ${PROJECT_DOCS_TEMPLATE_ROOT}"
  }
}

project_docs_resolve_target_dir() {
  local target_path="$1"

  [[ -n "${target_path}" ]] || project_docs_die "missing target project path"
  [[ -d "${target_path}" ]] || {
    project_docs_die "target project path must be an existing directory: ${target_path}"
  }

  PROJECT_DOCS_TARGET_DIR="$(cd -- "${target_path}" && pwd)"
}

project_docs_validate_slug() {
  local kind="$1"
  local slug="$2"

  [[ -n "${slug}" ]] || project_docs_die "missing ${kind} slug"
  if [[ ! "${slug}" =~ ^[A-Za-z0-9._-]+$ ]]; then
    project_docs_die "invalid ${kind} slug: ${slug} (use [A-Za-z0-9._-]+)"
  fi
}

project_docs_preflight_entries() {
  local force="$1"
  shift

  local entry=""
  local template_rel=""
  local target_rel=""
  local template_abs=""
  local target_abs=""
  local parent_abs=""

  for entry in "$@"; do
    template_rel="${entry%%:*}"
    target_rel="${entry#*:}"
    template_abs="${PROJECT_DOCS_TEMPLATE_ROOT}/${template_rel}"
    target_abs="${PROJECT_DOCS_TARGET_DIR}/${target_rel}"
    parent_abs="$(dirname "${target_abs}")"

    [[ -f "${template_abs}" ]] || project_docs_die "missing template: ${template_rel}"

    if [[ -e "${parent_abs}" && ! -d "${parent_abs}" ]]; then
      project_docs_die "$(dirname "${target_rel}") exists but is not a directory"
    fi

    if [[ -e "${target_abs}" ]]; then
      if [[ ! -f "${target_abs}" ]]; then
        project_docs_die "${target_rel} already exists and is not a file"
      fi
      if [[ "${force}" != "true" ]]; then
        project_docs_die "${target_rel} already exists. Use --force to overwrite."
      fi
    fi
  done
}

project_docs_copy_entries() {
  local force="$1"
  shift

  local entry=""
  local template_rel=""
  local target_rel=""
  local template_abs=""
  local target_abs=""

  project_docs_require_template_root
  project_docs_preflight_entries "${force}" "$@"
  PROJECT_DOCS_WRITTEN=()

  for entry in "$@"; do
    template_rel="${entry%%:*}"
    target_rel="${entry#*:}"
    template_abs="${PROJECT_DOCS_TEMPLATE_ROOT}/${template_rel}"
    target_abs="${PROJECT_DOCS_TARGET_DIR}/${target_rel}"

    mkdir -p "$(dirname "${target_abs}")"
    cp "${template_abs}" "${target_abs}"
    PROJECT_DOCS_WRITTEN+=("${target_rel}")
  done
}

project_docs_print_summary() {
  local label="$1"
  local path=""

  printf '%s\n' "${label}"
  for path in "${PROJECT_DOCS_WRITTEN[@]}"; do
    printf '  %s\n' "${path}"
  done
}
