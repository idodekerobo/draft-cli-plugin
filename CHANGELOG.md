# Changelog

All notable changes to the Draft plugin will be documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Version numbers follow [Semantic Versioning](https://semver.org/).

---

## [Unreleased]

### Added — Cursor support
- `scripts/cursor-setup.sh` — one-time setup script for Cursor IDE and Cursor CLI. Installs the `sessionStart` hook, PM brain rules, sub-agent definitions, and the `/draft-setup` skill into `~/.cursor/`. Run via `bash ./scripts/cursor-setup.sh` from the repo root, or `curl -fsSL https://raw.githubusercontent.com/idodekerobo/draft-cli-plugin/main/scripts/cursor-setup.sh | bash`. Detects existing Claude Code and Codex plugin installations and skips anything that would create duplicate PM brain context in Cursor.
- `scripts/cursor-uninstall.sh` — cleanly reverses everything `cursor-setup.sh` installed. Removes the sessionStart hook entry, hook script, rules file, sub-agents, and skill. Preserves `~/.draft/workspace/` (PM brain data is never touched).
- `scripts/cursor-session-start.sh` — `sessionStart` hook script installed to `~/.cursor/hooks/draft/`. Fires on every new Cursor Composer session, outputs `{ "additional_context": "..." }` JSON with the full workspace snapshot (context tree, dimension frontmatter, current priorities, memory). Context is injected silently into initial system context — no user action required.
- `.cursor/rules/draft-context.mdc` — always-on Cursor rules file (`alwaysApply: true`) containing pm-agent orchestrator instructions for Cursor. Installed to `~/.cursor/rules/` only when neither the Claude Code nor Codex plugin is detected (those already supply equivalent instructions via `pm-agent.md` and `AGENTS.md` respectively).
- `.cursor/hooks.json` — in-repo hooks config for development use (when the plugin repo itself is open in Cursor). References `$CURSOR_PROJECT_DIR/scripts/cursor-session-start.sh`.
- `.cursor-plugin/plugin.json` — Cursor marketplace manifest. Bundles rules, skills, sub-agents, and hooks for native Cursor plugin installation. Pending marketplace submission.

**Detection logic:** Cursor natively reads `~/.claude/agents/` and `~/.codex/AGENTS.md`, so installing Draft sub-agents and rules on top of an existing Claude Code or Codex installation creates duplicate PM brain blocks in Cursor's context panel. `cursor-setup.sh` detects each plugin via its sentinel file (`~/.claude/agents/pm-agent.md` for Claude Code, `~/.codex/AGENTS.md` for Codex) and conditionally skips the rules and sub-agent install steps. The `sessionStart` hook is always installed since Cursor requires its own context injection mechanism regardless of other plugins.

**Sub-agents:** `agents/draft-{researcher,executor,learner}.md` are installed to `~/.cursor/agents/` when Claude Code is not detected. When Claude Code is installed, Cursor reads these from `~/.claude/agents/` directly.

### Added — Codex support
- `scripts/codex-setup.sh` — one-time setup script for Codex. Installs SessionStart hook, sub-agent TOML definitions, pm-agent instructions, and the `$draft-setup` skill directly into `~/.codex/` and `~/.agents/skills/`. Run via `curl -fsSL https://raw.githubusercontent.com/idodekerobo/draft-cli-plugin/main/scripts/codex-setup.sh | bash` or `bash ./scripts/codex-setup.sh` from a local clone.
- `scripts/codex-uninstall.sh` — cleanly removes everything the setup script installed. Preserves `~/.draft/workspace/` (PM brain data is never touched).
- `scripts/inject-context.sh` — shared SessionStart hook script. Runs on every Codex session start, injects workspace snapshot (context tree, dimension frontmatter, current priorities, memory) as developer context. Now used by both Claude Code and Codex.
- `.codex/AGENTS.md` — pm-agent instructions for Codex. Installed to `~/.codex/AGENTS.md`. Adapted from `agents/pm-agent.md` for Codex conventions: sub-agent delegation uses Codex spawning language, session context section references the hook.
- `.codex/agents/draft-{researcher,executor,learner}.toml` — Codex custom agent definitions for the three sub-agents. Installed to `~/.codex/agents/` by `codex-setup.sh`.
- `skills/draft-setup/SKILL.md` — onboarding interview skill. Installed to `~/.agents/skills/draft-setup/` by `codex-setup.sh`. Invoked as `$draft-setup` in Codex (the `$` prefix is how Codex invokes skills; slash commands are Codex built-ins only).

**Note on Codex plugin approach:** Codex plugin marketplace distribution was attempted but encountered unresolvable TUI read errors. The direct install approach via `codex-setup.sh` is the working path. `.codex-plugin/` has been removed from the repo.

### Changed — prior unreleased items
- `agents/pm-agent.md` — fixed sub-agent delegation instructions to use fully-qualified agent names (`draft:draft-executor`, `draft:draft-researcher`, `draft:draft-learner`). Previously used short names which caused "agent not found" errors when pm-agent attempted to spawn sub-agents.
- `settings.json` activates `draft:pm-agent` as the main Claude Code thread. Agent names must use the plugin-prefixed form (`draft:<name>`) — Claude Code registers all plugin agents under `<plugin-id>:<agent-name>`.
- `agents/pm-agent.md` — orchestrator agent that owns all PM behavior: orchestration rules, delegation patterns, document writing flow, staleness policy, proactive memory, onboarding detection, and skills reference. No model or maxTurns set — inherits user defaults.
- `scripts/inject-context.sh` — unconditionally runs at `SessionStart` and injects workspace context (workspace tree, context index, priorities, memory) by executing commands directly. Now shared between Claude Code and Codex — `codex-setup.sh` installs it to `~/.codex/hooks/draft/`.
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
