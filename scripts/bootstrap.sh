#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$(cd "${SCRIPT_DIR}/../bootstrap-templates/templates/universal" && pwd)"

if [[ ! -d "${TEMPLATE_DIR}" ]]; then
  echo "Error: Cannot find templates at ${TEMPLATE_DIR}"
  exit 1
fi

TARGET_DIR="${1:-.}"
cd "${TARGET_DIR}"

if [[ -d ".claude" || -f "AGENTS.md" ]]; then
  echo "Warning: .claude/ directory or AGENTS.md already exists in $(pwd)"
  read -p "Are you sure you want to overwrite existing files? (y/N) " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
  fi
fi

echo "Bootstrapping project in $(pwd)..."

# --- Detect Stack ---
TECH_STACK="Unknown"
MAIN_LANGUAGE="Unknown"
BUILD_COMMAND="not configured"
TEST_COMMAND="not configured"
RUN_COMMAND="not configured"

if [[ -f "package.json" ]]; then
  TECH_STACK="Node/TypeScript"
  MAIN_LANGUAGE="TypeScript"
  BUILD_COMMAND="npm run build"
  TEST_COMMAND="npm test"
  RUN_COMMAND="npm start"
elif [[ -f "go.mod" ]]; then
  TECH_STACK="Go"
  MAIN_LANGUAGE="Go"
  BUILD_COMMAND="go build ./..."
  TEST_COMMAND="go test ./..."
  RUN_COMMAND="go run ."
elif [[ -f "Cargo.toml" ]]; then
  TECH_STACK="Rust"
  MAIN_LANGUAGE="Rust"
  BUILD_COMMAND="cargo build"
  TEST_COMMAND="cargo test"
  RUN_COMMAND="cargo run"
elif ls *.sln 1> /dev/null 2>&1 || ls *.csproj 1> /dev/null 2>&1; then
  TECH_STACK=".NET"
  MAIN_LANGUAGE="C#"
  BUILD_COMMAND="dotnet build"
  TEST_COMMAND="dotnet test"
  RUN_COMMAND="dotnet run"
elif [[ -f "requirements.txt" || -f "pyproject.toml" ]]; then
  TECH_STACK="Python"
  MAIN_LANGUAGE="Python"
  TEST_COMMAND="pytest"
  RUN_COMMAND="python -m <module>"
elif [[ -f "pom.xml" ]]; then
  TECH_STACK="Java/Kotlin (Maven)"
  MAIN_LANGUAGE="Java"
  BUILD_COMMAND="mvn package"
  TEST_COMMAND="mvn test"
  RUN_COMMAND="mvn exec:java"
elif [[ -f "build.gradle" || -f "build.gradle.kts" ]]; then
  TECH_STACK="Java/Kotlin (Gradle)"
  MAIN_LANGUAGE="Java"
  BUILD_COMMAND="./gradlew build"
  TEST_COMMAND="./gradlew test"
  RUN_COMMAND="./gradlew run"
fi

DEFAULT_PROJECT_NAME="$(basename "$(pwd)")"

echo "Please confirm or override the following detected settings:"
read -p "Project Name [${DEFAULT_PROJECT_NAME}]: " PROJECT_NAME
PROJECT_NAME="${PROJECT_NAME:-$DEFAULT_PROJECT_NAME}"

read -p "Project Description []: " PROJECT_DESCRIPTION
PROJECT_DESCRIPTION="${PROJECT_DESCRIPTION:-}"

read -p "Tech Stack [${TECH_STACK}]: " INPUT_TECH_STACK
TECH_STACK="${INPUT_TECH_STACK:-$TECH_STACK}"

read -p "Main Language [${MAIN_LANGUAGE}]: " INPUT_MAIN_LANGUAGE
MAIN_LANGUAGE="${INPUT_MAIN_LANGUAGE:-$MAIN_LANGUAGE}"

read -p "Build Command [${BUILD_COMMAND}]: " INPUT_BUILD_COMMAND
BUILD_COMMAND="${INPUT_BUILD_COMMAND:-$BUILD_COMMAND}"

read -p "Typecheck Command [not configured]: " TYPECHECK_COMMAND
TYPECHECK_COMMAND="${TYPECHECK_COMMAND:-not configured}"

read -p "Lint Command [not configured]: " LINT_COMMAND
LINT_COMMAND="${LINT_COMMAND:-not configured}"

read -p "Browser Verify Command [not configured]: " BROWSER_VERIFY_COMMAND
BROWSER_VERIFY_COMMAND="${BROWSER_VERIFY_COMMAND:-not configured}"

read -p "Test Command [${TEST_COMMAND}]: " INPUT_TEST_COMMAND
TEST_COMMAND="${INPUT_TEST_COMMAND:-$TEST_COMMAND}"

read -p "Run Command [${RUN_COMMAND}]: " INPUT_RUN_COMMAND
RUN_COMMAND="${INPUT_RUN_COMMAND:-$RUN_COMMAND}"

read -p "Source Directory [src/]: " SOURCE_DIR
SOURCE_DIR="${SOURCE_DIR:-src/}"

read -p "Architecture Pattern [Layered]: " ARCHITECTURE_PATTERN
ARCHITECTURE_PATTERN="${ARCHITECTURE_PATTERN:-Layered}"

echo ""
echo "Tool Target options: both, claude-code, codex"
read -p "Tool Target [both]: " TOOL_TARGET
TOOL_TARGET="${TOOL_TARGET:-both}"

DEFAULT_BEADS_PREFIX=$(echo "${PROJECT_NAME}" | tr -cd '[:alnum:]' | tr '[:upper:]' '[:lower:]' | cut -c1-3)
if [[ -z "$DEFAULT_BEADS_PREFIX" ]]; then DEFAULT_BEADS_PREFIX="prj"; fi
read -p "Beads Prefix [${DEFAULT_BEADS_PREFIX}]: " BEADS_PREFIX
BEADS_PREFIX="${BEADS_PREFIX:-$DEFAULT_BEADS_PREFIX}"

BOOTSTRAP_DATE="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

echo ""
echo "Generating files..."

mkdir -p .claude/agents .claude/architecture .claude/context .claude/plans .claude/skills .claude/workflows
mkdir -p .codex/skills
mkdir -p .beads
mkdir -p .githooks

# Escape values for awk substitution
export P_PROJECT_NAME="$PROJECT_NAME"
export P_PROJECT_DESCRIPTION="$PROJECT_DESCRIPTION"
export P_TECH_STACK="$TECH_STACK"
export P_MAIN_LANGUAGE="$MAIN_LANGUAGE"
export P_BUILD_COMMAND="$BUILD_COMMAND"
export P_TYPECHECK_COMMAND="$TYPECHECK_COMMAND"
export P_LINT_COMMAND="$LINT_COMMAND"
export P_BROWSER_VERIFY_COMMAND="$BROWSER_VERIFY_COMMAND"
export P_TEST_COMMAND="$TEST_COMMAND"
export P_RUN_COMMAND="$RUN_COMMAND"
export P_SOURCE_DIR="$SOURCE_DIR"
export P_ARCHITECTURE_PATTERN="$ARCHITECTURE_PATTERN"
export P_TOOL_TARGET="$TOOL_TARGET"
export P_BEADS_PREFIX="$BEADS_PREFIX"
export P_BOOTSTRAP_DATE="$BOOTSTRAP_DATE"

# Awk script for replacing placeholders without regex special character issues
replace_vars() {
  awk '
  {
    gsub(/\{\{PROJECT_NAME\}\}/, ENVIRON["P_PROJECT_NAME"])
    gsub(/\{\{PROJECT_DESCRIPTION\}\}/, ENVIRON["P_PROJECT_DESCRIPTION"])
    gsub(/\{\{TECH_STACK\}\}/, ENVIRON["P_TECH_STACK"])
    gsub(/\{\{MAIN_LANGUAGE\}\}/, ENVIRON["P_MAIN_LANGUAGE"])
    gsub(/\{\{BUILD_COMMAND\}\}/, ENVIRON["P_BUILD_COMMAND"])
    gsub(/\{\{TYPECHECK_COMMAND\}\}/, ENVIRON["P_TYPECHECK_COMMAND"])
    gsub(/\{\{LINT_COMMAND\}\}/, ENVIRON["P_LINT_COMMAND"])
    gsub(/\{\{BROWSER_VERIFY_COMMAND\}\}/, ENVIRON["P_BROWSER_VERIFY_COMMAND"])
    gsub(/\{\{TEST_COMMAND\}\}/, ENVIRON["P_TEST_COMMAND"])
    gsub(/\{\{RUN_COMMAND\}\}/, ENVIRON["P_RUN_COMMAND"])
    gsub(/\{\{SOURCE_DIR\}\}/, ENVIRON["P_SOURCE_DIR"])
    gsub(/\{\{ARCHITECTURE_PATTERN\}\}/, ENVIRON["P_ARCHITECTURE_PATTERN"])
    gsub(/\{\{TOOL_TARGET\}\}/, ENVIRON["P_TOOL_TARGET"])
    gsub(/\{\{BEADS_PREFIX\}\}/, ENVIRON["P_BEADS_PREFIX"])
    gsub(/\{\{BOOTSTRAP_DATE\}\}/, ENVIRON["P_BOOTSTRAP_DATE"])
    print
  }' "$1"
}

copy_template() {
  local src="$1"
  local dst="$2"
  if [[ -f "${TEMPLATE_DIR}/${src}" ]]; then
    replace_vars "${TEMPLATE_DIR}/${src}" > "${dst}"
    echo "  ✓ ${dst}"
  fi
}

copy_hook() {
  local src="$1"
  local dst="$2"
  if [[ -f "${TEMPLATE_DIR}/${src}" ]]; then
    cp "${TEMPLATE_DIR}/${src}" "${dst}"
    chmod +x "${dst}"
    echo "  ✓ ${dst}"
  fi
}

# 1. Base files
copy_template "anti-patterns.md.tmpl" ".claude/anti-patterns.md"

# 2. Agents
copy_template "agents/feature-implementation.md.tmpl" ".claude/agents/feature-implementation.md"
copy_template "agents/git-manager.md.tmpl" ".claude/agents/git-manager.md"

# 3. Skills
for skill in grill-me ubiquitous-language improve-architecture tdd feature-start retro sync-bootstrap fabricate-beads-history; do
  copy_template "skills/${skill}.md.tmpl" ".claude/skills/${skill}.md"
done

# 4. Workflows
copy_template "workflows/feature-workflow.md.tmpl" ".claude/workflows/feature-workflow.md"

# 5. Beads
if [[ ! -f ".beads/config.yaml" ]]; then
  copy_template "beads/config.yaml.tmpl" ".beads/config.yaml"
fi
if [[ ! -f ".beads/clone-contract.json" ]]; then
  copy_template "beads/clone-contract.json.tmpl" ".beads/clone-contract.json"
fi
if [[ ! -f ".beads/.gitignore" ]]; then
  cp "${TEMPLATE_DIR}/beads/gitignore" ".beads/.gitignore"
fi

# 6. Githooks
copy_hook "githooks/_common.sh" ".githooks/_common.sh"
copy_hook "githooks/beads-pre-commit.sh" ".githooks/beads-pre-commit.sh"
if [[ ! -f ".githooks/pre-commit" ]]; then
  copy_hook "githooks/pre-commit" ".githooks/pre-commit"
else
  echo "  ! .githooks/pre-commit already exists. Remember to source _common.sh and beads-pre-commit.sh manually."
fi
git config core.hooksPath .githooks || true

# 7. TOOL_TARGET files
if [[ "$TOOL_TARGET" == "both" || "$TOOL_TARGET" == "codex" ]]; then
  copy_template "AGENTS.md.tmpl" "AGENTS.md"
  for skill in grill-me ubiquitous-language improve-architecture tdd fabricate-beads-history; do
    copy_template "skills/${skill}.md.tmpl" ".codex/skills/${skill}.md"
  done
fi

# 8. Special handling for CLAUDE.md
if [[ "$TOOL_TARGET" == "both" || "$TOOL_TARGET" == "claude-code" ]]; then
  export P_OVERVIEW_SECTION=""
  export P_AGENTS_IMPORT=""

  if [[ "$TOOL_TARGET" == "both" ]]; then
    P_AGENTS_IMPORT="@AGENTS.md\n\n"
  elif [[ "$TOOL_TARGET" == "claude-code" ]]; then
    P_OVERVIEW_SECTION="\n## Project Overview\n\n${P_PROJECT_DESCRIPTION}\n\n- **Tech Stack:** ${P_TECH_STACK}\n- **Language:** ${P_MAIN_LANGUAGE}\n- **Source Directory:** ${P_SOURCE_DIR}\n- **Architecture:** ${P_ARCHITECTURE_PATTERN}\n\n## Essential Commands\n\n\`\`\`bash\n# Build\n${P_BUILD_COMMAND}\n\n# Typecheck (optional)\n${P_TYPECHECK_COMMAND}\n\n# Lint (optional)\n${P_LINT_COMMAND}\n\n# Browser verification (optional)\n${P_BROWSER_VERIFY_COMMAND}\n\n# Test\n${P_TEST_COMMAND}\n\n# Run\n${P_RUN_COMMAND}\n\`\`\`\n\n## Architecture & Key Patterns\n\n${P_ARCHITECTURE_PATTERN}\n\nFollow existing patterns in \`${P_SOURCE_DIR}\` when implementing new features. Explore before implementing — find similar code and replicate its structure.\n\n## Durable Artifacts\n\n- **Feature specs:** \`.claude/plans/<feature-slug>.md\`\n- **Ubiquitous language:** \`.claude/context/ubiquitous-language.md\`\n- **Module map:** \`.claude/architecture/module-map.md\`\n\nThese files are created on first use by the generated skills.\n\n## Code Style Guidelines\n\n- Match the style of surrounding code\n- Functions should do one thing\n- Name things for what they are, not how they're implemented\n- Validate at system boundaries (user input, external APIs) — trust internal code\n- No dead code, no commented-out blocks, no TODO left behind after a feature\n- Tests are not optional\n\n## Task Tracking — Beads\n\nThis project uses [beads](https://github.com/steveyegge/beads) (\`bd\`) for task tracking. Issue prefix: \`${P_BEADS_PREFIX}\`.\n\nBefore starting new work:\n    bd ready --json           # list available tasks\n    bd update <id> --claim --json   # claim one\n\nCreating a task:\n    bd create --title \"...\" -p 2 --json\n\nClosing a task:\n    bd close <id> --reason \"done\" --json\n\n\`.beads/issues.jsonl\` is the git-tracked snapshot; the pre-commit hook refreshes it via \`bd export --no-memories\` and auto-stages changes, so task state travels with commits. Do not edit \`.beads/issues.jsonl\` by hand. Do not bypass the hook (\`--no-verify\`).\n"
  fi

  # Render CLAUDE.md.tmpl to a temporary file using the common variable replacer
  replace_vars "${TEMPLATE_DIR}/CLAUDE.md.tmpl" > .claude/CLAUDE.md.tmp

  # Now replace the special sections using awk
  awk '
  {
    if (index($0, "{{AGENTS_MD_IMPORT}}") > 0) {
      if (ENVIRON["P_AGENTS_IMPORT"] != "") {
        printf "@AGENTS.md\n\n"
      }
    } else if (index($0, "{{PROJECT_OVERVIEW_SECTION}}") > 0) {
      if (ENVIRON["P_OVERVIEW_SECTION"] != "") {
        print ENVIRON["P_OVERVIEW_SECTION"]
      }
    } else {
      print $0
    }
  }' .claude/CLAUDE.md.tmp > .claude/CLAUDE.md
  
  rm .claude/CLAUDE.md.tmp
  echo "  ✓ .claude/CLAUDE.md"
fi

# 9. Generate Manifest
cat <<EOF > .claude/.bootstrap-manifest.json
{
  "generatedAt": "${BOOTSTRAP_DATE}",
  "pluginVersion": "1.0.0",
  "techStack": "${TECH_STACK}",
  "toolTarget": "${TOOL_TARGET}",
  "templateSource": "bootstrap-templates/templates/universal",
  "variables": {
    "PROJECT_NAME": "${PROJECT_NAME}",
    "PROJECT_DESCRIPTION": "${PROJECT_DESCRIPTION}",
    "TECH_STACK": "${TECH_STACK}",
    "MAIN_LANGUAGE": "${MAIN_LANGUAGE}",
    "BUILD_COMMAND": "${BUILD_COMMAND}",
    "TYPECHECK_COMMAND": "${TYPECHECK_COMMAND}",
    "LINT_COMMAND": "${LINT_COMMAND}",
    "BROWSER_VERIFY_COMMAND": "${BROWSER_VERIFY_COMMAND}",
    "TEST_COMMAND": "${TEST_COMMAND}",
    "RUN_COMMAND": "${RUN_COMMAND}",
    "SOURCE_DIR": "${SOURCE_DIR}",
    "ARCHITECTURE_PATTERN": "${ARCHITECTURE_PATTERN}",
    "TOOL_TARGET": "${TOOL_TARGET}",
    "BEADS_PREFIX": "${BEADS_PREFIX}",
    "BOOTSTRAP_DATE": "${BOOTSTRAP_DATE}"
  },
  "files": [
    { "target": "AGENTS.md", "source": "AGENTS.md.tmpl", "category": "config" },
    { "target": ".claude/CLAUDE.md", "source": "CLAUDE.md.tmpl", "category": "config" },
    { "target": ".claude/anti-patterns.md", "source": "anti-patterns.md.tmpl", "category": "config" },
    { "target": ".claude/agents/feature-implementation.md", "source": "agents/feature-implementation.md.tmpl", "category": "agent" },
    { "target": ".claude/agents/git-manager.md", "source": "agents/git-manager.md.tmpl", "category": "agent" },
    { "target": ".claude/skills/grill-me.md", "source": "skills/grill-me.md.tmpl", "category": "skill" },
    { "target": ".claude/skills/ubiquitous-language.md", "source": "skills/ubiquitous-language.md.tmpl", "category": "skill" },
    { "target": ".claude/skills/improve-architecture.md", "source": "skills/improve-architecture.md.tmpl", "category": "skill" },
    { "target": ".claude/skills/tdd.md", "source": "skills/tdd.md.tmpl", "category": "skill" },
    { "target": ".claude/skills/feature-start.md", "source": "skills/feature-start.md.tmpl", "category": "skill" },
    { "target": ".claude/skills/retro.md", "source": "skills/retro.md.tmpl", "category": "skill" },
    { "target": ".claude/skills/sync-bootstrap.md", "source": "skills/sync-bootstrap.md.tmpl", "category": "skill" },
    { "target": ".claude/skills/fabricate-beads-history.md", "source": "skills/fabricate-beads-history.md.tmpl", "category": "skill" },
    { "target": ".codex/skills/grill-me.md", "source": "skills/grill-me.md.tmpl", "category": "skill" },
    { "target": ".codex/skills/ubiquitous-language.md", "source": "skills/ubiquitous-language.md.tmpl", "category": "skill" },
    { "target": ".codex/skills/improve-architecture.md", "source": "skills/improve-architecture.md.tmpl", "category": "skill" },
    { "target": ".codex/skills/tdd.md", "source": "skills/tdd.md.tmpl", "category": "skill" },
    { "target": ".codex/skills/fabricate-beads-history.md", "source": "skills/fabricate-beads-history.md.tmpl", "category": "skill" },
    { "target": ".claude/workflows/feature-workflow.md", "source": "workflows/feature-workflow.md.tmpl", "category": "workflow" },
    { "target": ".beads/config.yaml", "source": "beads/config.yaml.tmpl", "category": "beads" },
    { "target": ".beads/clone-contract.json", "source": "beads/clone-contract.json.tmpl", "category": "beads" },
    { "target": ".beads/.gitignore", "source": "beads/gitignore", "category": "beads" },
    { "target": ".githooks/_common.sh", "source": "githooks/_common.sh", "category": "hook" },
    { "target": ".githooks/beads-pre-commit.sh", "source": "githooks/beads-pre-commit.sh", "category": "hook" },
    { "target": ".githooks/pre-commit", "source": "githooks/pre-commit", "category": "hook" }
  ]
}
EOF
echo "  ✓ .claude/.bootstrap-manifest.json"

echo ""
echo "Bootstrap complete!"
