# Changelog

All notable changes to the Draft plugin will be documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Version numbers follow [Semantic Versioning](https://semver.org/).

---

## [Unreleased]

- `agents/pm-agent.md` — fixed sub-agent delegation instructions to use fully-qualified agent names (`draft:draft-executor`, `draft:draft-researcher`, `draft:draft-learner`). Previously used short names which caused "agent not found" errors when pm-agent attempted to spawn sub-agents.
- `settings.json` activates `draft:pm-agent` as the main Claude Code thread. Agent names must use the plugin-prefixed form (`draft:<name>`) — Claude Code registers all plugin agents under `<plugin-id>:<agent-name>`.
- `agents/pm-agent.md` — orchestrator agent that owns all PM behavior: orchestration rules, delegation patterns, document writing flow, staleness policy, proactive memory, onboarding detection, and skills reference. No model or maxTurns set — inherits user defaults.
- `scripts/inject-context.sh` — unconditionally runs at `SessionStart` and injects workspace context (workspace tree, context index, priorities, memory) by executing commands directly. Replaces the previous conditional `cat` hook and `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD` approach (Claude Code does not recognize that env var for CLAUDE.md directory scanning).
- `workspace-template/CLAUDE.md` stripped to dynamic context injection only — all behavioral prose moved to `pm-agent.md`. No duplication with the agent system prompt.
- `session-init.sh` adds `Write`, `Read`, and `Edit` permissions for `~/.draft/**` to `~/.claude/settings.json` so Claude can read/write workspace files without prompting. Status messages redirected to stderr.

---

## [1.0.0-beta] — 2026-04-11

Initial release.

### Added
- `SessionStart` hook bootstraps `~/.draft/workspace/` from bundled template on first run
- Hook writes `DRAFT_WORKSPACE`, `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD`, and `additionalDirectories` to `~/.claude/settings.json` so workspace context loads automatically in every future session from any directory
- `@draft-researcher` subagent for retrieving workspace context and web content
- `@draft-executor` subagent for writing product documents (PRDs, decision docs)
- `@draft-learner` subagent for persisting context and memory to `~/.draft/workspace/`
- `/draft:setup` skill for the onboarding interview
- Workspace template with starter context files for all dimensions (company, product, user, team, priorities)

### Platform support
- macOS: supported
- Linux: supported
- Windows: not supported (requires bash; WSL untested)

### Notes
- Workspace lives at `~/.draft/workspace/` — intentionally outside `~/.claude/` so files are accessible by other tools (Codex, etc.)
- Agent files reference `~/.draft/workspace` directly rather than using Claude-specific plugin path variables, to preserve cross-platform portability
