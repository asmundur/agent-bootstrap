#!/usr/bin/env bash
set -Eeuo pipefail

report_smoke_failure() {
  local status="$?"
  echo "scaffold smoke test failed at line ${BASH_LINENO[0]}: ${BASH_COMMAND}" >&2
  exit "${status}"
}
trap report_smoke_failure ERR

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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
  rg -F --quiet -- "${pattern}" "${path}" || {
    echo "missing expected text in ${path}: ${pattern}" >&2
    exit 1
  }
}

forbid_text() {
  local pattern="$1"
  local path="$2"
  require_file "${path}"
  if rg -F --quiet -- "${pattern}" "${path}"; then
    echo "unexpected text in ${path}: ${pattern}" >&2
    exit 1
  fi
}

path_mode() {
  local path="$1"

  if stat -f '%Lp' "${path}" >/dev/null 2>&1; then
    stat -f '%Lp' "${path}"
  else
    stat -c '%a' "${path}"
  fi
}

snapshot_tree() {
  local root="$1"
  local destination="$2"

  (
    cd "${root}"
    while IFS= read -r path; do
      if [[ -L "${path}" ]]; then
        printf 'link\t%s\t%s\t%s\n' \
          "$(path_mode "${path}")" \
          "$(readlink "${path}")" \
          "${path}"
      elif [[ -d "${path}" ]]; then
        printf 'directory\t%s\t%s\n' "$(path_mode "${path}")" "${path}"
      elif [[ -f "${path}" ]]; then
        printf 'file\t%s\t%s\t%s\n' \
          "$(path_mode "${path}")" \
          "$(shasum -a 256 "${path}" | awk '{print $1}')" \
          "${path}"
      else
        printf 'other\t%s\n' "${path}"
      fi
    done < <((find . -mindepth 1 -print 2>/dev/null || true) | LC_ALL=C sort)
  ) > "${destination}"
}

assert_tree_matches_snapshot() {
  local root="$1"
  local expected="$2"
  local context="$3"
  local actual=""

  actual="$(mktemp "${TMPDIR:-/tmp}/scaffold-tree-actual.XXXXXX")"
  snapshot_tree "${root}" "${actual}"
  if ! cmp -s "${expected}" "${actual}"; then
    echo "${context} changed the target tree" >&2
    diff -u "${expected}" "${actual}" >&2 || true
    rm -f "${actual}"
    exit 1
  fi
  rm -f "${actual}"
}

assert_scaffold_check_and_apply_fail_unchanged() {
  local scaffold_script="$1"
  local root="$2"
  local context="$3"
  shift 3
  local invocation=""
  local before=""
  local out=""
  local err=""
  local -a args=()
  local pattern=""

  for invocation in check apply; do
    before="$(mktemp "${TMPDIR:-/tmp}/scaffold-blocker-before.XXXXXX")"
    out="$(mktemp "${TMPDIR:-/tmp}/scaffold-blocker-output.XXXXXX")"
    err="$(mktemp "${TMPDIR:-/tmp}/scaffold-blocker-error.XXXXXX")"
    snapshot_tree "${root}" "${before}"

    if [[ "${invocation}" == "check" ]]; then
      args=(--check "${root}" all)
    else
      args=("${root}" all)
    fi

    if bash "${scaffold_script}" "${args[@]}" > "${out}" 2> "${err}"; then
      echo "${context} should block scaffold ${invocation}" >&2
      exit 1
    fi

    require_text "Scaffold preflight failed" "${err}"
    for pattern in "$@"; do
      require_text "${pattern}" "${err}"
    done
    assert_tree_matches_snapshot "${root}" "${before}" "${context} (${invocation})"
    rm -f "${before}" "${out}" "${err}"
  done
}

set_managed_checksum() {
  local root="$1"
  local target="$2"
  local state="${root}/.agent-scaffold.json"
  local checksum=""

  checksum="$(shasum -a 256 "${root}/${target}" | awk '{print $1}')"
  jq --arg target "${target}" --arg checksum "${checksum}" '
    .files |= map(if .target == $target then .checksum = $checksum else . end)
  ' "${state}" > "${state}.next"
  mv "${state}.next" "${state}"
}

assert_managed_checksums_match() {
  local root="$1"
  local target=""
  local expected=""
  local actual=""

  while IFS=$'\t' read -r target expected; do
    actual="$(shasum -a 256 "${root}/${target}" | awk '{print $1}')"
    [[ "${actual}" == "${expected}" ]] || {
      echo "managed checksum mismatch for ${target}: expected ${expected}, got ${actual}" >&2
      exit 1
    }
  done < <(jq -r '.files[] | [.target, .checksum] | @tsv' "${root}/.agent-scaffold.json")
}

template_files=(
  "bootstrap-templates/templates/universal/AGENTS.md.tmpl"
  "bootstrap-templates/templates/universal/CLAUDE.md.tmpl"
  "bootstrap-templates/templates/universal/agents/feature-implementation.md.tmpl"
  "bootstrap-templates/templates/universal/skills/bootstrap.md.tmpl"
  "bootstrap-templates/templates/universal/skills/grill-me.md.tmpl"
  "bootstrap-templates/templates/universal/skills/ubiquitous-language.md.tmpl"
  "bootstrap-templates/templates/universal/skills/improve-architecture.md.tmpl"
  "bootstrap-templates/templates/universal/skills/tdd.md.tmpl"
  "bootstrap-templates/templates/universal/skills/feature-start.md.tmpl"
  "bootstrap-templates/templates/universal/skills/retro.md.tmpl"
  "bootstrap-templates/templates/universal/skills/resolve-adopted-artifacts.md.tmpl"
  "bootstrap-templates/templates/universal/skills/audit-beads-quality.md.tmpl"
  "bootstrap-templates/templates/universal/workflows/feature-workflow.md.tmpl"
)

local_files=(
  "AGENTS.md"
  ".agent-scaffold.json"
  ".agents/anti-patterns.md"
  ".agents/workflows/feature-workflow.md"
  ".claude/CLAUDE.md"
  ".claude/agents/feature-implementation.md"
  ".claude/agents/git-manager.md"
  ".claude/skills/bootstrap.md"
  ".claude/skills/grill-me.md"
  ".claude/skills/ubiquitous-language.md"
  ".claude/skills/improve-architecture.md"
  ".claude/skills/tdd.md"
  ".claude/skills/feature-start.md"
  ".claude/skills/retro.md"
  ".claude/skills/resolve-adopted-artifacts.md"
  ".claude/skills/audit-beads-quality.md"
  ".codex/skills/bootstrap.md"
  ".codex/skills/grill-me.md"
  ".codex/skills/ubiquitous-language.md"
  ".codex/skills/improve-architecture.md"
  ".codex/skills/tdd.md"
  ".codex/skills/feature-start.md"
  ".codex/skills/retro.md"
  ".codex/skills/resolve-adopted-artifacts.md"
  ".codex/skills/audit-beads-quality.md"
  ".antigravity/skills/bootstrap.md"
  ".antigravity/skills/grill-me.md"
  ".antigravity/skills/ubiquitous-language.md"
  ".antigravity/skills/improve-architecture.md"
  ".antigravity/skills/tdd.md"
  ".antigravity/skills/feature-start.md"
  ".antigravity/skills/retro.md"
  ".antigravity/skills/resolve-adopted-artifacts.md"
  ".antigravity/skills/audit-beads-quality.md"
)

for path in "${template_files[@]}"; do
  require_file "${path}"
done

for path in "${local_files[@]}"; do
  require_file "${path}"
done

require_text "/bootstrap" ".claude/CLAUDE.md"
require_text "\"generatedBy\": \"agent-bootstrap\"" ".agent-scaffold.json"
require_text "\"agentHarness\":" ".agent-scaffold.json"
require_text "\"templateSource\":" ".agent-scaffold.json"
require_text "\"checksum\":" ".agent-scaffold.json"
require_text "\"TYPECHECK_COMMAND\": \"not configured\"" ".agent-scaffold.json"
require_text "\"SCAFFOLD_COMMAND\": \"scripts/scaffold.sh\"" ".agent-scaffold.json"
require_text "\"target\": \".claude/skills/bootstrap.md\"" ".agent-scaffold.json"
require_text "\"target\": \".claude/skills/resolve-adopted-artifacts.md\"" ".agent-scaffold.json"
require_text "\"target\": \".codex/skills/feature-start.md\"" ".agent-scaffold.json"
require_text "\"target\": \".antigravity/skills/feature-start.md\"" ".agent-scaffold.json"
require_text "filling in the project-specific values" "bootstrap-templates/templates/universal/skills/bootstrap.md.tmpl"
require_text "resolve all unresolved scaffold adoption conflicts in one pass" "bootstrap-templates/templates/universal/skills/resolve-adopted-artifacts.md.tmpl"
require_text "extract what the upstream scaffold should learn" "bootstrap-templates/templates/universal/skills/resolve-adopted-artifacts.md.tmpl"
require_text "\`scripts/scaffold.sh\` for generation behavior" "bootstrap-templates/templates/universal/skills/resolve-adopted-artifacts.md.tmpl"
require_text "break or change existing behavior" "bootstrap-templates/templates/universal/skills/resolve-adopted-artifacts.md.tmpl"
require_text "line-item policy inventory" "bootstrap-templates/templates/universal/skills/resolve-adopted-artifacts.md.tmpl"
require_text "Scaffold variable or extension point" "bootstrap-templates/templates/universal/skills/resolve-adopted-artifacts.md.tmpl"
require_text "grill-me style adoption interview" "bootstrap-templates/templates/universal/skills/resolve-adopted-artifacts.md.tmpl"
require_text "Do not present a wide matrix covering every conflict" "bootstrap-templates/templates/universal/skills/resolve-adopted-artifacts.md.tmpl"
require_text "Do not lead with \"should I archive/install these files?\"" "bootstrap-templates/templates/universal/skills/resolve-adopted-artifacts.md.tmpl"
require_text "Would installing the scaffold candidate as-is break or weaken behavior" "bootstrap-templates/templates/universal/skills/resolve-adopted-artifacts.md.tmpl"
require_text "apply upstream source changes first" "bootstrap-templates/templates/universal/skills/resolve-adopted-artifacts.md.tmpl"
require_text "Do not compress a policy artifact into an umbrella phrase" "bootstrap-templates/templates/universal/skills/resolve-adopted-artifacts.md.tmpl"
require_text "For every bundled policy loss, split the bundle into concrete rule rows before the interview" "bootstrap-templates/templates/universal/skills/resolve-adopted-artifacts.md.tmpl"
require_text "the interview must be a continuation of the extraction, not a summary endpoint" "bootstrap-templates/templates/universal/skills/resolve-adopted-artifacts.md.tmpl"
require_text "Err on the side of a more complete questionnaire when multiple independent decisions are hiding under one artifact" "bootstrap-templates/templates/universal/skills/resolve-adopted-artifacts.md.tmpl"
require_text "no session-close git actions, no tracker push, generated instruction ownership, hook path ownership, stale Beads runtime recovery, and tracker-only work ledgers" "bootstrap-templates/templates/universal/skills/resolve-adopted-artifacts.md.tmpl"
require_text "Question: Should I preserve these locally?" "bootstrap-templates/templates/universal/skills/resolve-adopted-artifacts.md.tmpl"
require_text "non-mutating commit validation belongs in executable \`.githooks/pre-commit.validate\`" "bootstrap-templates/templates/universal/skills/resolve-adopted-artifacts.md.tmpl"
require_text "generation, formatting, fixing, export, or any other intentional mutation belongs in executable \`.githooks/prepare-commit.local\`" "bootstrap-templates/templates/universal/skills/resolve-adopted-artifacts.md.tmpl"
require_text "Project-Specific Safety Constraints" "bootstrap-templates/templates/universal/AGENTS.md.tmpl"
require_text "Agents must not run \`git add\`, \`git commit\`, or \`git push\` as an automatic session-close workflow." "bootstrap-templates/templates/universal/AGENTS.md.tmpl"
require_text "If local Beads runtime state is stale" "bootstrap-templates/templates/universal/AGENTS.md.tmpl"
require_text "Do not create markdown TODO trackers or side ledgers for net-new work." "bootstrap-templates/templates/universal/AGENTS.md.tmpl"
require_text "A high-quality Beads task has a concrete title, scope-bearing description, design notes, observable acceptance criteria, evidence notes, estimate, and dependencies where relevant." "bootstrap-templates/templates/universal/AGENTS.md.tmpl"
require_text "classify each issue as keep, improve, create, delete-noise, or needs-user-decision" "bootstrap-templates/templates/universal/skills/audit-beads-quality.md.tmpl"
require_text "bd delete --dry-run" "bootstrap-templates/templates/universal/skills/audit-beads-quality.md.tmpl"
require_text "Do not adopt or preserve mandatory automatic git commit, git push, bd sync, or bd dolt push workflows." "bootstrap-templates/templates/universal/skills/audit-beads-quality.md.tmpl"
require_text "routine scaffold refreshes do not require \`/bootstrap\`" "bootstrap-templates/templates/universal/AGENTS.md.tmpl"
require_text "stale_runtime_recovery" "bootstrap-templates/templates/universal/beads/clone-contract.json.tmpl"
require_text "Stage 0 — Shared Design Alignment" "bootstrap-templates/templates/universal/workflows/feature-workflow.md.tmpl"
require_text 'Create or update `.agents/context/ubiquitous-language.md`' "bootstrap-templates/templates/universal/skills/ubiquitous-language.md.tmpl"
require_text "Infrastructure And YAML Contract TDD" "bootstrap-templates/templates/universal/skills/tdd.md.tmpl"
require_text "preflight validation before host, cloud, DNS, database, queue, secret, or" "bootstrap-templates/templates/universal/skills/tdd.md.tmpl"
require_text "Never weaken a guardrail just to make a" "bootstrap-templates/templates/universal/skills/tdd.md.tmpl"
require_text "A request to monitor, babysit, follow through, or watch a deployment authorizes persistent observation only." "bootstrap-templates/templates/universal/AGENTS.md.tmpl"
require_text "Treating monitoring as mutation authority" "bootstrap-templates/templates/universal/anti-patterns.md.tmpl"
require_text "stage each approved source path individually" "bootstrap-templates/templates/universal/AGENTS.md.tmpl"
require_text "Stop if preparation expands beyond the approved scope." "bootstrap-templates/templates/universal/AGENTS.md.tmpl"
require_text "stage each approved generated path individually" "bootstrap-templates/templates/universal/AGENTS.md.tmpl"
require_text "Verify the committed tree matches the approved tree" "bootstrap-templates/templates/universal/agents/git-manager.md.tmpl"
require_text "pre-commit.validate" "bootstrap-templates/templates/universal/githooks/pre-commit"
forbid_text "pre-commit.local" "bootstrap-templates/templates/universal/githooks/pre-commit"
require_text 'git cat-file blob ":${beads_snapshot_relative}"' "bootstrap-templates/templates/universal/githooks/beads-pre-commit.sh"
require_text "embeddeddolt/" "bootstrap-templates/templates/universal/beads/gitignore"
forbid_text "/sync-bootstrap" ".claude/CLAUDE.md"

hook_contract_files=(
  "bootstrap-templates/templates/universal/githooks/prepare-commit"
  "bootstrap-templates/templates/universal/githooks/pre-commit"
  "bootstrap-templates/templates/universal/githooks/beads-pre-commit.sh"
)

for path in "${hook_contract_files[@]}"; do
  require_file "${path}"
  if rg --quiet '^[[:space:]]*git[[:space:]]+add([[:space:]]|$)' "${path}"; then
    echo "commit hook must not stage files: ${path}" >&2
    exit 1
  fi
done

branch_guidance_files=(
  "bootstrap-templates/templates/universal/skills/feature-start.md.tmpl"
  ".claude/skills/feature-start.md"
  ".codex/skills/feature-start.md"
  ".antigravity/skills/feature-start.md"
)

for path in "${branch_guidance_files[@]}"; do
  require_text 'feature/<feature-slug>' "${path}"
  require_text 'git check-ref-format --branch "${branch_name}"' "${path}"
  require_text 'git switch -c "${branch_name}"' "${path}"
  require_text "If the user explicitly declines the proposed feature branch, continue on the current branch" "${path}"
  forbid_text 'feature/{{PROJECT_NAME}}' "${path}"
done

run_scaffold() {
  local tmp="$1"
  local agent_harness="$2"
  mkdir -p "${tmp}"
  bash "${repo_root}/scripts/scaffold.sh" "${tmp}" "${agent_harness}" >/dev/null
}

assert_bootstrap_prompt_cadence() {
  local tmp="$1"
  local first_out=""
  local refresh_out=""
  local hydrated_out=""

  mkdir -p "${tmp}"
  first_out="$(mktemp "${TMPDIR:-/tmp}/scaffold-cadence-first.XXXXXX")"
  refresh_out="$(mktemp "${TMPDIR:-/tmp}/scaffold-cadence-refresh.XXXXXX")"
  hydrated_out="$(mktemp "${TMPDIR:-/tmp}/scaffold-cadence-hydrated.XXXXXX")"

  bash "${repo_root}/scripts/scaffold.sh" "${tmp}" "all" > "${first_out}"
  require_text "Next step: run /bootstrap in your agent harness to hydrate project-specific values from the codebase." "${first_out}"

  bash "${repo_root}/scripts/scaffold.sh" "${tmp}" "all" > "${refresh_out}"
  require_text "Scaffold refresh complete." "${refresh_out}"
  require_text "Project-specific scaffold values still look generic: PROJECT_NAME, PROJECT_DESCRIPTION, TECH_STACK, MAIN_LANGUAGE, SOURCE_DIR, ARCHITECTURE_PATTERN" "${refresh_out}"
  require_text "Next step: run /bootstrap in your agent harness to hydrate those values from the codebase." "${refresh_out}"
  forbid_text "to hydrate project-specific values from the codebase." "${refresh_out}"

  jq '
    .variables.PROJECT_NAME = "scaffold-cadence-smoke" |
    .variables.PROJECT_DESCRIPTION = "Reusable scaffold for agent-assisted software development." |
    .variables.TECH_STACK = "Bash, Markdown, jq" |
    .variables.MAIN_LANGUAGE = "Shell" |
    .variables.SOURCE_DIR = "scripts/" |
    .variables.ARCHITECTURE_PATTERN = "Template renderer" |
    .variables.BUILD_COMMAND = "not configured" |
    .variables.TYPECHECK_COMMAND = "not configured" |
    .variables.LINT_COMMAND = "not configured" |
    .variables.BROWSER_VERIFY_COMMAND = "not configured" |
    .variables.TEST_COMMAND = "not configured" |
    .variables.RUN_COMMAND = "not configured"
  ' "${tmp}/.agent-scaffold.json" > "${tmp}/.agent-scaffold.json.next"
  mv "${tmp}/.agent-scaffold.json.next" "${tmp}/.agent-scaffold.json"

  bash "${repo_root}/scripts/scaffold.sh" "${tmp}" "all" > "${hydrated_out}"
  require_text "Scaffold refresh complete." "${hydrated_out}"
  require_text "/bootstrap is not needed for this refresh." "${hydrated_out}"
  forbid_text "Project-specific scaffold values still look generic" "${hydrated_out}"

  rm -f "${first_out}" "${refresh_out}" "${hydrated_out}"
}

assert_beads_readiness_message_matches_status() {
  if ! command -v bd >/dev/null 2>&1; then
    echo "bd not found; skipping Beads readiness message smoke test"
    return 0
  fi

  local tmp="$1"
  local out=""

  out="$(mktemp "${TMPDIR:-/tmp}/scaffold-beads-readiness.XXXXXX")"
  git -C "${tmp}" init -q
  bash "${repo_root}/scripts/scaffold.sh" "${tmp}" "all" > "${out}"

  if (cd "${tmp}" && bd status --json >/dev/null 2>&1); then
    require_text "Beads bootstrap verified." "${out}"
  else
    require_text "Warning: scaffold files were written, but 'bd bootstrap --yes --json' did not complete successfully." "${out}"
    require_text "Verify Beads readiness with: bd status --json" "${out}"
    forbid_text "Beads bootstrap verified." "${out}"
  fi

  rm -f "${out}"
}

assert_check_is_zero_write() {
  local tmp="$1"
  local before=""
  local out=""

  mkdir -p "${tmp}"
  git -C "${tmp}" init -q
  git -C "${tmp}" config scaffold.smoke untouched
  printf 'check mode sentinel\n' > "${tmp}/sentinel.txt"

  before="$(mktemp "${TMPDIR:-/tmp}/scaffold-check-before.XXXXXX")"
  out="$(mktemp "${TMPDIR:-/tmp}/scaffold-check-output.XXXXXX")"
  snapshot_tree "${tmp}" "${before}"

  bash "${repo_root}/scripts/scaffold.sh" --check "${tmp}" "all" > "${out}"

  require_text "Scaffold check passed." "${out}"
  assert_tree_matches_snapshot "${tmp}" "${before}" "successful scaffold --check"
  [[ ! -e "${tmp}/.agent-scaffold.json" ]] || {
    echo "scaffold --check created state in ${tmp}" >&2
    exit 1
  }
  [[ "$(git -C "${tmp}" config --get scaffold.smoke)" == "untouched" ]] || {
    echo "scaffold --check changed Git configuration in ${tmp}" >&2
    exit 1
  }

  rm -f "${before}" "${out}"
}

assert_managed_combined_hook_blocks_without_writes() {
  local tmp="$1"

  run_scaffold "${tmp}" "all"
  cat <<'EOF' > "${tmp}/.githooks/pre-commit"
#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

"$(cd "$(dirname "$0")" && pwd)/beads-pre-commit.sh" "$@"

# Preserved from pre-existing .githooks/pre-commit during scaffold adoption.
"${repo_root}/scripts/check-production-vault.sh"
EOF
  chmod +x "${tmp}/.githooks/pre-commit"
  set_managed_checksum "${tmp}" ".githooks/pre-commit"

  assert_scaffold_check_and_apply_fail_unchanged \
    "${repo_root}/scripts/scaffold.sh" \
    "${tmp}" \
    "managed combined-hook blocker" \
    ".githooks/pre-commit" \
    ".githooks/pre-commit.validate" \
    ".githooks/prepare-commit.local"
}

assert_legacy_pre_commit_local_blocks_without_writes() {
  local tmp="$1"

  run_scaffold "${tmp}" "all"
  cat <<'EOF' > "${tmp}/.githooks/pre-commit.local"
#!/usr/bin/env bash
set -euo pipefail
printf 'legacy hook\n'
EOF
  chmod +x "${tmp}/.githooks/pre-commit.local"

  assert_scaffold_check_and_apply_fail_unchanged \
    "${repo_root}/scripts/scaffold.sh" \
    "${tmp}" \
    "legacy pre-commit.local blocker" \
    ".githooks/pre-commit.local"
}

assert_non_executable_extensions_block_without_writes() {
  local tmp="$1"

  run_scaffold "${tmp}" "all"
  cat <<'EOF' > "${tmp}/.githooks/prepare-commit.local"
#!/usr/bin/env bash
exit 0
EOF
  cat <<'EOF' > "${tmp}/.githooks/pre-commit.validate"
#!/usr/bin/env bash
exit 0
EOF
  chmod 644 "${tmp}/.githooks/prepare-commit.local" "${tmp}/.githooks/pre-commit.validate"

  assert_scaffold_check_and_apply_fail_unchanged \
    "${repo_root}/scripts/scaffold.sh" \
    "${tmp}" \
    "non-executable hook-extension blocker" \
    ".githooks/prepare-commit.local" \
    ".githooks/pre-commit.validate" \
    "executable"
}

assert_executable_non_shell_extensions_survive_refresh() {
  local tmp="$1"
  local prepare_local="${tmp}/.githooks/prepare-commit.local"
  local before_checksum=""
  local out=""

  run_scaffold "${tmp}" "all"
  cat <<'EOF' > "${prepare_local}"
#!/usr/bin/env python3
print("project preparation")
EOF
  chmod 0755 "${prepare_local}"
  before_checksum="$(shasum -a 256 "${prepare_local}" | awk '{print $1}')"
  out="$(mktemp "${TMPDIR:-/tmp}/scaffold-non-shell-extension.XXXXXX")"

  bash "${repo_root}/scripts/scaffold.sh" --check "${tmp}" "all" > "${out}"
  require_text "Scaffold check passed." "${out}"
  bash "${repo_root}/scripts/scaffold.sh" "${tmp}" "all" > "${out}"
  require_text "Scaffold refresh complete." "${out}"
  [[ "$(shasum -a 256 "${prepare_local}" | awk '{print $1}')" == "${before_checksum}" ]] || {
    echo "executable non-shell project hook extension changed during refresh" >&2
    exit 1
  }

  rm -f "${out}"
}

assert_managed_legacy_clone_contract_blocks_without_writes() {
  local tmp="$1"
  local contract="${tmp}/.beads/clone-contract.json"

  run_scaffold "${tmp}" "all"
  jq '.jsonl_export = "issues.jsonl"' "${contract}" > "${contract}.next"
  mv "${contract}.next" "${contract}"
  set_managed_checksum "${tmp}" ".beads/clone-contract.json"

  assert_scaffold_check_and_apply_fail_unchanged \
    "${repo_root}/scripts/scaffold.sh" \
    "${tmp}" \
    "managed clone-contract migration blocker" \
    ".beads/clone-contract.json" \
    "issues.jsonl"
}

assert_late_drift_blocks_all_earlier_writes() {
  local tmp="$1"
  local state="${tmp}/.agent-scaffold.json"

  run_scaffold "${tmp}" "all"
  jq '.variables.PROJECT_DESCRIPTION = "This value must not render before late drift is reported."' \
    "${state}" > "${state}.next"
  mv "${state}.next" "${state}"
  printf '\nLate managed drift.\n' >> "${tmp}/.claude/CLAUDE.md"

  assert_scaffold_check_and_apply_fail_unchanged \
    "${repo_root}/scripts/scaffold.sh" \
    "${tmp}" \
    "late-target drift preflight" \
    ".claude/CLAUDE.md"
  forbid_text "This value must not render before late drift is reported." "${tmp}/AGENTS.md"
}

assert_candidate_collision_blocks_without_writes() {
  local tmp="$1"

  mkdir -p "${tmp}"
  printf '# Active project guidance\n' > "${tmp}/AGENTS.md"
  printf '# Stale scaffold candidate\n' > "${tmp}/AGENTS.scaffold-candidate.md"

  assert_scaffold_check_and_apply_fail_unchanged \
    "${repo_root}/scripts/scaffold.sh" \
    "${tmp}" \
    "state-less adoption candidate collision" \
    "scaffold candidate path already exists" \
    "AGENTS.scaffold-candidate.md"
  [[ ! -e "${tmp}/.agent-scaffold.json" ]] || {
    echo "candidate-collision blocker wrote scaffold state" >&2
    exit 1
  }
}

assert_late_blocker_withholds_adoption_candidates() {
  local tmp="$1"

  mkdir -p "${tmp}/.githooks"
  printf '# Active project guidance\n' > "${tmp}/AGENTS.md"
  cat <<'EOF' > "${tmp}/.githooks/prepare-commit.local"
#!/usr/bin/env bash
exit 0
EOF
  chmod 0644 "${tmp}/.githooks/prepare-commit.local"

  assert_scaffold_check_and_apply_fail_unchanged \
    "${repo_root}/scripts/scaffold.sh" \
    "${tmp}" \
    "late blocker withholding state-less candidates" \
    ".githooks/prepare-commit.local" \
    "executable"
  [[ ! -e "${tmp}/AGENTS.scaffold-candidate.md" ]] || {
    echo "late preflight blocker still created a state-less adoption candidate" >&2
    exit 1
  }
  [[ ! -e "${tmp}/.agent-scaffold.json" ]] || {
    echo "late preflight blocker still created scaffold state" >&2
    exit 1
  }
}

assert_unsafe_obsolete_target_blocks_without_writes() {
  local tmp="$1"
  local outside="${tmp}.outside-managed"
  local outside_checksum=""
  local outside_mode=""
  local unsafe_target="../$(basename "${outside}")"

  run_scaffold "${tmp}" "all"
  printf 'must stay outside the target\n' > "${outside}"
  chmod 0640 "${outside}"
  outside_checksum="$(shasum -a 256 "${outside}" | awk '{print $1}')"
  outside_mode="$(path_mode "${outside}")"

  jq \
    --arg target "${unsafe_target}" \
    --arg checksum "${outside_checksum}" \
    '.files += [{
      target: $target,
      source: "obsolete-fixture",
      category: "config",
      checksum: $checksum
    }]' \
    "${tmp}/.agent-scaffold.json" > "${tmp}/.agent-scaffold.json.next"
  mv "${tmp}/.agent-scaffold.json.next" "${tmp}/.agent-scaffold.json"

  assert_scaffold_check_and_apply_fail_unchanged \
    "${repo_root}/scripts/scaffold.sh" \
    "${tmp}" \
    "unsafe obsolete target" \
    "unsafe" \
    "checkout-relative"
  [[ "$(shasum -a 256 "${outside}" | awk '{print $1}')" == "${outside_checksum}" ]] || {
    echo "unsafe obsolete target changed a file outside the checkout" >&2
    exit 1
  }
  [[ "$(path_mode "${outside}")" == "${outside_mode}" ]] || {
    echo "unsafe obsolete target changed a mode outside the checkout" >&2
    exit 1
  }
  rm -f "${outside}"
}

assert_option_like_obsolete_target_blocks_without_writes() {
  local tmp="$1"
  local checksum=""

  run_scaffold "${tmp}" "all"
  printf 'project-owned dash file\n' > "${tmp}/-"
  checksum="$(shasum -a 256 "${tmp}/-" | awk '{print $1}')"
  jq \
    --arg checksum "${checksum}" \
    '.files += [{
      target: "-",
      source: "obsolete-option-fixture",
      category: "config",
      checksum: $checksum
    }]' \
    "${tmp}/.agent-scaffold.json" > "${tmp}/.agent-scaffold.json.next"
  mv "${tmp}/.agent-scaffold.json.next" "${tmp}/.agent-scaffold.json"

  assert_scaffold_check_and_apply_fail_unchanged \
    "${repo_root}/scripts/scaffold.sh" \
    "${tmp}" \
    "option-like obsolete target" \
    "scaffold state contains an invalid, unsafe, or non-checkout-relative managed path"
}

assert_unverified_legacy_manifest_blocks_without_writes() {
  local tmp="$1"

  run_scaffold "${tmp}" "all"
  printf '{"owner":"project"}\n' > "${tmp}/.claude/.bootstrap-manifest.json"

  assert_scaffold_check_and_apply_fail_unchanged \
    "${repo_root}/scripts/scaffold.sh" \
    "${tmp}" \
    "unverified legacy manifest" \
    "legacy scaffold state" \
    "refusing unverified removal"
}

assert_symlinked_parent_blocks_without_external_writes() {
  local tmp="$1"
  local outside="${tmp}.outside-hooks"
  local outside_before=""

  mkdir -p "${tmp}" "${outside}"
  printf 'outside sentinel\n' > "${outside}/sentinel.txt"
  ln -s "${outside}" "${tmp}/.githooks"
  outside_before="$(mktemp "${TMPDIR:-/tmp}/scaffold-outside-before.XXXXXX")"
  snapshot_tree "${outside}" "${outside_before}"

  assert_scaffold_check_and_apply_fail_unchanged \
    "${repo_root}/scripts/scaffold.sh" \
    "${tmp}" \
    "symlinked scaffold parent" \
    "destination parent contains a symlink" \
    ".githooks"
  assert_tree_matches_snapshot "${outside}" "${outside_before}" "symlinked scaffold parent external target"
  rm -f "${outside_before}"
  rm -rf "${outside}"
}

assert_invalid_state_destinations_block_without_writes() {
  local directory_target="$1"
  local symlink_target="$2"
  local outside="${symlink_target}.outside-state"
  local outside_before=""

  mkdir -p "${directory_target}/.agent-scaffold.json"
  printf 'state-directory sentinel\n' \
    > "${directory_target}/.agent-scaffold.json/sentinel.txt"
  assert_scaffold_check_and_apply_fail_unchanged \
    "${repo_root}/scripts/scaffold.sh" \
    "${directory_target}" \
    "directory scaffold-state destination" \
    "scaffold state destination must be missing or a regular file" \
    ".agent-scaffold.json"

  mkdir -p "${symlink_target}" "${outside}"
  printf 'external state-directory sentinel\n' > "${outside}/sentinel.txt"
  ln -s "${outside}" "${symlink_target}/.agent-scaffold.json"
  outside_before="$(mktemp "${TMPDIR:-/tmp}/scaffold-outside-state-before.XXXXXX")"
  snapshot_tree "${outside}" "${outside_before}"
  assert_scaffold_check_and_apply_fail_unchanged \
    "${repo_root}/scripts/scaffold.sh" \
    "${symlink_target}" \
    "symlinked scaffold-state destination" \
    "scaffold state destination must be missing or a regular file" \
    ".agent-scaffold.json"
  assert_tree_matches_snapshot \
    "${outside}" \
    "${outside_before}" \
    "symlinked scaffold-state destination external target"

  rm -f "${outside_before}"
  rm -rf "${outside}"
}

assert_untrusted_state_files_block_without_writes() {
  local foreign_target="$1"
  local invalid_schema_target="$2"

  mkdir -p "${foreign_target}"
  printf '%s\n' \
    '{"generatedBy":"project","variables":{},"files":[]}' \
    > "${foreign_target}/.agent-scaffold.json"
  assert_scaffold_check_and_apply_fail_unchanged \
    "${repo_root}/scripts/scaffold.sh" \
    "${foreign_target}" \
    "foreign scaffold-state ownership" \
    "scaffold state ownership could not be verified" \
    ".agent-scaffold.json"

  mkdir -p "${invalid_schema_target}"
  printf '%s\n' \
    '{"generatedBy":"agent-bootstrap","variables":"not-an-object","files":[]}' \
    > "${invalid_schema_target}/.agent-scaffold.json"
  assert_scaffold_check_and_apply_fail_unchanged \
    "${repo_root}/scripts/scaffold.sh" \
    "${invalid_schema_target}" \
    "invalid scaffold-state schema" \
    "scaffold state does not match the required schema" \
    ".agent-scaffold.json"
}

assert_state_capture_rejects_mismatched_copy() {
  local tmp="$1"
  local state="${tmp}/.agent-scaffold.json"
  local payload=""
  local bash_env=""
  local before=""
  local out=""
  local err=""
  local invocation=""
  local -a args=()

  run_scaffold "${tmp}" "all"
  payload="$(mktemp "${TMPDIR:-/tmp}/scaffold-state-race-payload.XXXXXX")"
  bash_env="$(mktemp "${TMPDIR:-/tmp}/scaffold-state-race-env.XXXXXX")"
  jq '.variables.PROJECT_DESCRIPTION = "state copy supplied by the race fixture"' \
    "${state}" > "${payload}"
  cat <<'EOF' > "${bash_env}"
cp() {
  if [[ "${1:-}" == ".agent-scaffold.json" && "${2:-}" == */existing-state.json ]]; then
    command cp "${SCAFFOLD_STATE_RACE_PAYLOAD:?}" "$2"
    return
  fi
  command cp "$@"
}
EOF

  for invocation in check apply; do
    before="$(mktemp "${TMPDIR:-/tmp}/scaffold-state-race-before.XXXXXX")"
    out="$(mktemp "${TMPDIR:-/tmp}/scaffold-state-race-output.XXXXXX")"
    err="$(mktemp "${TMPDIR:-/tmp}/scaffold-state-race-error.XXXXXX")"
    snapshot_tree "${tmp}" "${before}"
    if [[ "${invocation}" == "check" ]]; then
      args=(--check "${tmp}" all)
    else
      args=("${tmp}" all)
    fi
    if BASH_ENV="${bash_env}" \
      SCAFFOLD_STATE_RACE_PAYLOAD="${payload}" \
      bash "${repo_root}/scripts/scaffold.sh" "${args[@]}" > "${out}" 2> "${err}"; then
      echo "mismatched scaffold-state capture should block ${invocation}" >&2
      exit 1
    fi
    require_text "scaffold input changed while it was being captured" "${err}"
    assert_tree_matches_snapshot \
      "${tmp}" \
      "${before}" \
      "mismatched scaffold-state capture (${invocation})"
    rm -f "${before}" "${out}" "${err}"
  done

  rm -f "${payload}" "${bash_env}"
}

assert_consumed_beads_input_is_rechecked() {
  local tmp="$1"
  local expected="${tmp}.expected"
  local bash_env=""
  local expected_snapshot=""
  local out=""
  local err=""
  local invocation=""
  local -a args=()

  mkdir -p "${tmp}/.beads" "${expected}/.beads"
  printf 'issue-prefix: raced\n' > "${expected}/.beads/config.yaml"
  expected_snapshot="$(mktemp "${TMPDIR:-/tmp}/scaffold-input-race-expected.XXXXXX")"
  snapshot_tree "${expected}" "${expected_snapshot}"
  bash_env="$(mktemp "${TMPDIR:-/tmp}/scaffold-input-race-env.XXXXXX")"
  cat <<'EOF' > "${bash_env}"
awk() {
  command awk "$@"
  case "$*" in
    *existing-beads-config.yaml*)
      printf 'issue-prefix: raced\n' \
        > "${SCAFFOLD_INFERENCE_RACE_TARGET:?}/.beads/config.yaml"
      ;;
  esac
}
EOF

  for invocation in check apply; do
    printf 'issue-prefix: original\n' > "${tmp}/.beads/config.yaml"
    out="$(mktemp "${TMPDIR:-/tmp}/scaffold-input-race-output.XXXXXX")"
    err="$(mktemp "${TMPDIR:-/tmp}/scaffold-input-race-error.XXXXXX")"
    if [[ "${invocation}" == "check" ]]; then
      args=(--check "${tmp}" all)
    else
      args=("${tmp}" all)
    fi
    if BASH_ENV="${bash_env}" \
      SCAFFOLD_INFERENCE_RACE_TARGET="${tmp}" \
      bash "${repo_root}/scripts/scaffold.sh" "${args[@]}" > "${out}" 2> "${err}"; then
      echo "changed Beads inference input should block scaffold ${invocation}" >&2
      exit 1
    fi
    require_text "target changed after preflight: .beads/config.yaml" "${err}"
    assert_tree_matches_snapshot \
      "${tmp}" \
      "${expected_snapshot}" \
      "changed Beads inference input (${invocation})"
    rm -f "${out}" "${err}"
  done

  rm -f "${bash_env}" "${expected_snapshot}"
  rm -rf "${expected}"
}

assert_unsearchable_destination_parent_blocks_without_writes() {
  local tmp="$1"

  mkdir -p "${tmp}/.claude"
  chmod 0200 "${tmp}/.claude"
  assert_scaffold_check_and_apply_fail_unchanged \
    "${repo_root}/scripts/scaffold.sh" \
    "${tmp}" \
    "unsearchable scaffold destination parent" \
    "destination parent is not searchable" \
    ".claude"
  chmod 0700 "${tmp}/.claude"
}

assert_invalid_generated_templates_block_without_writes() {
  local tmp="$1"
  local source_root="${tmp}/source"
  local json_target="${tmp}/json-target"
  local shell_target="${tmp}/shell-target"

  mkdir -p "${source_root}/scripts" "${source_root}/bootstrap-templates/templates"
  cp "${repo_root}/scripts/scaffold.sh" "${source_root}/scripts/scaffold.sh"
  cp -R \
    "${repo_root}/bootstrap-templates/templates/universal" \
    "${source_root}/bootstrap-templates/templates/"

  mkdir -p "${json_target}"
  printf 'target sentinel\n' > "${json_target}/sentinel.txt"
  printf '{ invalid generated json\n' \
    > "${source_root}/bootstrap-templates/templates/universal/beads/clone-contract.json.tmpl"
  assert_scaffold_check_and_apply_fail_unchanged \
    "${source_root}/scripts/scaffold.sh" \
    "${json_target}" \
    "invalid generated JSON" \
    "generated JSON" \
    ".beads/clone-contract.json"

  cp \
    "${repo_root}/bootstrap-templates/templates/universal/beads/clone-contract.json.tmpl" \
    "${source_root}/bootstrap-templates/templates/universal/beads/clone-contract.json.tmpl"
  mkdir -p "${shell_target}"
  printf 'target sentinel\n' > "${shell_target}/sentinel.txt"
  printf '\nif then\n' \
    >> "${source_root}/bootstrap-templates/templates/universal/githooks/pre-commit"
  assert_scaffold_check_and_apply_fail_unchanged \
    "${source_root}/scripts/scaffold.sh" \
    "${shell_target}" \
    "invalid generated shell" \
    "generated shell is invalid" \
    ".githooks/pre-commit"
}

assert_target_local_tmpdir_is_rejected_without_writes() {
  local tmp="$1"
  local before=""
  local out=""
  local err=""
  local invocation=""
  local -a args=()

  mkdir -p "${tmp}/tmp"
  printf 'target sentinel\n' > "${tmp}/sentinel.txt"
  for invocation in check apply; do
    before="$(mktemp "${TMPDIR:-/tmp}/scaffold-local-tmp-before.XXXXXX")"
    out="$(mktemp "${TMPDIR:-/tmp}/scaffold-local-tmp-output.XXXXXX")"
    err="$(mktemp "${TMPDIR:-/tmp}/scaffold-local-tmp-error.XXXXXX")"
    snapshot_tree "${tmp}" "${before}"
    if [[ "${invocation}" == "check" ]]; then
      args=(--check "${tmp}" all)
    else
      args=("${tmp}" all)
    fi
    if TMPDIR="${tmp}/tmp" bash "${repo_root}/scripts/scaffold.sh" "${args[@]}" > "${out}" 2> "${err}"; then
      echo "target-local TMPDIR should block scaffold ${invocation}" >&2
      exit 1
    fi
    require_text "TMPDIR must resolve outside the scaffold target" "${err}"
    assert_tree_matches_snapshot "${tmp}" "${before}" "target-local TMPDIR (${invocation})"
    rm -f "${before}" "${out}" "${err}"
  done
}

assert_explicit_hook_extensions_survive_refresh() {
  local tmp="$1"
  local state="${tmp}/.agent-scaffold.json"
  local prepare_local="${tmp}/.githooks/prepare-commit.local"
  local validate_local="${tmp}/.githooks/pre-commit.validate"
  local prepare_checksum=""
  local validate_checksum=""
  local before=""
  local out=""

  run_scaffold "${tmp}" "all"
  cat <<'EOF' > "${tmp}/.githooks/pre-commit"
#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/_common.sh"
"$(cd "$(dirname "$0")" && pwd)/beads-pre-commit.sh" "$@"

# Preserved from pre-existing .githooks/pre-commit during scaffold adoption.
"${repo_root}/scripts/check-production-vault.sh"
EOF
  chmod 0755 "${tmp}/.githooks/pre-commit"
  set_managed_checksum "${tmp}" ".githooks/pre-commit"
  assert_scaffold_check_and_apply_fail_unchanged \
    "${repo_root}/scripts/scaffold.sh" \
    "${tmp}" \
    "unresolved legacy hook before explicit classification" \
    "legacy managed combined hook"

  cp \
    "${repo_root}/bootstrap-templates/templates/universal/githooks/pre-commit" \
    "${tmp}/.githooks/pre-commit"
  chmod 0755 "${tmp}/.githooks/pre-commit"
  cat <<'EOF' > "${prepare_local}"
#!/usr/bin/env bash
set -euo pipefail
printf 'prepare local: %s\n' "$*"
EOF
  cat <<'EOF' > "${validate_local}"
#!/usr/bin/env bash
set -euo pipefail
printf 'validate local: %s\n' "$*"
EOF
  chmod +x "${prepare_local}" "${validate_local}"
  prepare_checksum="$(shasum -a 256 "${prepare_local}" | awk '{print $1}')"
  validate_checksum="$(shasum -a 256 "${validate_local}" | awk '{print $1}')"

  before="$(mktemp "${TMPDIR:-/tmp}/scaffold-resolved-hooks-before.XXXXXX")"
  out="$(mktemp "${TMPDIR:-/tmp}/scaffold-resolved-hooks-output.XXXXXX")"
  snapshot_tree "${tmp}" "${before}"
  bash "${repo_root}/scripts/scaffold.sh" --check "${tmp}" "all" > "${out}"
  require_text "Scaffold check passed." "${out}"
  assert_tree_matches_snapshot "${tmp}" "${before}" "resolved-hook scaffold check"

  jq '.variables.PROJECT_NAME = "UI Glitch Hunter, Inc.!"' "${state}" > "${state}.next"
  mv "${state}.next" "${state}"
  bash "${repo_root}/scripts/scaffold.sh" "${tmp}" "all" > "${out}"

  [[ -x "${prepare_local}" && -x "${validate_local}" ]] || {
    echo "scaffold refresh changed explicit hook-extension modes" >&2
    exit 1
  }
  [[ "$(shasum -a 256 "${prepare_local}" | awk '{print $1}')" == "${prepare_checksum}" ]] || {
    echo "scaffold refresh changed prepare-commit.local" >&2
    exit 1
  }
  [[ "$(shasum -a 256 "${validate_local}" | awk '{print $1}')" == "${validate_checksum}" ]] || {
    echo "scaffold refresh changed pre-commit.validate" >&2
    exit 1
  }
  cmp -s \
    "${repo_root}/bootstrap-templates/templates/universal/githooks/pre-commit" \
    "${tmp}/.githooks/pre-commit" || {
      echo "resolved hook refresh did not install the clean pre-commit dispatcher" >&2
      exit 1
    }
  cmp -s \
    "${repo_root}/bootstrap-templates/templates/universal/githooks/prepare-commit" \
    "${tmp}/.githooks/prepare-commit" || {
      echo "resolved hook refresh did not install prepare-commit" >&2
      exit 1
    }
  require_text "pre-commit.validate" "${tmp}/.githooks/pre-commit"
  forbid_text "pre-commit.local" "${tmp}/.githooks/pre-commit"
  forbid_text "# Preserved from pre-existing .githooks/pre-commit during scaffold adoption." \
    "${tmp}/.githooks/pre-commit"
  assert_managed_checksums_match "${tmp}"

  for path in \
    "${tmp}/.claude/skills/feature-start.md" \
    "${tmp}/.codex/skills/feature-start.md" \
    "${tmp}/.antigravity/skills/feature-start.md"; do
    require_text 'feature/<feature-slug>' "${path}"
    forbid_text 'feature/UI Glitch Hunter, Inc.!' "${path}"
  done
  git check-ref-format --branch "feature/ui-glitch-hunter-safety" >/dev/null

  rm -f "${before}" "${out}"
}

assert_drift_fails_loud() {
  local tmp="$1"
  local out=""
  local err=""

  out="$(mktemp "${TMPDIR:-/tmp}/scaffold-drift-output.XXXXXX")"
  err="$(mktemp "${TMPDIR:-/tmp}/scaffold-drift-error.XXXXXX")"
  printf '\n# local edit\n' >> "${tmp}/AGENTS.md"
  if bash "${repo_root}/scripts/scaffold.sh" "${tmp}" "all" > "${out}" 2> "${err}"; then
    echo "scaffold should have failed on local drift" >&2
    exit 1
  fi
  require_text "Refusing to overwrite drifted scaffold-managed files." "${err}"
  rm -f "${out}" "${err}"
}

assert_adoption_conflict_is_preserved() {
  local tmp="$1"
  local state="${tmp}/.agent-scaffold.json"
  local before=""
  local check_out=""
  local apply_out=""

  mkdir -p "${tmp}/.claude"
  cat <<'EOF' > "${tmp}/AGENTS.md"
# Legacy AGENTS
Keep this around.
EOF

  before="$(mktemp "${TMPDIR:-/tmp}/scaffold-adoption-check-before.XXXXXX")"
  check_out="$(mktemp "${TMPDIR:-/tmp}/scaffold-adoption-check-output.XXXXXX")"
  apply_out="$(mktemp "${TMPDIR:-/tmp}/scaffold-adoption-apply-output.XXXXXX")"
  snapshot_tree "${tmp}" "${before}"
  bash "${repo_root}/scripts/scaffold.sh" --check "${tmp}" "all" > "${check_out}"
  require_text "Scaffold check passed." "${check_out}"
  assert_tree_matches_snapshot "${tmp}" "${before}" "state-less adoption scaffold check"
  [[ ! -e "${tmp}/AGENTS.scaffold-candidate.md" ]] || {
    echo "scaffold --check created a state-less adoption candidate" >&2
    exit 1
  }

  bash "${repo_root}/scripts/scaffold.sh" "${tmp}" "all" > "${apply_out}"

  require_text "# Legacy AGENTS" "${tmp}/AGENTS.md"
  require_file "${tmp}/AGENTS.scaffold-candidate.md"
  require_text "# " "${tmp}/AGENTS.scaffold-candidate.md"
  jq -e '.adoptionConflicts | length == 1' "${state}" >/dev/null
  require_text "\"target\": \"AGENTS.md\"" "${state}"
  require_text "\"scaffoldCandidate\": \"AGENTS.scaffold-candidate.md\"" "${state}"
  require_text "\"targetChecksum\":" "${state}"
  require_text "\"candidateChecksum\":" "${state}"
  require_text "\"status\": \"unresolved\"" "${state}"
  require_text "AGENTS.md remains active; scaffold candidate: AGENTS.scaffold-candidate.md" "${apply_out}"
  require_text "Next step: run /resolve-adopted-artifacts before /bootstrap or another scaffold refresh." "${apply_out}"
  forbid_text "Next step: run /bootstrap in your agent harness" "${apply_out}"

  rm -f "${before}" "${check_out}" "${apply_out}"
}

assert_adoption_conflict_blocks_rerun() {
  local tmp="$1"
  local out=""
  local err=""

  out="$(mktemp "${TMPDIR:-/tmp}/scaffold-adoption-rerun-output.XXXXXX")"
  err="$(mktemp "${TMPDIR:-/tmp}/scaffold-adoption-rerun-error.XXXXXX")"
  if bash "${repo_root}/scripts/scaffold.sh" "${tmp}" "all" > "${out}" 2> "${err}"; then
    echo "scaffold should have failed with unresolved adoption conflicts" >&2
    exit 1
  fi

  require_text "unresolved adoption conflict" "${err}"
  require_text "/resolve-adopted-artifacts" "${err}"
  rm -f "${out}" "${err}"
}

assert_adoption_conflict_drift_fails_loud() {
  local tmp="$1"
  local out=""
  local err=""

  out="$(mktemp "${TMPDIR:-/tmp}/scaffold-adoption-drift-output.XXXXXX")"
  err="$(mktemp "${TMPDIR:-/tmp}/scaffold-adoption-drift-error.XXXXXX")"
  printf '\nchanged after capture\n' >> "${tmp}/AGENTS.md"
  if bash "${repo_root}/scripts/scaffold.sh" "${tmp}" "all" > "${out}" 2> "${err}"; then
    echo "scaffold should have failed when active conflict targets drifted" >&2
    exit 1
  fi

  require_text "active adoption-conflict target changed since capture" "${err}"
  rm -f "${out}" "${err}"
}

assert_adoption_conflict_resolution_unblocks_rerun() {
  local tmp="$1"
  local state="${tmp}/.agent-scaffold.json"
  local out=""

  mkdir -p "${tmp}/docs/legacy-agent-artifacts"
  mv "${tmp}/AGENTS.md" "${tmp}/docs/legacy-agent-artifacts/AGENTS.md"
  mv "${tmp}/AGENTS.scaffold-candidate.md" "${tmp}/AGENTS.md"
  jq 'del(.adoptionConflicts)' "${state}" > "${state}.next"
  mv "${state}.next" "${state}"

  out="$(mktemp "${TMPDIR:-/tmp}/scaffold-adoption-resolved-output.XXXXXX")"
  bash "${repo_root}/scripts/scaffold.sh" "${tmp}" "all" > "${out}"
  [[ ! -e "${tmp}/AGENTS.scaffold-candidate.md" ]] || {
    echo "resolved scaffold run should not recreate AGENTS.scaffold-candidate.md" >&2
    exit 1
  }
  require_file "${tmp}/docs/legacy-agent-artifacts/AGENTS.md"
  jq -e 'has("adoptionConflicts") | not' "${tmp}/.agent-scaffold.json" >/dev/null
  rm -f "${out}"
}

assert_existing_beads_contract_is_inferred() {
  local tmp="$1"
  local state="${tmp}/.agent-scaffold.json"
  local legacy_checksum=""
  local bd_log="${tmp}.bd-invocations"
  local before=""
  local check_out=""
  local apply_out=""

  mkdir -p "${tmp}/.beads" "${tmp}/.githooks" "${tmp}/scripts" "${tmp}/bin"
  cat <<'EOF' > "${tmp}/.beads/config.yaml"
issue-prefix: ghq
EOF
  cat <<'EOF' > "${tmp}/.beads/clone-contract.json"
{
  "mode": "bootstrap_required",
  "backend": "dolt",
  "issue_prefix": "ghq",
  "jsonl_export": ".beads/issues.jsonl",
  "bootstrap_commands": [
    "bd init -p ghq --skip-agents --skip-hooks --json",
    "bd import .beads/issues.jsonl --json",
    "git config core.hooksPath .githooks"
  ],
  "read_probe": "bd status --json"
}
EOF
  cat <<'EOF' > "${tmp}/.githooks/beads-pre-commit.sh"
#!/usr/bin/env bash
set -euo pipefail
echo old beads hook
EOF
  chmod +x "${tmp}/.githooks/beads-pre-commit.sh"
  cat <<'EOF' > "${tmp}/.githooks/pre-commit"
#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

"$(cd "$(dirname "$0")" && pwd)/beads-pre-commit.sh" "$@"
if [[ -x "${repo_root}/scripts/secrets-validate" ]]; then
  "${repo_root}/scripts/secrets-validate" --mode pre-commit --repo-root "${repo_root}"
  if [[ -x "${repo_root}/scripts/lint" ]]; then
    "${repo_root}/scripts/lint" --fix
  fi
fi
if ! command -v bd >/dev/null 2>&1; then
  echo "Warning: bd command not found in PATH, skipping Beads pre-commit hook" >&2
  exit 0
fi
echo "Refreshing Beads tracker exports..."
bd export -o .beads/issues.jsonl >/dev/null
export BD_GIT_HOOK=1
BD_HOOK_EXIT=0
bd hooks run pre-commit "$@" || BD_HOOK_EXIT=$?
exit "${BD_HOOK_EXIT}"
EOF
  chmod +x "${tmp}/.githooks/pre-commit"
  bash -n "${tmp}/.githooks/pre-commit"
  legacy_checksum="$(shasum -a 256 "${tmp}/.githooks/pre-commit" | awk '{print $1}')"
  cat <<'EOF' > "${tmp}/bin/bd"
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "${BD_INVOCATION_LOG:?}"
exit 1
EOF
  chmod +x "${tmp}/bin/bd"

  : > "${bd_log}"
  before="$(mktemp "${TMPDIR:-/tmp}/scaffold-existing-beads-before.XXXXXX")"
  check_out="$(mktemp "${TMPDIR:-/tmp}/scaffold-existing-beads-check.XXXXXX")"
  apply_out="$(mktemp "${TMPDIR:-/tmp}/scaffold-existing-beads-apply.XXXXXX")"
  snapshot_tree "${tmp}" "${before}"
  PATH="${tmp}/bin:${PATH}" \
    BD_INVOCATION_LOG="${bd_log}" \
    bash "${repo_root}/scripts/scaffold.sh" --check "${tmp}" "all" > "${check_out}"
  assert_tree_matches_snapshot "${tmp}" "${before}" "existing Beads contract check"
  [[ ! -s "${bd_log}" ]] || {
    echo "scaffold --check invoked the Beads runtime" >&2
    exit 1
  }

  PATH="${tmp}/bin:${PATH}" \
    BD_INVOCATION_LOG="${bd_log}" \
    bash "${repo_root}/scripts/scaffold.sh" "${tmp}" "all" > "${apply_out}"

  [[ "$(shasum -a 256 "${tmp}/.githooks/pre-commit" | awk '{print $1}')" == "${legacy_checksum}" ]] || {
    echo "active legacy pre-commit hook changed during adoption" >&2
    exit 1
  }
  jq -e '.variables.BEADS_PREFIX == "ghq"' "${state}" >/dev/null
  require_file "${tmp}/.beads/config.scaffold-candidate.yaml"
  require_text "issue-prefix: ghq" "${tmp}/.beads/config.scaffold-candidate.yaml"

  require_file "${tmp}/.beads/clone-contract.scaffold-candidate.json"
  jq -e '.issue_prefix == "ghq"' "${tmp}/.beads/clone-contract.scaffold-candidate.json" >/dev/null
  jq -e '.jsonl_export == ".beads/issues.jsonl"' "${tmp}/.beads/clone-contract.scaffold-candidate.json" >/dev/null
  jq -e '.bootstrap_commands == [
    "bd init -p ghq --skip-agents --skip-hooks --json",
    "bd import .beads/issues.jsonl --json",
    "git config core.hooksPath .githooks"
  ]' "${tmp}/.beads/clone-contract.scaffold-candidate.json" >/dev/null
  jq -e '.stale_runtime_recovery.local_pins | index(".beads/dolt-server.port")' "${tmp}/.beads/clone-contract.scaffold-candidate.json" >/dev/null

  require_file "${tmp}/.githooks/pre-commit.scaffold-candidate"
  require_text "pre-commit.validate" "${tmp}/.githooks/pre-commit.scaffold-candidate"
  forbid_text "pre-commit.local" "${tmp}/.githooks/pre-commit.scaffold-candidate"
  require_text "beads-pre-commit.sh" "${tmp}/.githooks/pre-commit.scaffold-candidate"
  forbid_text "Preserved from pre-existing .githooks/pre-commit" "${tmp}/.githooks/pre-commit.scaffold-candidate"
  forbid_text 'scripts/secrets-validate' "${tmp}/.githooks/pre-commit.scaffold-candidate"
  forbid_text 'scripts/lint' "${tmp}/.githooks/pre-commit.scaffold-candidate"
  forbid_text "Refreshing Beads tracker exports" "${tmp}/.githooks/pre-commit.scaffold-candidate"
  forbid_text "bd export -o .beads/issues.jsonl" "${tmp}/.githooks/pre-commit.scaffold-candidate"
  forbid_text "BD_HOOK_EXIT" "${tmp}/.githooks/pre-commit.scaffold-candidate"
  bash -n "${tmp}/.githooks/pre-commit.scaffold-candidate"

  require_file "${tmp}/.githooks/beads-pre-commit.scaffold-candidate.sh"
  require_text 'git cat-file blob ":${beads_snapshot_relative}"' "${tmp}/.githooks/beads-pre-commit.scaffold-candidate.sh"
  require_text "does not match the live tracker export" "${tmp}/.githooks/beads-pre-commit.scaffold-candidate.sh"

  jq -e '.adoptionConflicts | map(.target) |
    index(".beads/config.yaml") and
    index(".beads/clone-contract.json") and
    index(".githooks/pre-commit") and
    index(".githooks/beads-pre-commit.sh")' "${state}" >/dev/null

  rm -f \
    "${before}" \
    "${bd_log}" \
    "${check_out}" \
    "${apply_out}"
}

assert_prepare_and_validate_contract() {
  local tmp="$1"
  local hook_log="${tmp}/hook.log"
  local hook_tmp="${tmp}/hook-tmp"
  local stub_bin="${tmp}/stub-bin"
  local prepare_local="${tmp}/.githooks/prepare-commit.local"
  local validate_local="${tmp}/.githooks/pre-commit.validate"
  local index_tree_before=""
  local cached_names_before=""
  local snapshot_checksum=""
  local snapshot_index_contents=""
  local hook_status=0
  local alternate_index=""
  local alternate_checksum=""
  local err=""

  run_scaffold "${tmp}" "all"
  mkdir -p "${stub_bin}" "${hook_tmp}"

  cat <<'EOF' > "${stub_bin}/bd"
#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
  hooks)
    [[ "${BD_GIT_HOOK:-}" == "1" ]] || {
      echo "bd hooks smoke invocation is missing BD_GIT_HOOK=1" >&2
      exit 2
    }
    [[ "${BD_EXPORT_AUTO:-}" == "false" && "${BD_EXPORT_GIT_ADD:-}" == "false" ]] || {
      echo "bd hooks smoke invocation did not disable automatic export/staging" >&2
      exit 2
    }
    printf 'bd-hooks:%s\n' "$*" >> "${HOOK_BEHAVIOR_LOG:?}"
    ;;
  export)
    if [[ "$*" == "export --help" ]]; then
      if [[ "${BD_HELP_HAS_NO_MEMORIES:-true}" == "true" ]]; then
        printf 'Usage: bd export [--no-memories] -o FILE\n'
      else
        printf 'Usage: bd export -o FILE\n'
      fi
      exit 0
    fi
    [[ "${BD_GIT_HOOK:-}" == "1" ]] || {
      echo "bd export smoke invocation is missing BD_GIT_HOOK=1" >&2
      exit 2
    }
    [[ "${BD_EXPORT_AUTO:-}" == "false" && "${BD_EXPORT_GIT_ADD:-}" == "false" ]] || {
      echo "bd export smoke invocation did not disable automatic export/staging" >&2
      exit 2
    }
    printf 'bd-export:%s\n' "$*" >> "${HOOK_BEHAVIOR_LOG:?}"
    output=""
    shift
    while [[ "$#" -gt 0 ]]; do
      case "$1" in
        -o)
          shift
          output="${1:?missing export output path}"
          ;;
      esac
      shift || true
    done
    [[ -n "${output}" ]] || {
      echo "bd smoke stub did not receive an export output path" >&2
      exit 2
    }
    printf '{"id":"prepared"}\n' > "${output}"
    ;;
  *)
    echo "unexpected bd smoke invocation: $*" >&2
    exit 2
    ;;
esac
EOF
  chmod +x "${stub_bin}/bd"

  cat <<'EOF' > "${prepare_local}"
#!/usr/bin/env bash
set -euo pipefail
printf 'prepare-local:%s\n' "$*" >> "${HOOK_BEHAVIOR_LOG:?}"
printf 'prepared by local hook\n' >> generated.txt
EOF
  cat <<'EOF' > "${validate_local}"
#!/usr/bin/env bash
set -euo pipefail
printf 'validate:%s\n' "$*" >> "${HOOK_BEHAVIOR_LOG:?}"
EOF
  chmod +x "${prepare_local}" "${validate_local}"

  printf '{"id":"stale"}\n' > "${tmp}/.beads/issues.jsonl"
  printf 'generated baseline\n' > "${tmp}/generated.txt"
  printf 'source baseline\n' > "${tmp}/source.txt"
  : > "${hook_log}"

  git -C "${tmp}" init -q
  git -C "${tmp}" config user.name "Scaffold Smoke"
  git -C "${tmp}" config user.email "scaffold-smoke@example.com"
  git -C "${tmp}" config core.hooksPath .git/hooks
  git -C "${tmp}" add -A
  git -C "${tmp}" commit -q -m "test: initialize hook contract fixture"

  printf 'source change\n' >> "${tmp}/source.txt"
  git -C "${tmp}" add source.txt
  index_tree_before="$(git -C "${tmp}" write-tree)"
  cached_names_before="$(git -C "${tmp}" diff --cached --name-status)"
  snapshot_checksum="$(shasum -a 256 "${tmp}/.beads/issues.jsonl" | awk '{print $1}')"
  snapshot_index_contents="$(git -C "${tmp}" show :.beads/issues.jsonl)"

  chmod 644 "${prepare_local}"
  : > "${hook_log}"
  err="$(mktemp "${TMPDIR:-/tmp}/scaffold-prepare-mode-error.XXXXXX")"
  hook_status=0
  (
    cd "${tmp}"
    PATH="${stub_bin}:${PATH}" \
      TMPDIR="${hook_tmp}" \
      HOOK_BEHAVIOR_LOG="${hook_log}" \
      .githooks/prepare-commit non-executable
  ) > /dev/null 2> "${err}" || hook_status=$?
  [[ "${hook_status}" -ne 0 ]] || {
    echo "prepare-commit should reject a non-executable prepare-commit.local" >&2
    exit 1
  }
  require_text "regular executable file" "${err}"
  [[ ! -s "${hook_log}" ]] || {
    echo "prepare-commit ran project or Beads work with a non-executable extension" >&2
    exit 1
  }
  [[ "$(git -C "${tmp}" write-tree)" == "${index_tree_before}" ]] || {
    echo "non-executable prepare extension changed the Git index" >&2
    exit 1
  }
  chmod +x "${prepare_local}"
  rm -f "${err}"

  chmod 644 "${validate_local}"
  : > "${hook_log}"
  err="$(mktemp "${TMPDIR:-/tmp}/scaffold-validate-mode-error.XXXXXX")"
  hook_status=0
  (
    cd "${tmp}"
    PATH="${stub_bin}:${PATH}" \
      TMPDIR="${hook_tmp}" \
      HOOK_BEHAVIOR_LOG="${hook_log}" \
      .githooks/pre-commit non-executable
  ) > /dev/null 2> "${err}" || hook_status=$?
  [[ "${hook_status}" -ne 0 ]] || {
    echo "pre-commit should reject a non-executable pre-commit.validate" >&2
    exit 1
  }
  require_text "regular executable file" "${err}"
  [[ ! -s "${hook_log}" ]] || {
    echo "pre-commit ran project or Beads work with a non-executable validator" >&2
    exit 1
  }
  [[ "$(git -C "${tmp}" write-tree)" == "${index_tree_before}" ]] || {
    echo "non-executable validator changed the Git index" >&2
    exit 1
  }
  chmod +x "${validate_local}"
  rm -f "${err}"

  mv "${prepare_local}" "${prepare_local}.saved"
  mkdir "${prepare_local}"
  : > "${hook_log}"
  err="$(mktemp "${TMPDIR:-/tmp}/scaffold-prepare-directory-error.XXXXXX")"
  hook_status=0
  (
    cd "${tmp}"
    PATH="${stub_bin}:${PATH}" \
      TMPDIR="${hook_tmp}" \
      HOOK_BEHAVIOR_LOG="${hook_log}" \
      .githooks/prepare-commit directory-extension
  ) > /dev/null 2> "${err}" || hook_status=$?
  [[ "${hook_status}" -ne 0 ]] || {
    echo "prepare-commit should reject a directory at prepare-commit.local" >&2
    exit 1
  }
  require_text "regular executable file" "${err}"
  [[ ! -s "${hook_log}" ]] || {
    echo "prepare-commit ran project or Beads work with a directory extension" >&2
    exit 1
  }
  rmdir "${prepare_local}"
  mv "${prepare_local}.saved" "${prepare_local}"
  rm -f "${err}"

  mv "${validate_local}" "${validate_local}.saved"
  mkdir "${validate_local}"
  : > "${hook_log}"
  err="$(mktemp "${TMPDIR:-/tmp}/scaffold-validate-directory-error.XXXXXX")"
  hook_status=0
  (
    cd "${tmp}"
    PATH="${stub_bin}:${PATH}" \
      TMPDIR="${hook_tmp}" \
      HOOK_BEHAVIOR_LOG="${hook_log}" \
      .githooks/pre-commit directory-extension
  ) > /dev/null 2> "${err}" || hook_status=$?
  [[ "${hook_status}" -ne 0 ]] || {
    echo "pre-commit should reject a directory at pre-commit.validate" >&2
    exit 1
  }
  require_text "regular executable file" "${err}"
  [[ ! -s "${hook_log}" ]] || {
    echo "pre-commit ran project or Beads work with a directory validator" >&2
    exit 1
  }
  rmdir "${validate_local}"
  mv "${validate_local}.saved" "${validate_local}"
  rm -f "${err}"
  [[ "$(git -C "${tmp}" write-tree)" == "${index_tree_before}" ]] || {
    echo "directory hook-extension rejection changed the Git index" >&2
    exit 1
  }
  [[ "$(shasum -a 256 "${tmp}/.beads/issues.jsonl" | awk '{print $1}')" == "${snapshot_checksum}" ]] || {
    echo "invalid hook-extension rejection rewrote the working snapshot" >&2
    exit 1
  }

  mv "${prepare_local}" "${prepare_local}.saved"
  ln -s "${prepare_local}.saved" "${prepare_local}"
  : > "${hook_log}"
  err="$(mktemp "${TMPDIR:-/tmp}/scaffold-prepare-symlink-error.XXXXXX")"
  hook_status=0
  (
    cd "${tmp}"
    PATH="${stub_bin}:${PATH}" \
      TMPDIR="${hook_tmp}" \
      HOOK_BEHAVIOR_LOG="${hook_log}" \
      .githooks/prepare-commit symlink-extension
  ) > /dev/null 2> "${err}" || hook_status=$?
  [[ "${hook_status}" -ne 0 ]] || {
    echo "prepare-commit should reject a symlink at prepare-commit.local" >&2
    exit 1
  }
  require_text "regular executable file" "${err}"
  [[ ! -s "${hook_log}" ]] || {
    echo "prepare-commit ran project or Beads work through a symlink extension" >&2
    exit 1
  }
  rm "${prepare_local}"
  mv "${prepare_local}.saved" "${prepare_local}"
  rm -f "${err}"

  mv "${validate_local}" "${validate_local}.saved"
  ln -s "${validate_local}.saved" "${validate_local}"
  : > "${hook_log}"
  err="$(mktemp "${TMPDIR:-/tmp}/scaffold-validate-symlink-error.XXXXXX")"
  hook_status=0
  (
    cd "${tmp}"
    PATH="${stub_bin}:${PATH}" \
      TMPDIR="${hook_tmp}" \
      HOOK_BEHAVIOR_LOG="${hook_log}" \
      .githooks/pre-commit symlink-extension
  ) > /dev/null 2> "${err}" || hook_status=$?
  [[ "${hook_status}" -ne 0 ]] || {
    echo "pre-commit should reject a symlink at pre-commit.validate" >&2
    exit 1
  }
  require_text "regular executable file" "${err}"
  [[ ! -s "${hook_log}" ]] || {
    echo "pre-commit ran project or Beads validation through a symlink extension" >&2
    exit 1
  }
  rm "${validate_local}"
  mv "${validate_local}.saved" "${validate_local}"
  rm -f "${err}"
  [[ "$(git -C "${tmp}" write-tree)" == "${index_tree_before}" ]] || {
    echo "symlink hook-extension rejection changed the Git index" >&2
    exit 1
  }

  err="$(mktemp "${TMPDIR:-/tmp}/scaffold-stale-working-error.XXXXXX")"
  hook_status=0
  (
    cd "${tmp}"
    PATH="${stub_bin}:${PATH}" \
      TMPDIR="${hook_tmp}" \
      HOOK_BEHAVIOR_LOG="${hook_log}" \
      .githooks/pre-commit stale-working
  ) > /dev/null 2> "${err}" || hook_status=$?
  [[ "${hook_status}" -ne 0 ]] || {
    echo "pre-commit validation should reject a stale working Beads snapshot" >&2
    exit 1
  }
  require_text ".githooks/prepare-commit" "${err}"
  [[ "$(sed -n '1p' "${hook_log}")" == "validate:stale-working" ]] || {
    echo "project validator did not run before stale-snapshot validation" >&2
    exit 1
  }
  [[ "$(sed -n '2p' "${hook_log}")" == bd-export:* ]] || {
    echo "Beads validation did not export after the project validator" >&2
    exit 1
  }
  [[ "$(wc -l < "${hook_log}" | tr -d ' ')" == "2" ]] || {
    echo "unexpected hook work ran during stale-snapshot validation" >&2
    exit 1
  }
  [[ "$(git -C "${tmp}" write-tree)" == "${index_tree_before}" ]] || {
    echo "stale working-snapshot validation changed the Git index" >&2
    exit 1
  }
  [[ "$(shasum -a 256 "${tmp}/.beads/issues.jsonl" | awk '{print $1}')" == "${snapshot_checksum}" ]] || {
    echo "stale working-snapshot validation rewrote the working snapshot" >&2
    exit 1
  }
  [[ -z "$(find "${hook_tmp}" -mindepth 1 -print -quit)" ]] || {
    echo "stale working-snapshot validation leaked temporary files" >&2
    exit 1
  }
  rm -f "${err}"

  : > "${hook_log}"
  index_tree_before="$(git -C "${tmp}" write-tree)"
  cached_names_before="$(git -C "${tmp}" diff --cached --name-status)"
  (
    cd "${tmp}"
    PATH="${stub_bin}:${PATH}" \
      TMPDIR="${hook_tmp}" \
      HOOK_BEHAVIOR_LOG="${hook_log}" \
      .githooks/prepare-commit prepare-arg
  ) >/dev/null
  [[ "$(sed -n '1p' "${hook_log}")" == "prepare-local:prepare-arg" ]] || {
    echo "prepare-commit.local did not receive the original arguments first" >&2
    exit 1
  }
  [[ "$(sed -n '2p' "${hook_log}")" == "bd-hooks:hooks run pre-commit prepare-arg" ]] || {
    echo "Beads preparation did not run after prepare-commit.local" >&2
    exit 1
  }
  [[ "$(sed -n '3p' "${hook_log}")" == "bd-export:export --no-memories -o "* ]] || {
    echo "Beads export did not use the advertised --no-memories capability" >&2
    exit 1
  }
  [[ "$(wc -l < "${hook_log}" | tr -d ' ')" == "3" ]] || {
    echo "unexpected work ran during commit preparation" >&2
    exit 1
  }
  [[ "$(git -C "${tmp}" write-tree)" == "${index_tree_before}" ]] || {
    echo "prepare-commit changed the Git index" >&2
    exit 1
  }
  [[ "$(git -C "${tmp}" diff --cached --name-status)" == "${cached_names_before}" ]] || {
    echo "prepare-commit changed the staged path set" >&2
    exit 1
  }
  require_text "prepared by local hook" "${tmp}/generated.txt"
  require_text '{"id":"prepared"}' "${tmp}/.beads/issues.jsonl"
  [[ "$(git -C "${tmp}" show :.beads/issues.jsonl)" == "${snapshot_index_contents}" ]] || {
    echo "prepare-commit staged the refreshed Beads snapshot" >&2
    exit 1
  }

  : > "${hook_log}"
  (
    cd "${tmp}"
    PATH="${stub_bin}:${PATH}" \
      TMPDIR="${hook_tmp}" \
      HOOK_BEHAVIOR_LOG="${hook_log}" \
      BD_HELP_HAS_NO_MEMORIES=false \
      .githooks/prepare-commit legacy-export-help
  ) >/dev/null
  [[ "$(sed -n '3p' "${hook_log}")" == "bd-export:export -o "* ]] || {
    echo "Beads export did not omit --no-memories when help did not advertise it" >&2
    exit 1
  }
  forbid_text "--no-memories" "${hook_log}"
  [[ "$(git -C "${tmp}" write-tree)" == "${index_tree_before}" ]] || {
    echo "legacy Beads export preparation changed the Git index" >&2
    exit 1
  }

  snapshot_checksum="$(shasum -a 256 "${tmp}/.beads/issues.jsonl" | awk '{print $1}')"
  : > "${hook_log}"
  err="$(mktemp "${TMPDIR:-/tmp}/scaffold-stale-index-error.XXXXXX")"
  hook_status=0
  (
    cd "${tmp}"
    PATH="${stub_bin}:${PATH}" \
      TMPDIR="${hook_tmp}" \
      HOOK_BEHAVIOR_LOG="${hook_log}" \
      .githooks/pre-commit stale-index
  ) > /dev/null 2> "${err}" || hook_status=$?
  [[ "${hook_status}" -ne 0 ]] || {
    echo "pre-commit validation should reject a stale staged Beads snapshot" >&2
    exit 1
  }
  require_text "staged .beads/issues.jsonl does not match" "${err}"
  [[ "$(git -C "${tmp}" write-tree)" == "${index_tree_before}" ]] || {
    echo "stale staged-snapshot validation changed the Git index" >&2
    exit 1
  }
  [[ "$(shasum -a 256 "${tmp}/.beads/issues.jsonl" | awk '{print $1}')" == "${snapshot_checksum}" ]] || {
    echo "stale staged-snapshot validation rewrote the working snapshot" >&2
    exit 1
  }
  [[ -z "$(find "${hook_tmp}" -mindepth 1 -print -quit)" ]] || {
    echo "stale staged-snapshot validation leaked temporary files" >&2
    exit 1
  }
  rm -f "${err}"

  git -C "${tmp}" add .beads/issues.jsonl
  index_tree_before="$(git -C "${tmp}" write-tree)"
  cached_names_before="$(git -C "${tmp}" diff --cached --name-status)"
  snapshot_checksum="$(shasum -a 256 "${tmp}/.beads/issues.jsonl" | awk '{print $1}')"
  : > "${hook_log}"
  (
    cd "${tmp}"
    PATH="${stub_bin}:${PATH}" \
      TMPDIR="${hook_tmp}" \
      HOOK_BEHAVIOR_LOG="${hook_log}" \
      .githooks/pre-commit validation-arg
  ) >/dev/null
  [[ "$(sed -n '1p' "${hook_log}")" == "validate:validation-arg" ]] || {
    echo "pre-commit.validate did not receive the original arguments first" >&2
    exit 1
  }
  [[ "$(sed -n '2p' "${hook_log}")" == bd-export:* ]] || {
    echo "Beads snapshot validation did not run after pre-commit.validate" >&2
    exit 1
  }
  [[ "$(git -C "${tmp}" write-tree)" == "${index_tree_before}" ]] || {
    echo "successful pre-commit validation changed the Git index" >&2
    exit 1
  }
  [[ "$(git -C "${tmp}" diff --cached --name-status)" == "${cached_names_before}" ]] || {
    echo "successful pre-commit validation changed the staged path set" >&2
    exit 1
  }
  [[ "$(shasum -a 256 "${tmp}/.beads/issues.jsonl" | awk '{print $1}')" == "${snapshot_checksum}" ]] || {
    echo "successful pre-commit validation rewrote the working snapshot" >&2
    exit 1
  }
  [[ -z "$(find "${hook_tmp}" -mindepth 1 -print -quit)" ]] || {
    echo "successful pre-commit validation leaked temporary files" >&2
    exit 1
  }

  cat <<'EOF' > "${prepare_local}"
#!/usr/bin/env bash
set -euo pipefail
printf 'prepare-failed:%s\n' "$*" >> "${HOOK_BEHAVIOR_LOG:?}"
exit 23
EOF
  chmod +x "${prepare_local}"
  : > "${hook_log}"
  index_tree_before="$(git -C "${tmp}" write-tree)"
  hook_status=0
  (
    cd "${tmp}"
    PATH="${stub_bin}:${PATH}" \
      TMPDIR="${hook_tmp}" \
      HOOK_BEHAVIOR_LOG="${hook_log}" \
      .githooks/prepare-commit local-failure
  ) >/dev/null 2>&1 || hook_status=$?
  [[ "${hook_status}" -eq 23 ]] || {
    echo "prepare-commit did not preserve prepare-commit.local failure status" >&2
    exit 1
  }
  [[ "$(cat "${hook_log}")" == "prepare-failed:local-failure" ]] || {
    echo "Beads preparation ran after prepare-commit.local failed" >&2
    exit 1
  }
  [[ "$(git -C "${tmp}" write-tree)" == "${index_tree_before}" ]] || {
    echo "failing prepare-commit.local changed the Git index" >&2
    exit 1
  }

  printf 'unstaged generator change\n' >> "${tmp}/generated.txt"
  cat <<'EOF' > "${prepare_local}"
#!/usr/bin/env bash
set -euo pipefail
printf 'prepare-index-mutation:%s\n' "$*" >> "${HOOK_BEHAVIOR_LOG:?}"
git add generated.txt
EOF
  chmod +x "${prepare_local}"
  : > "${hook_log}"
  index_tree_before="$(git -C "${tmp}" write-tree)"
  err="$(mktemp "${TMPDIR:-/tmp}/scaffold-prepare-index-error.XXXXXX")"
  hook_status=0
  (
    cd "${tmp}"
    PATH="${stub_bin}:${PATH}" \
      TMPDIR="${hook_tmp}" \
      HOOK_BEHAVIOR_LOG="${hook_log}" \
      .githooks/prepare-commit index-mutation
  ) > /dev/null 2> "${err}" || hook_status=$?
  [[ "${hook_status}" -ne 0 ]] || {
    echo "prepare-commit should reject local Git-index mutation" >&2
    exit 1
  }
  require_text "modified the Git index" "${err}"
  [[ "$(cat "${hook_log}")" == "prepare-index-mutation:index-mutation" ]] || {
    echo "Beads preparation ran after prepare-commit.local changed the index" >&2
    exit 1
  }
  git -C "${tmp}" reset -q -- generated.txt
  [[ "$(git -C "${tmp}" write-tree)" == "${index_tree_before}" ]] || {
    echo "prepare-commit index-mutation fixture could not restore the intended index" >&2
    exit 1
  }
  rm -f "${err}"

  cat <<'EOF' > "${prepare_local}"
#!/usr/bin/env bash
set -euo pipefail
printf 'prepare-local:%s\n' "$*" >> "${HOOK_BEHAVIOR_LOG:?}"
printf 'prepared by local hook\n' >> generated.txt
EOF
  cat <<'EOF' > "${validate_local}"
#!/usr/bin/env bash
set -euo pipefail
printf 'validate-failed:%s\n' "$*" >> "${HOOK_BEHAVIOR_LOG:?}"
exit 31
EOF
  chmod +x "${prepare_local}" "${validate_local}"
  : > "${hook_log}"
  index_tree_before="$(git -C "${tmp}" write-tree)"
  hook_status=0
  (
    cd "${tmp}"
    PATH="${stub_bin}:${PATH}" \
      TMPDIR="${hook_tmp}" \
      HOOK_BEHAVIOR_LOG="${hook_log}" \
      .githooks/pre-commit validator-failure
  ) >/dev/null 2>&1 || hook_status=$?
  [[ "${hook_status}" -eq 31 ]] || {
    echo "pre-commit did not preserve pre-commit.validate failure status" >&2
    exit 1
  }
  [[ "$(cat "${hook_log}")" == "validate-failed:validator-failure" ]] || {
    echo "Beads validation ran after pre-commit.validate failed" >&2
    exit 1
  }
  [[ "$(git -C "${tmp}" write-tree)" == "${index_tree_before}" ]] || {
    echo "failing pre-commit.validate changed the Git index" >&2
    exit 1
  }

  printf 'validator worktree change\n' >> "${tmp}/generated.txt"
  cat <<'EOF' > "${validate_local}"
#!/usr/bin/env bash
set -euo pipefail
printf 'validate-index-mutation:%s\n' "$*" >> "${HOOK_BEHAVIOR_LOG:?}"
git add generated.txt
EOF
  chmod +x "${validate_local}"
  : > "${hook_log}"
  index_tree_before="$(git -C "${tmp}" write-tree)"
  err="$(mktemp "${TMPDIR:-/tmp}/scaffold-validate-index-error.XXXXXX")"
  hook_status=0
  (
    cd "${tmp}"
    PATH="${stub_bin}:${PATH}" \
      TMPDIR="${hook_tmp}" \
      HOOK_BEHAVIOR_LOG="${hook_log}" \
      .githooks/pre-commit validator-index-mutation
  ) > /dev/null 2> "${err}" || hook_status=$?
  [[ "${hook_status}" -ne 0 ]] || {
    echo "pre-commit should reject validator Git-index mutation" >&2
    exit 1
  }
  require_text "modified the Git index" "${err}"
  [[ "$(cat "${hook_log}")" == "validate-index-mutation:validator-index-mutation" ]] || {
    echo "Beads validation ran after pre-commit.validate changed the index" >&2
    exit 1
  }
  git -C "${tmp}" reset -q -- generated.txt
  [[ "$(git -C "${tmp}" write-tree)" == "${index_tree_before}" ]] || {
    echo "validator index-mutation fixture could not restore the intended index" >&2
    exit 1
  }
  rm -f "${err}"

  cat <<'EOF' > "${validate_local}"
#!/usr/bin/env bash
set -euo pipefail
printf 'validate:%s\n' "$*" >> "${HOOK_BEHAVIOR_LOG:?}"
EOF
  chmod +x "${validate_local}"

  alternate_index="${tmp}/alternate-index"
  cp "$(git -C "${tmp}" rev-parse --absolute-git-dir)/index" "${alternate_index}"
  alternate_checksum="$(shasum -a 256 "${alternate_index}" | awk '{print $1}')"
  index_tree_before="$(git -C "${tmp}" write-tree)"

  : > "${hook_log}"
  err="$(mktemp "${TMPDIR:-/tmp}/scaffold-prepare-alternate-index-error.XXXXXX")"
  hook_status=0
  (
    cd "${tmp}"
    PATH="${stub_bin}:${PATH}" \
      TMPDIR="${hook_tmp}" \
      HOOK_BEHAVIOR_LOG="${hook_log}" \
      GIT_INDEX_FILE="${alternate_index}" \
      .githooks/prepare-commit alternate-index
  ) > /dev/null 2> "${err}" || hook_status=$?
  [[ "${hook_status}" -ne 0 ]] || {
    echo "prepare-commit should reject an alternate Git index" >&2
    exit 1
  }
  require_text "alternate Git index" "${err}"
  [[ ! -s "${hook_log}" ]] || {
    echo "prepare-commit ran project or Beads work with an alternate index" >&2
    exit 1
  }
  [[ "$(shasum -a 256 "${alternate_index}" | awk '{print $1}')" == "${alternate_checksum}" ]] || {
    echo "prepare-commit changed the alternate Git index" >&2
    exit 1
  }
  [[ "$(git -C "${tmp}" write-tree)" == "${index_tree_before}" ]] || {
    echo "prepare-commit changed the main Git index while rejecting an alternate index" >&2
    exit 1
  }
  rm -f "${err}"

  : > "${hook_log}"
  err="$(mktemp "${TMPDIR:-/tmp}/scaffold-validate-alternate-index-error.XXXXXX")"
  hook_status=0
  (
    cd "${tmp}"
    PATH="${stub_bin}:${PATH}" \
      TMPDIR="${hook_tmp}" \
      HOOK_BEHAVIOR_LOG="${hook_log}" \
      GIT_INDEX_FILE="${alternate_index}" \
      .githooks/pre-commit alternate-index
  ) > /dev/null 2> "${err}" || hook_status=$?
  [[ "${hook_status}" -ne 0 ]] || {
    echo "pre-commit should reject an alternate Git index" >&2
    exit 1
  }
  require_text "alternate Git index" "${err}"
  [[ ! -s "${hook_log}" ]] || {
    echo "pre-commit ran project or Beads validation with an alternate index" >&2
    exit 1
  }
  [[ "$(shasum -a 256 "${alternate_index}" | awk '{print $1}')" == "${alternate_checksum}" ]] || {
    echo "pre-commit changed the alternate Git index" >&2
    exit 1
  }
  [[ "$(git -C "${tmp}" write-tree)" == "${index_tree_before}" ]] || {
    echo "pre-commit changed the main Git index while rejecting an alternate index" >&2
    exit 1
  }
  rm -f "${err}"
}

assert_beads_snapshot_symlink_is_rejected() {
  local tmp="$1"
  local stub_bin="${tmp}/stub-bin"
  local bd_log="${tmp}/bd.log"
  local outside="${tmp}.outside-snapshot"
  local outside_checksum=""
  local before=""
  local err=""
  local index_tree=""
  local hook=""

  run_scaffold "${tmp}" "all"
  mkdir -p "${stub_bin}"
  cat <<'EOF' > "${stub_bin}/bd"
#!/usr/bin/env bash
set -euo pipefail
printf 'unexpected bd invocation: %s\n' "$*" >> "${UNEXPECTED_BD_LOG:?}"
exit 99
EOF
  chmod 0755 "${stub_bin}/bd"
  : > "${bd_log}"
  printf 'external snapshot sentinel\n' > "${outside}"
  outside_checksum="$(shasum -a 256 "${outside}" | awk '{print $1}')"
  ln -s "${outside}" "${tmp}/.beads/issues.jsonl"

  git -C "${tmp}" init -q
  git -C "${tmp}" config user.name "Scaffold Smoke"
  git -C "${tmp}" config user.email "scaffold-smoke@example.com"
  git -C "${tmp}" config core.hooksPath .git/hooks
  git -C "${tmp}" add -A
  git -C "${tmp}" commit -q -m "test: initialize unsafe snapshot fixture"
  index_tree="$(git -C "${tmp}" write-tree)"

  for hook in prepare-commit pre-commit; do
    before="$(mktemp "${TMPDIR:-/tmp}/scaffold-snapshot-symlink-before.XXXXXX")"
    err="$(mktemp "${TMPDIR:-/tmp}/scaffold-snapshot-symlink-error.XXXXXX")"
    snapshot_tree "${tmp}" "${before}"
    if (
      cd "${tmp}"
      PATH="${stub_bin}:${PATH}" \
        UNEXPECTED_BD_LOG="${bd_log}" \
        ".githooks/${hook}" unsafe-snapshot
    ) > /dev/null 2> "${err}"; then
      echo "${hook} should reject a symlinked Beads snapshot" >&2
      exit 1
    fi
    require_text ".beads/issues.jsonl must be missing or a regular non-symlink file" "${err}"
    assert_tree_matches_snapshot \
      "${tmp}" \
      "${before}" \
      "${hook} symlinked Beads snapshot rejection"
    [[ "$(git -C "${tmp}" write-tree)" == "${index_tree}" ]] || {
      echo "${hook} changed the Git index while rejecting a symlinked Beads snapshot" >&2
      exit 1
    }
    [[ "$(shasum -a 256 "${outside}" | awk '{print $1}')" == "${outside_checksum}" ]] || {
      echo "${hook} wrote through a symlinked Beads snapshot" >&2
      exit 1
    }
    [[ ! -s "${bd_log}" ]] || {
      echo "${hook} invoked Beads before rejecting a symlinked snapshot" >&2
      exit 1
    }
    rm -f "${before}" "${err}"
  done

  rm -f "${outside}"
}

assert_pathspec_commit_rejected_without_beads_runtime() {
  local tmp="$1"
  local stub_bin="${tmp}/stub-bin"
  local bd_log="${tmp}/bd.log"
  local err=""
  local head_before=""
  local tree_before=""

  run_scaffold "${tmp}" "all"
  mkdir -p "${stub_bin}"
  cat <<'EOF' > "${stub_bin}/bd"
#!/usr/bin/env bash
set -euo pipefail
printf 'unexpected bd invocation: %s\n' "$*" >> "${UNEXPECTED_BD_LOG:?}"
exit 99
EOF
  chmod 0755 "${stub_bin}/bd"
  : > "${bd_log}"

  git -C "${tmp}" init -q
  git -C "${tmp}" config user.name "Scaffold Smoke"
  git -C "${tmp}" config user.email "scaffold-smoke@example.com"
  git -C "${tmp}" config core.hooksPath .git/hooks
  printf 'baseline\n' > "${tmp}/source.txt"
  git -C "${tmp}" add -A
  git -C "${tmp}" commit -q -m "test: initialize pathspec fixture"
  git -C "${tmp}" config core.hooksPath .githooks

  printf 'pathspec change\n' >> "${tmp}/source.txt"
  printf 'separately staged change\n' > "${tmp}/other.txt"
  git -C "${tmp}" add source.txt other.txt
  head_before="$(git -C "${tmp}" rev-parse HEAD)"
  tree_before="$(git -C "${tmp}" write-tree)"
  err="$(mktemp "${TMPDIR:-/tmp}/scaffold-pathspec-without-beads.XXXXXX")"
  if (
    cd "${tmp}"
    PATH="${stub_bin}:${PATH}" \
      UNEXPECTED_BD_LOG="${bd_log}" \
      git commit source.txt -m "test: reject pathspec commit"
  ) > /dev/null 2> "${err}"; then
    echo "pathspec commit should fail before invoking the Beads runtime" >&2
    exit 1
  fi

  require_text "alternate Git index" "${err}"
  [[ ! -s "${bd_log}" ]] || {
    echo "pathspec rejection invoked the Beads runtime" >&2
    exit 1
  }
  [[ "$(git -C "${tmp}" rev-parse HEAD)" == "${head_before}" ]] || {
    echo "rejected pathspec commit changed HEAD" >&2
    exit 1
  }
  [[ "$(git -C "${tmp}" write-tree)" == "${tree_before}" ]] || {
    echo "rejected pathspec commit changed the main Git index" >&2
    exit 1
  }

  rm -f "${err}"
}

assert_committed_tree_matches_reviewed_fingerprint() {
  local tmp="$1"
  local approved_head=""
  local approved_tree=""

  mkdir -p "${tmp}"
  git -C "${tmp}" init -q
  git -C "${tmp}" config user.name "Scaffold Smoke"
  git -C "${tmp}" config user.email "scaffold-smoke@example.com"
  printf 'baseline\n' > "${tmp}/reviewed.txt"
  git -C "${tmp}" add reviewed.txt
  git -C "${tmp}" commit -q -m "test: initialize reviewed tree fixture"

  printf 'approved change\n' >> "${tmp}/reviewed.txt"
  git -C "${tmp}" add reviewed.txt
  approved_head="$(git -C "${tmp}" rev-parse HEAD)"
  approved_tree="$(git -C "${tmp}" write-tree)"
  [[ "$(git -C "${tmp}" rev-parse HEAD)" == "${approved_head}" ]] || {
    echo "reviewed base HEAD changed before commit" >&2
    exit 1
  }
  [[ "$(git -C "${tmp}" write-tree)" == "${approved_tree}" ]] || {
    echo "reviewed tree changed before commit" >&2
    exit 1
  }

  git -C "${tmp}" commit -q -m "test: commit reviewed tree"
  [[ "$(git -C "${tmp}" rev-parse HEAD^)" == "${approved_head}" ]] || {
    echo "commit parent does not match the reviewed base HEAD" >&2
    exit 1
  }
  [[ "$(git -C "${tmp}" rev-parse 'HEAD^{tree}')" == "${approved_tree}" ]] || {
    echo "committed tree does not match the reviewed git write-tree fingerprint" >&2
    exit 1
  }
}

assert_state_accurate() {
  local tmp="$1"
  local agent_harness="$2"
  local state="${tmp}/.agent-scaffold.json"

  [[ -f "${state}" ]] || { echo "state file missing in ${tmp}" >&2; exit 1; }

  local generatedBy
  generatedBy=$(jq -r '.generatedBy' "${state}")
  [[ "${generatedBy}" == "agent-bootstrap" ]] || {
    echo "expected generatedBy=agent-bootstrap, got ${generatedBy}" >&2; exit 1; }

  jq -e '.templateVersion == "1.3.0"' "${state}" >/dev/null
  jq -e '.templateSource' "${state}" >/dev/null
  jq -e '.variables' "${state}" >/dev/null
  jq -e '[.files[].target] | length == (unique | length)' "${state}" >/dev/null || {
    echo "state file contains duplicate managed targets in ${tmp}" >&2
    exit 1
  }
  assert_managed_checksums_match "${tmp}"

  while IFS= read -r target; do
    [[ -f "${tmp}/${target}" ]] || {
      echo "state file claims ${target} but file is missing in ${tmp}" >&2
      exit 1
    }
    local expected_mode="644"
    [[ "${target}" == .githooks/* ]] && expected_mode="755"
    [[ "$(path_mode "${tmp}/${target}")" == "${expected_mode}" ]] || {
      echo "managed mode mismatch for ${target}: expected ${expected_mode}, got $(path_mode "${tmp}/${target}")" >&2
      exit 1
    }
  done < <(jq -r '.files[].target' "${state}")
  [[ "$(path_mode "${state}")" == "644" ]] || {
    echo "scaffold state mode mismatch: expected 644, got $(path_mode "${state}")" >&2
    exit 1
  }

  require_text "Before the first repository or task-tracker mutation" "${tmp}/.claude/CLAUDE.md"
  require_text "feature/<feature-slug>" "${tmp}/.claude/CLAUDE.md"
  require_text "A monitoring or babysitting request authorizes persistent observation only." "${tmp}/.claude/CLAUDE.md"
  require_text "A live apply/deploy is release work, not a TDD check" "${tmp}/.claude/CLAUDE.md"
  require_text "Then stage approved sources individually, run \`.githooks/prepare-commit\`" "${tmp}/.claude/CLAUDE.md"
  require_text "stop if its output exceeds the approved scope" "${tmp}/.claude/CLAUDE.md"
  require_text "stage approved generated outputs individually" "${tmp}/.claude/CLAUDE.md"

  if [[ "${agent_harness}" == "claude-code" ]]; then
    local extras
    extras=$(jq -r '.files[].target' "${state}" \
      | grep -E '^(AGENTS\.md|\.codex/|\.antigravity/)' || true)
    if [[ -n "${extras}" ]]; then
      echo "claude-code state leaked entries:" >&2
      echo "${extras}" >&2
      exit 1
    fi
  fi

  local listed
  listed=$(jq -r '.files[].target' "${state}" | sort -u)
  while IFS= read -r found; do
    [[ -z "${found}" ]] && continue
    local rel="${found#${tmp}/}"
    case "${rel}" in
      .claude/plans/*|.claude/context/*|.claude/architecture/*) continue ;;
      .agent-scaffold.json) continue ;;
      .beads/issues.jsonl) continue ;;
      .beads/README.md|.beads/metadata.json|.beads/export-state.json|.beads/push-state.json|.beads/interactions.jsonl) continue ;;
      .beads/embeddeddolt/*) continue ;;
    esac
    if ! grep -Fxq "${rel}" <<< "${listed}"; then
      echo "file ${rel} exists in ${tmp} but is not in state file" >&2
      exit 1
    fi
  done < <(
    find "${tmp}/.claude" "${tmp}/.codex" "${tmp}/.antigravity" \
      "${tmp}/.beads" "${tmp}/.githooks" \
      "${tmp}/AGENTS.md" \
      -type f 2>/dev/null || true
  )

  git -C "${tmp}" init -q
  : > "${tmp}/.beads/export-state.json"
  mkdir -p "${tmp}/.beads/embeddeddolt/beads/.dolt"
  : > "${tmp}/.beads/embeddeddolt/beads/.dolt/config.json"
  if ! git -C "${tmp}" check-ignore -q .beads/export-state.json; then
    echo ".beads/export-state.json should be ignored in ${tmp}" >&2
    exit 1
  fi
  if ! git -C "${tmp}" check-ignore -q .beads/embeddeddolt/beads/.dolt/config.json; then
    echo ".beads/embeddeddolt should be ignored in ${tmp}" >&2
    exit 1
  fi

  if git -C "${tmp}" check-ignore -q .beads/issues.jsonl; then
    echo ".beads/issues.jsonl should remain trackable in ${tmp}" >&2
    exit 1
  fi

  if [[ -f "${tmp}/AGENTS.md" ]]; then
    require_text "Project-Specific Safety Constraints" "${tmp}/AGENTS.md"
    require_text "Agents must not run \`git add\`, \`git commit\`, or \`git push\` as an automatic session-close workflow." "${tmp}/AGENTS.md"
    require_text "If local Beads runtime state is stale" "${tmp}/AGENTS.md"
    require_text "Do not create markdown TODO trackers or side ledgers for net-new work." "${tmp}/AGENTS.md"
    require_text "A high-quality Beads task has a concrete title, scope-bearing description, design notes, observable acceptance criteria, evidence notes, estimate, and dependencies where relevant." "${tmp}/AGENTS.md"
    require_text "A request to monitor, babysit, follow through, or watch a deployment authorizes persistent observation only." "${tmp}/AGENTS.md"
    require_file "${tmp}/.codex/skills/audit-beads-quality.md"
    require_file "${tmp}/.antigravity/skills/audit-beads-quality.md"
    require_text "Infrastructure And YAML Contract TDD" "${tmp}/.codex/skills/tdd.md"
    require_text "Treating monitoring as mutation authority" "${tmp}/.agents/anti-patterns.md"
    forbid_text "fabricate-beads-history" "${tmp}/.agent-scaffold.json"
    require_text "routine scaffold refreshes do not require \`/bootstrap\`" "${tmp}/AGENTS.md"
    forbid_text "{{BUILD_COMMAND}}" "${tmp}/AGENTS.md"
    forbid_text "{{LINT_COMMAND}}" "${tmp}/AGENTS.md"
    forbid_text "{{SCAFFOLD_COMMAND}}" "${tmp}/AGENTS.md"

    local skill=""
    for skill in feature-start grill-me resolve-adopted-artifacts tdd; do
      cmp -s "${tmp}/.claude/skills/${skill}.md" "${tmp}/.codex/skills/${skill}.md" || {
        echo "Claude and Codex provider contracts differ for ${skill} in ${tmp}" >&2
        exit 1
      }
      cmp -s "${tmp}/.claude/skills/${skill}.md" "${tmp}/.antigravity/skills/${skill}.md" || {
        echo "Claude and Antigravity provider contracts differ for ${skill} in ${tmp}" >&2
        exit 1
      }
    done
  fi
  jq -e '.stale_runtime_recovery.retry_probes | index("bd status --json") and index("bd ready --json")' "${tmp}/.beads/clone-contract.json" >/dev/null
  jq -e '.jsonl_export == ".beads/issues.jsonl"' "${tmp}/.beads/clone-contract.json" >/dev/null
  forbid_text "{{LINT_COMMAND}}" "${tmp}/.agents/anti-patterns.md"
}

assert_agents_local_safety_constraints_survive_refresh() {
  local tmp="$1"
  local state="${tmp}/.agent-scaffold.json"
  local checksum=""
  local out=""

  awk '
    {
      print
    }
    /^## Project-Specific Safety Constraints[[:space:]]*$/ {
      print ""
      print "- Local smoke constraint: preserve project-specific safety guidance across scaffold refreshes."
    }
  ' "${tmp}/AGENTS.md" > "${tmp}/AGENTS.md.next"
  mv "${tmp}/AGENTS.md.next" "${tmp}/AGENTS.md"

  checksum="$(shasum -a 256 "${tmp}/AGENTS.md" | awk '{print $1}')"
  jq --arg checksum "${checksum}" '
    .files |= map(if .target == "AGENTS.md" then .checksum = $checksum else . end)
  ' "${state}" > "${state}.next"
  mv "${state}.next" "${state}"

  out="$(mktemp "${TMPDIR:-/tmp}/scaffold-agents-local-safety.XXXXXX")"
  bash "${repo_root}/scripts/scaffold.sh" "${tmp}" "all" > "${out}"
  require_text "Local smoke constraint: preserve project-specific safety guidance across scaffold refreshes." "${tmp}/AGENTS.md"
  rm -f "${out}"
}

assert_agents_value_drift_refreshes() {
  local tmp="$1"
  local state="${tmp}/.agent-scaffold.json"
  local checksum=""
  local out=""

  awk '
    /^- \*\*Source Directory:\*\* / {
      print "- **Source Directory:** cmd/..."
      next
    }
    /^# Build$/ {
      print
      getline
      print "go build ./cmd/agent-sandbox"
      next
    }
    /^# Test$/ {
      print
      getline
      print "go test ./..."
      next
    }
    /^# Run$/ {
      print
      getline
      print "go run ./cmd/agent-sandbox --help"
      next
    }
    /^- \*\*Typecheck:\*\* `/ {
      print "- **Typecheck:** `go test ./...`"
      next
    }
    {
      print
    }
  ' "${tmp}/AGENTS.md" > "${tmp}/AGENTS.md.next"
  mv "${tmp}/AGENTS.md.next" "${tmp}/AGENTS.md"

  out="$(mktemp "${TMPDIR:-/tmp}/scaffold-agents-value-drift.XXXXXX")"
  bash "${repo_root}/scripts/scaffold.sh" "${tmp}" "all" > "${out}"

  require_text "- **Source Directory:** cmd/..." "${tmp}/AGENTS.md"
  require_text "go build ./cmd/agent-sandbox" "${tmp}/AGENTS.md"
  require_text "go test ./..." "${tmp}/AGENTS.md"
  require_text "go run ./cmd/agent-sandbox --help" "${tmp}/AGENTS.md"
  jq -e '.variables.SOURCE_DIR == "cmd/..."' "${state}" >/dev/null
  jq -e '.variables.BUILD_COMMAND == "go build ./cmd/agent-sandbox"' "${state}" >/dev/null
  jq -e '.variables.TEST_COMMAND == "go test ./..."' "${state}" >/dev/null
  jq -e '.variables.RUN_COMMAND == "go run ./cmd/agent-sandbox --help"' "${state}" >/dev/null
  jq -e '.variables.TYPECHECK_COMMAND == "go test ./..."' "${state}" >/dev/null
  checksum="$(shasum -a 256 "${tmp}/AGENTS.md" | awk '{print $1}')"
  jq -e --arg checksum "${checksum}" '.files[] | select(.target == "AGENTS.md") | .checksum == $checksum' "${state}" >/dev/null

  rm -f "${out}"
}

assert_state_first_value_hydration_refreshes() {
  local tmp="$1"
  local state="${tmp}/.agent-scaffold.json"
  local nuxt_build_command="NUXT_PUBLIC_API_BASE=http://127.0.0.1:18001 NUXT_SERVER_API_BASE=http://127.0.0.1:18001 VITE_API_BASE=http://127.0.0.1:18001 sh -c 'npm run build:css:prod && pnpm --dir frontends/nuxt build'"
  local out=""

  jq --arg build_command "${nuxt_build_command}" '
    .variables.BUILD_COMMAND = $build_command |
    .variables.RUN_COMMAND = "printf \"run ok\""
  ' "${state}" > "${state}.next"
  mv "${state}.next" "${state}"

  out="$(mktemp "${TMPDIR:-/tmp}/scaffold-state-first-hydration.XXXXXX")"
  bash "${repo_root}/scripts/scaffold.sh" "${tmp}" "all" > "${out}"

  require_text "${nuxt_build_command}" "${tmp}/AGENTS.md"
  require_text "${nuxt_build_command}" "${tmp}/.agents/workflows/feature-workflow.md"
  require_text "${nuxt_build_command}" "${tmp}/.codex/skills/feature-start.md"
  require_text "${nuxt_build_command}" "${tmp}/.claude/skills/feature-start.md"
  require_text "${nuxt_build_command}" "${tmp}/.antigravity/skills/feature-start.md"
  require_text 'printf "run ok"' "${tmp}/AGENTS.md"
  jq -e --arg build_command "${nuxt_build_command}" '.variables.BUILD_COMMAND == $build_command' "${state}" >/dev/null
  jq -e '.variables.RUN_COMMAND == "printf \"run ok\""' "${state}" >/dev/null

  rm -f "${out}"
}

assert_state_advanced_partial_agents_refreshes() {
  local tmp="$1"
  local state="${tmp}/.agent-scaffold.json"
  local out=""

  jq '
    .variables.SOURCE_DIR = "cmd/agent-sandbox and internal packages" |
    .variables.BUILD_COMMAND = "go build ./cmd/agent-sandbox" |
    .variables.TYPECHECK_COMMAND = "go test ./..." |
    .variables.TEST_COMMAND = "go test ./..." |
    .variables.RUN_COMMAND = "go run ./cmd/agent-sandbox --help"
  ' "${state}" > "${state}.next"
  mv "${state}.next" "${state}"

  awk '
    /^# Build$/ {
      print
      getline
      print "go build ./cmd/agent-sandbox"
      next
    }
    /^# Test$/ {
      print
      getline
      print "go test ./..."
      next
    }
    /^# Run$/ {
      print
      getline
      print "go run ./cmd/agent-sandbox --help"
      next
    }
    /^- \*\*Typecheck:\*\* `/ {
      print "- **Typecheck:** `go test ./...`"
      next
    }
    {
      print
    }
  ' "${tmp}/AGENTS.md" > "${tmp}/AGENTS.md.next"
  mv "${tmp}/AGENTS.md.next" "${tmp}/AGENTS.md"

  out="$(mktemp "${TMPDIR:-/tmp}/scaffold-state-advanced-partial-agents.XXXXXX")"
  bash "${repo_root}/scripts/scaffold.sh" "${tmp}" "all" > "${out}"

  require_text "- **Source Directory:** cmd/agent-sandbox and internal packages" "${tmp}/AGENTS.md"
  require_text "go build ./cmd/agent-sandbox" "${tmp}/AGENTS.md"
  require_text "go test ./..." "${tmp}/AGENTS.md"
  require_text "go run ./cmd/agent-sandbox --help" "${tmp}/AGENTS.md"
  jq -e '.variables.SOURCE_DIR == "cmd/agent-sandbox and internal packages"' "${state}" >/dev/null
  jq -e '.variables.BUILD_COMMAND == "go build ./cmd/agent-sandbox"' "${state}" >/dev/null

  rm -f "${out}"
}

assert_repository_self_refresh_is_complete() {
  local path=""

  require_text "\"target\": \".githooks/prepare-commit\"" ".agent-scaffold.json"
  for path in \
    ".githooks/prepare-commit" \
    ".githooks/pre-commit" \
    ".githooks/beads-pre-commit.sh"; do
    require_file "${path}"
    if rg --quiet '^[[:space:]]*git[[:space:]]+add([[:space:]]|$)' "${path}"; then
      echo "self-refreshed commit hook must not stage files: ${path}" >&2
      exit 1
    fi
  done
  require_text "pre-commit.validate" ".githooks/pre-commit"
  forbid_text "pre-commit.local" ".githooks/pre-commit"
  cmp -s \
    "bootstrap-templates/templates/universal/githooks/prepare-commit" \
    ".githooks/prepare-commit" || {
      echo "self-refreshed .githooks/prepare-commit does not match its template" >&2
      exit 1
    }
  cmp -s \
    "bootstrap-templates/templates/universal/githooks/pre-commit" \
    ".githooks/pre-commit" || {
      echo "self-refreshed .githooks/pre-commit does not match its template" >&2
      exit 1
    }
  cmp -s \
    "bootstrap-templates/templates/universal/githooks/beads-pre-commit.sh" \
    ".githooks/beads-pre-commit.sh" || {
      echo "self-refreshed .githooks/beads-pre-commit.sh does not match its template" >&2
      exit 1
    }
}

assert_beads_partial_commit_guard() {
  if ! command -v bd >/dev/null 2>&1; then
    echo "bd not found; skipping Beads partial-commit smoke test"
    return 0
  fi

  local tmp
  local repo
  tmp=$(mktemp -d -t scaffold-smoke-beads-XXXX)
  repo="${tmp}/repo"

  git clone -q "${repo_root}" "${repo}"
  cp -R "${repo_root}/.githooks/." "${repo}/.githooks/"
  git -C "${repo}" config user.name "Scaffold Smoke"
  git -C "${repo}" config user.email "scaffold-smoke@example.com"
  git -C "${repo}" config beads.role maintainer
  git -C "${repo}" config core.hooksPath .git/hooks
  chmod 700 "${repo}/.beads"

  (cd "${repo}" && bd bootstrap --yes --json >/dev/null)
  if ! git -C "${repo}" diff --quiet -- .githooks; then
    git -C "${repo}" add .githooks
    git -C "${repo}" commit -m "test: sync hook under test" >/dev/null
  fi
  git -C "${repo}" config core.hooksPath .githooks

  (cd "${repo}" && bd create "Smoke test partial commit guard" \
    --type task \
    --priority 1 \
    --description "Verify the scaffolded Beads hook blocks pathspec commits when the exported issue snapshot is involved, so the snapshot cannot be left behind in the main index." \
    --design "Create a task, modify README.md, attempt a pathspec commit, require a fail-loud message, then retry with a full commit and verify a clean result." \
    --acceptance "- Pathspec commit fails loudly\n- Full commit succeeds and includes .beads/issues.jsonl\n- No staged Beads snapshot remains afterward" \
    --notes "Smoke-test coverage for scaffolded hook behavior with explicit pathspec commits." \
    --estimate 5 \
    --json >/dev/null)

  printf 'smoke test\n' >> "${repo}/README.md"
  git -C "${repo}" add README.md

  (cd "${repo}" && .githooks/prepare-commit >/dev/null)
  if git -C "${repo}" diff --cached --quiet -- .beads/issues.jsonl; then
    :
  else
    echo "prepare-commit staged .beads/issues.jsonl in ${repo}" >&2
    exit 1
  fi
  git -C "${repo}" add .beads/issues.jsonl

  local commit_err
  commit_err=$(mktemp "${TMPDIR:-/tmp}/scaffold-pathspec-commit.XXXXXX")
  if git -C "${repo}" commit README.md -m "test partial commit" > /dev/null 2> "${commit_err}"; then
    echo "pathspec commit should have failed because it uses an alternate Git index in ${repo}" >&2
    exit 1
  fi
  require_text "alternate Git index" "${commit_err}"

  git -C "${repo}" commit -m "test full commit" >/dev/null

  if [[ -n "$(git -C "${repo}" status --short)" ]]; then
    echo "full commit should not leave Beads changes behind in ${repo}" >&2
    exit 1
  fi

  git -C "${repo}" show --stat --oneline HEAD -- .beads/issues.jsonl README.md > "${commit_err}.head"
  require_text ".beads/issues.jsonl" "${commit_err}.head"
  require_text "README.md" "${commit_err}.head"

  rm -f "${commit_err}" "${commit_err}.head"
  rm -rf "${tmp}"
}

smoke_tmp_dirs=()
cleanup_smoke_tmp_dirs() {
  local path=""
  for path in "${smoke_tmp_dirs[@]}"; do
    [[ -z "${path}" || ! -d "${path}" ]] || rm -rf -- "${path}"
  done
}
trap cleanup_smoke_tmp_dirs EXIT

tmp_check=$(mktemp -d -t scaffold-smoke-check-XXXX)
smoke_tmp_dirs+=("${tmp_check}")
assert_check_is_zero_write "${tmp_check}"

tmp_managed_hook=$(mktemp -d -t scaffold-smoke-managed-hook-XXXX)
smoke_tmp_dirs+=("${tmp_managed_hook}")
assert_managed_combined_hook_blocks_without_writes "${tmp_managed_hook}"

tmp_legacy_local=$(mktemp -d -t scaffold-smoke-legacy-local-XXXX)
smoke_tmp_dirs+=("${tmp_legacy_local}")
assert_legacy_pre_commit_local_blocks_without_writes "${tmp_legacy_local}"

tmp_extension_modes=$(mktemp -d -t scaffold-smoke-extension-modes-XXXX)
smoke_tmp_dirs+=("${tmp_extension_modes}")
assert_non_executable_extensions_block_without_writes "${tmp_extension_modes}"

tmp_non_shell_extension=$(mktemp -d -t scaffold-smoke-non-shell-extension-XXXX)
smoke_tmp_dirs+=("${tmp_non_shell_extension}")
assert_executable_non_shell_extensions_survive_refresh "${tmp_non_shell_extension}"

tmp_legacy_contract=$(mktemp -d -t scaffold-smoke-legacy-contract-XXXX)
smoke_tmp_dirs+=("${tmp_legacy_contract}")
assert_managed_legacy_clone_contract_blocks_without_writes "${tmp_legacy_contract}"

tmp_late_drift=$(mktemp -d -t scaffold-smoke-late-drift-XXXX)
smoke_tmp_dirs+=("${tmp_late_drift}")
assert_late_drift_blocks_all_earlier_writes "${tmp_late_drift}"

tmp_candidate_collision=$(mktemp -d -t scaffold-smoke-candidate-collision-XXXX)
smoke_tmp_dirs+=("${tmp_candidate_collision}")
assert_candidate_collision_blocks_without_writes "${tmp_candidate_collision}"

tmp_late_adoption_blocker=$(mktemp -d -t scaffold-smoke-late-adoption-blocker-XXXX)
smoke_tmp_dirs+=("${tmp_late_adoption_blocker}")
assert_late_blocker_withholds_adoption_candidates "${tmp_late_adoption_blocker}"

tmp_unsafe_obsolete=$(mktemp -d -t scaffold-smoke-unsafe-obsolete-XXXX)
smoke_tmp_dirs+=("${tmp_unsafe_obsolete}")
assert_unsafe_obsolete_target_blocks_without_writes "${tmp_unsafe_obsolete}"

tmp_option_obsolete=$(mktemp -d -t scaffold-smoke-option-obsolete-XXXX)
smoke_tmp_dirs+=("${tmp_option_obsolete}")
assert_option_like_obsolete_target_blocks_without_writes \
  "${tmp_option_obsolete}"

tmp_legacy_manifest=$(mktemp -d -t scaffold-smoke-legacy-manifest-XXXX)
smoke_tmp_dirs+=("${tmp_legacy_manifest}")
assert_unverified_legacy_manifest_blocks_without_writes "${tmp_legacy_manifest}"

tmp_symlink_parent=$(mktemp -d -t scaffold-smoke-symlink-parent-XXXX)
smoke_tmp_dirs+=("${tmp_symlink_parent}")
assert_symlinked_parent_blocks_without_external_writes "${tmp_symlink_parent}"

tmp_state_directory=$(mktemp -d -t scaffold-smoke-state-directory-XXXX)
smoke_tmp_dirs+=("${tmp_state_directory}")
tmp_state_symlink=$(mktemp -d -t scaffold-smoke-state-symlink-XXXX)
smoke_tmp_dirs+=("${tmp_state_symlink}")
assert_invalid_state_destinations_block_without_writes \
  "${tmp_state_directory}" \
  "${tmp_state_symlink}"

tmp_foreign_state=$(mktemp -d -t scaffold-smoke-foreign-state-XXXX)
smoke_tmp_dirs+=("${tmp_foreign_state}")
tmp_invalid_state_schema=$(mktemp -d -t scaffold-smoke-invalid-state-schema-XXXX)
smoke_tmp_dirs+=("${tmp_invalid_state_schema}")
assert_untrusted_state_files_block_without_writes \
  "${tmp_foreign_state}" \
  "${tmp_invalid_state_schema}"

tmp_state_capture_race=$(mktemp -d -t scaffold-smoke-state-capture-race-XXXX)
smoke_tmp_dirs+=("${tmp_state_capture_race}")
assert_state_capture_rejects_mismatched_copy "${tmp_state_capture_race}"

tmp_consumed_input_race=$(mktemp -d -t scaffold-smoke-input-race-XXXX)
smoke_tmp_dirs+=("${tmp_consumed_input_race}")
assert_consumed_beads_input_is_rechecked "${tmp_consumed_input_race}"

tmp_unsearchable_parent=$(mktemp -d -t scaffold-smoke-unsearchable-parent-XXXX)
smoke_tmp_dirs+=("${tmp_unsearchable_parent}")
assert_unsearchable_destination_parent_blocks_without_writes \
  "${tmp_unsearchable_parent}"

tmp_invalid_templates=$(mktemp -d -t scaffold-smoke-invalid-templates-XXXX)
smoke_tmp_dirs+=("${tmp_invalid_templates}")
assert_invalid_generated_templates_block_without_writes "${tmp_invalid_templates}"

tmp_local_tmpdir=$(mktemp -d -t scaffold-smoke-local-tmpdir-XXXX)
smoke_tmp_dirs+=("${tmp_local_tmpdir}")
assert_target_local_tmpdir_is_rejected_without_writes "${tmp_local_tmpdir}"

tmp_resolved_hooks=$(mktemp -d -t scaffold-smoke-resolved-hooks-XXXX)
smoke_tmp_dirs+=("${tmp_resolved_hooks}")
assert_explicit_hook_extensions_survive_refresh "${tmp_resolved_hooks}"

tmp_hook_contract=$(mktemp -d -t scaffold-smoke-hook-contract-XXXX)
smoke_tmp_dirs+=("${tmp_hook_contract}")
assert_prepare_and_validate_contract "${tmp_hook_contract}"

tmp_snapshot_symlink=$(mktemp -d -t scaffold-smoke-snapshot-symlink-XXXX)
smoke_tmp_dirs+=("${tmp_snapshot_symlink}")
assert_beads_snapshot_symlink_is_rejected "${tmp_snapshot_symlink}"

tmp_pathspec_without_beads=$(mktemp -d -t scaffold-smoke-pathspec-no-beads-XXXX)
smoke_tmp_dirs+=("${tmp_pathspec_without_beads}")
assert_pathspec_commit_rejected_without_beads_runtime \
  "${tmp_pathspec_without_beads}"

tmp_reviewed_tree=$(mktemp -d -t scaffold-smoke-reviewed-tree-XXXX)
smoke_tmp_dirs+=("${tmp_reviewed_tree}")
assert_committed_tree_matches_reviewed_fingerprint "${tmp_reviewed_tree}"

tmp_all=$(mktemp -d -t scaffold-smoke-all-XXXX)
smoke_tmp_dirs+=("${tmp_all}")
tmp_cadence=$(mktemp -d -t scaffold-smoke-cadence-XXXX)
smoke_tmp_dirs+=("${tmp_cadence}")
tmp_beads_readiness=$(mktemp -d -t scaffold-smoke-beads-readiness-XXXX)
smoke_tmp_dirs+=("${tmp_beads_readiness}")
assert_bootstrap_prompt_cadence "${tmp_cadence}"
assert_beads_readiness_message_matches_status "${tmp_beads_readiness}"
run_scaffold "${tmp_all}" "all"
assert_state_accurate "${tmp_all}" "all"
assert_agents_local_safety_constraints_survive_refresh "${tmp_all}"
assert_drift_fails_loud "${tmp_all}"

tmp_value_drift=$(mktemp -d -t scaffold-smoke-value-drift-XXXX)
smoke_tmp_dirs+=("${tmp_value_drift}")
run_scaffold "${tmp_value_drift}" "all"
assert_agents_value_drift_refreshes "${tmp_value_drift}"

tmp_state_hydration=$(mktemp -d -t scaffold-smoke-state-hydration-XXXX)
smoke_tmp_dirs+=("${tmp_state_hydration}")
run_scaffold "${tmp_state_hydration}" "all"
assert_state_first_value_hydration_refreshes "${tmp_state_hydration}"

tmp_state_advanced_partial=$(mktemp -d -t scaffold-smoke-state-advanced-partial-XXXX)
smoke_tmp_dirs+=("${tmp_state_advanced_partial}")
run_scaffold "${tmp_state_advanced_partial}" "all"
assert_state_advanced_partial_agents_refreshes "${tmp_state_advanced_partial}"

tmp_cc=$(mktemp -d -t scaffold-smoke-cc-XXXX)
smoke_tmp_dirs+=("${tmp_cc}")
run_scaffold "${tmp_cc}" "claude-code"
assert_state_accurate "${tmp_cc}" "claude-code"

tmp_adopt=$(mktemp -d -t scaffold-smoke-adopt-XXXX)
smoke_tmp_dirs+=("${tmp_adopt}")
assert_adoption_conflict_is_preserved "${tmp_adopt}"
assert_adoption_conflict_blocks_rerun "${tmp_adopt}"
assert_adoption_conflict_drift_fails_loud "${tmp_adopt}"

tmp_existing_beads=$(mktemp -d -t scaffold-smoke-existing-beads-XXXX)
smoke_tmp_dirs+=("${tmp_existing_beads}")
assert_existing_beads_contract_is_inferred "${tmp_existing_beads}"

tmp_resolved=$(mktemp -d -t scaffold-smoke-resolved-XXXX)
smoke_tmp_dirs+=("${tmp_resolved}")
assert_adoption_conflict_is_preserved "${tmp_resolved}"
assert_adoption_conflict_resolution_unblocks_rerun "${tmp_resolved}"

assert_repository_self_refresh_is_complete
assert_beads_partial_commit_guard

echo "scaffold smoke test passed"
