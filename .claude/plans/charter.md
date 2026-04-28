# Agent-Bootstrap Charter

## Summary

Agent-bootstrap is a ready-made project setup for agentic programming — a uniform orchestration system that learns from your interactions and improves over time. It works both as a project-specific scaffold and as a generic template.

## Goal

Provide a clear, learnable interface for agent-assisted development that:
- Removes friction from starting projects with agent workflows
- Captures learnings from each project and feeds them back into the template
- Remains understandable to both experienced and new developers

## User

Primary user: Ásmundur. Secondary users: anyone collaborating on this project in the future (if applicable).

## Success Criteria

Agent-bootstrap is done when:
- All interfaces are clear and understandable (no obscurity, no magic)
- Workflows work as designed
- A developer can pick up the template and use it without confusion

## Non-Goals

- Impose constraints on how projects should be structured
- Optimize for every tech stack (tech stack is irrelevant to agentic programming)
- Ship a perfectly automated feedback loop on day one

## Key Design Decisions

### 1. Tech Stack Irrelevance
Agent-bootstrap is fundamentally about **agent programming**, not language-specific orchestration. The scaffold command applies generic files and state, while the `/bootstrap` skill discovers project-specific context from the target repository. The workflows and skills themselves are agent-agnostic. The glossary, module map, and design-first approach work the same whether you're in Go, Python, TypeScript, or Rust.

### 2. "Set and Forget It" (for now)
Projects that use agent-bootstrap bootstrap once and work independently. Upstream changes to the template don't propagate automatically. This simplifies things early.

**Future improvement**: More dynamic, self-contained processes that handle template evolution gracefully.

### 3. Scaffold State Tracking
All generated scaffold-managed files are tracked in `.agent-scaffold.json`. This serves two purposes:
- Enables cleanup if the project later wants to remove agent-bootstrap
- Provides a foundation for future dynamic updates without overwriting local edits

### 4. Antigravity Support
Agent-bootstrap supports multiple agent harnesses:
- Claude Code (primary)
- Codex
- Antigravity (another agent harness)

Each harness may have its own skill variants in `.antigravity/`, `.codex/`, etc.

## Resolved Design Decisions

### Feedback Loop Propagation
**Decision**: Automatic propagation, user remains judge.

The `/retro` skill will automatically propose changes back to `bootstrap-templates/` based on learnings from the session. The coding agent synthesizes findings and commits them. **You** review and approve/reject via git before pushing upstream. This way: the agent proposes, you decide. Version control is the safety gate.

### Manifest File Format (Option A)
**Decision**: Simple, readable format without checksums (for now).

`.agent-scaffold.json` tracks all generated/modified scaffold-managed files:
```json
{
  "generatedBy": "agent-bootstrap",
  "templateVersion": "0.1.0",
  "files": [
    ".claude/CLAUDE.md",
    ".claude/anti-patterns.md",
    ".claude/skills/grill-me.md",
    ".beads/config.yaml"
  ]
}
```

If we later need change detection, we can add checksums. For now, keep it simple.

### Harness Interchangeability
**Decision**: Core skills are harness-agnostic. Switching between Claude Code, Codex, and Antigravity should be seamless.

- All core skills (grill-me, feature-start, retro, etc.) work in any harness
- `.antigravity/`, `.codex/` directories are optional variants only, not required
- No harness-specific logic in core workflows
- A project scaffolded with agent-bootstrap works equally in any harness

## Open Questions / Parked Decisions

### Dynamic Template Evolution
**Decision**: "Set and forget it" for now. Projects don't auto-sync with upstream changes.

**Future consideration**: Design a more sophisticated process where projects can stay in sync without overwriting local customizations.

**Parked**: Lower priority until more projects are using the bootstrap.

## Canonical Terms

- **Agent harness**: The system that runs Claude (Claude Code, Codex, Antigravity, etc.)
- **Bootstrap**: The act of setting up a project with agent-bootstrap orchestration
- **Template**: The generic workflow setup in `bootstrap-templates/` that gets copied into projects
- **Scaffold state**: `.agent-scaffold.json` tracking all generated/modified scaffold-managed files
- **Skill**: A reusable workflow document (e.g., `/grill-me`, `/retro`) that guides Claude through a structured process

## Affected Modules

- `.claude/` — Project-specific orchestration (generated per project)
- `bootstrap-templates/` — Generic templates used by the bootstrap script
- `.beads/` — Task tracking (if using Beads)
- `.antigravity/`, `.codex/` — Harness-specific skill variants

## Interface Changes

None at this stage. The project is defining its own interfaces, not integrating into an existing system.

## Acceptance Criteria

- [ ] This charter is clear enough that a new collaborator could read it and understand the project's purpose
- [ ] The feedback loop propagation mechanism is designed (not necessarily implemented)
- [ ] Tech stack irrelevance is documented and understood across the codebase
- [ ] The manifest file format is specified and used consistently

## Feedback Loop Mechanism

The propagation path from one project's learnings back into the template, and from the template out to other projects, is a four-part loop. All four parts already exist in the codebase:

1. **Capture** — `/retro` (`bootstrap-templates/templates/universal/skills/retro.md.tmpl`) runs after a feature lands. It analyzes the diff, asks the user what worked and what didn't, and proposes concrete edits against `bootstrap-templates/`.
2. **Gate** — Proposals land as a regular commit in the agent-bootstrap repo. The user reviews and approves/rejects via git. Version control is the safety gate; nothing auto-pushes upstream (per "Feedback Loop Propagation" decision above).
3. **Distribute** — Other projects pull improvements by re-running `scripts/scaffold.sh`. The command reads `templateSource` from `.agent-scaffold.json`, re-renders the scaffold-managed files, and refuses to overwrite drifted scaffold-managed files.
4. **Cursor** — `templateVersion` in the scaffold state is the version of the template that last scaffolded this project. Re-running `scripts/scaffold.sh` uses it as the forward refresh cursor for scaffold-managed files.

`.claude/scaffold-state-spec.md` documents the scaffold-state format, including drift detection via file checksums.

## Feedback Loops (operational)

- Read this charter before starting any new work on agent-bootstrap
- Run `/retro` after major features to capture learnings
- Update this charter if design decisions change

---

*Last updated: 2026-04-26*
