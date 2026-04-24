#!/usr/bin/env bash
set -euo pipefail

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
  rg -F --quiet "${pattern}" "${path}" || {
    echo "missing expected text in ${path}: ${pattern}" >&2
    exit 1
  }
}

template_files=(
  "bootstrap-templates/templates/universal/AGENTS.md.tmpl"
  "bootstrap-templates/templates/universal/CLAUDE.md.tmpl"
  "bootstrap-templates/templates/universal/agents/feature-implementation.md.tmpl"
  "bootstrap-templates/templates/universal/skills/grill-me.md.tmpl"
  "bootstrap-templates/templates/universal/skills/ubiquitous-language.md.tmpl"
  "bootstrap-templates/templates/universal/skills/improve-architecture.md.tmpl"
  "bootstrap-templates/templates/universal/skills/tdd.md.tmpl"
  "bootstrap-templates/templates/universal/skills/feature-start.md.tmpl"
  "bootstrap-templates/templates/universal/skills/retro.md.tmpl"
  "bootstrap-templates/templates/universal/skills/sync-bootstrap.md.tmpl"
  "bootstrap-templates/templates/universal/workflows/feature-workflow.md.tmpl"
)

local_files=(
  "AGENTS.md"
  ".claude/CLAUDE.md"
  ".claude/anti-patterns.md"
  ".claude/agents/feature-implementation.md"
  ".claude/agents/git-manager.md"
  ".claude/skills/grill-me.md"
  ".claude/skills/ubiquitous-language.md"
  ".claude/skills/improve-architecture.md"
  ".claude/skills/tdd.md"
  ".claude/skills/feature-start.md"
  ".claude/skills/retro.md"
  ".claude/skills/sync-bootstrap.md"
  ".claude/skills/fabricate-beads-history.md"
  ".claude/workflows/feature-workflow.md"
  ".claude/.bootstrap-manifest.json"
  ".codex/skills/grill-me.md"
  ".codex/skills/ubiquitous-language.md"
  ".codex/skills/improve-architecture.md"
  ".codex/skills/tdd.md"
  ".codex/skills/fabricate-beads-history.md"
  ".antigravity/skills/grill-me.md"
  ".antigravity/skills/ubiquitous-language.md"
  ".antigravity/skills/improve-architecture.md"
  ".antigravity/skills/tdd.md"
  ".antigravity/skills/fabricate-beads-history.md"
)

for path in "${template_files[@]}"; do
  require_file "${path}"
done

for path in "${local_files[@]}"; do
  require_file "${path}"
done

require_text "/grill-me" ".claude/CLAUDE.md"
require_text "/ubiquitous-language" ".claude/CLAUDE.md"
require_text "/improve-architecture" ".claude/CLAUDE.md"
require_text "/tdd" ".claude/CLAUDE.md"
require_text "\"TYPECHECK_COMMAND\": \"not configured\"" ".claude/.bootstrap-manifest.json"
require_text "\"target\": \".claude/skills/grill-me.md\"" ".claude/.bootstrap-manifest.json"
require_text "\"target\": \".codex/skills/tdd.md\"" ".claude/.bootstrap-manifest.json"
require_text "\"target\": \".antigravity/skills/tdd.md\"" ".claude/.bootstrap-manifest.json"
require_text "Implement the feature in small red/green/refactor steps" "bootstrap-templates/templates/universal/agents/feature-implementation.md.tmpl"
require_text "Stage 0 — Shared Design Alignment" "bootstrap-templates/templates/universal/workflows/feature-workflow.md.tmpl"
require_text 'Create or update `.claude/context/ubiquitous-language.md`' "bootstrap-templates/templates/universal/skills/ubiquitous-language.md.tmpl"

echo "bootstrap smoke test passed"
