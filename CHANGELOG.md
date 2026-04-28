# Changelog

All notable changes to the Draft plugin will be documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Version numbers follow [Semantic Versioning](https://semver.org/).

---

## [1.3.0] — 2026-04-27

### Added — Self-update system

- `VERSION` (repo root) — source of truth for the current release. Session hooks read this to record the installed version. The remote copy on `main` is what the update check compares against.
- `scripts/draft-update-check.sh` — background version check. Compares `~/.draft/version` against the raw `VERSION` file on `main`. Writes `UP_TO_DATE <ver>` or `UPGRADE_AVAILABLE <old> <new>` to `~/.draft/last-update-check` with TTL caching (60 min if current, 720 min if upgrade available). Never blocks session start — fires as a background process.
- `scripts/draft-update.sh` — self-update script. Fetches the latest release tag from the GitHub Releases API, detects installed platforms (Codex, Cursor) via sentinel files, and re-downloads all installed files at the new tag. Updates `~/.draft/version` and resets the update cache on completion. Never touches `~/.draft/workspace/` (user PM brain data).
- `skills/draft-update/SKILL.md` — `/draft:update` slash command (`$draft-update` on Codex, `/draft-update` on Cursor). Shows current and available version, asks for confirmation, runs the update script, summarizes the CHANGELOG between old and new versions, reminds user to restart.

### Changed

- `scripts/session-init.sh` — records installed plugin version to `~/.draft/version` and copies `draft-update-check.sh` + `draft-update.sh` to `~/.draft/scripts/` on every Claude Code session start. Ensures Codex/Cursor users' shared scripts stay in sync with the Claude Code plugin version after a plugin update.
- `scripts/inject-context.sh` — reads `~/.draft/last-update-check` and appends a `## Draft Update Available` notice to session context when an upgrade is waiting. Fires update check in background at session end so the result is cached for next session.
- `scripts/cursor-session-start.sh` — same update notice logic added to the `additional_context` JSON output. Also fires background update check.
- `scripts/codex-setup.sh` — installs shared update scripts to `~/.draft/scripts/`, installs `draft-update` skill to `~/.agents/skills/draft-update/`, records installed version to `~/.draft/version`.
- `scripts/cursor-setup.sh` — same additions; also installs `draft-update` skill to `~/.cursor/skills/draft-update/`.
- `scripts/codex-uninstall.sh` — removes `draft-update` skill; cleans up `~/.draft/scripts/` and `~/.draft/last-update-check` unless Cursor is also installed.
- `scripts/cursor-uninstall.sh` — same; checks for Codex before removing shared scripts.
- `agents/pm-agent.md` — added explicit instruction to surface update notifications when `## Draft Update Available` is present in session context.

**Release workflow (for maintainer):**
1. Bump `VERSION` and `version` in `.claude-plugin/plugin.json`
2. Commit and push
3. `git tag v1.x.x && git push origin v1.x.x`
4. `gh release create v1.x.x --title "v1.x.x" --notes "..."`

---

## [1.2.0] — 2026-04-20

### Added — `/draft:learn` skill

- `skills/draft-learn/SKILL.md` — new slash command for manually saving learnings to the Draft workspace. Supports three invocation modes:
  - **No args** (`/draft:learn`) — conversational mode. Asks one question ("What did you learn or decide?"), then routes the answer automatically.
  - **Free-form statement** (`/draft:learn we decided to drop the bridge daemon`) — classifies the learning by content and routes to the appropriate file(s) without requiring the user to specify a type. Only asks a clarifying question if classification is genuinely ambiguous.
  - **Explicit tag** (`/draft:learn [decision] drop the bridge daemon`) — bypasses inference entirely and writes directly to the tagged destination. Supported tags: `[decision]`, `[priority]`, `[product]`, `[company]`, `[team]`, `[memory]`, `[pref]`, `[vocab]`.
- Classification routes to the correct workspace file and writes a log entry where appropriate: `context/decisions/`, `context/priorities/index.md`, `context/product/index.md`, `context/company/index.md`, `context/team/index.md`, or `memory/memory.md`. A single learning can update multiple files when the content spans dimensions (e.g. a decision that affects both product direction and the current sprint).
- Updated `scripts/codex-setup.sh` — installs `draft-learn` skill to `~/.agents/skills/draft-learn/` alongside `draft-setup`. Codex requires explicit skill installation; it does not auto-discover.
- Updated `scripts/codex-uninstall.sh` — removes `~/.agents/skills/draft-learn/` on uninstall.
- Updated `scripts/cursor-setup.sh` — installs `draft-learn` skill to `~/.cursor/skills/draft-learn/` and `~/.agents/skills/draft-learn/`.
- Updated `scripts/cursor-uninstall.sh` — removes both `draft-learn` skill paths on uninstall.

**Platform invocation:**
| Platform | Command |
|---|---|
| Claude Code | `/draft:learn` (auto-discovered) |
| Codex | `$draft-learn` |
| Cursor | `/draft-learn` |

---

## [1.1.0] — 2026-04-18

### Added — Cursor support

- `scripts/cursor-setup.sh` — one-time setup script for Cursor IDE and Cursor CLI. Installs the `sessionStart` hook, PM brain rules, sub-agent definitions, and the `/draft-setup` skill into `~/.cursor/`. Run via `bash ./scripts/cursor-setup.sh` from the repo root, or `curl -fsSL https://raw.githubusercontent.com/idodekerobo/draft-cli-plugin/main/scripts/cursor-setup.sh | bash`. Detects existing Claude Code and Codex plugin installations and skips anything that would create duplicate PM brain context in Cursor.
- `scripts/cursor-uninstall.sh` — cleanly reverses everything `cursor-setup.sh` installed. Removes the sessionStart hook entry, hook script, rules file, sub-agents, and skill. Preserves `~/.draft/workspace/` (PM brain data is never touched).
- `scripts/cursor-session-start.sh` — `sessionStart` hook script installed to `~/.cursor/hooks/draft/`. Fires on every new Cursor Composer session, outputs `{ "additional_context": "..." }` JSON with the full workspace snapshot (context tree, dimension frontmatter, current priorities, memory). Context is injected silently into initial system context — no user action required.
- `.cursor/rules/draft-context.mdc` — always-on Cursor rules file (`alwaysApply: true`) containing pm-agent orchestrator instructions for Cursor. Installed to `~/.cursor/rules/` only when neither the Claude Code nor Codex plugin is detected (those already supply equivalent instructions via `pm-agent.md` and `AGENTS.md` respectively).
- `.cursor/hooks.json` — in-repo hooks config for development use (when the plugin repo itself is open in Cursor). References `$CURSOR_PROJECT_DIR/scripts/cursor-session-start.sh`.
- `.cursor-plugin/plugin.json` — Cursor marketplace manifest. Bundles rules, skills, sub-agents, and hooks for native Cursor plugin installation. Pending marketplace submission.

**Detection logic:** Cursor natively reads `~/.claude/agents/` and `~/.codex/AGENTS.md`, so installing Draft sub-agents and rules on top of an existing Claude Code or Codex installation creates duplicate PM brain blocks in Cursor's context panel. `cursor-setup.sh` detects each plugin via its sentinel file (`~/.claude/agents/pm-agent.md` for Claude Code, `~/.codex/AGENTS.md` for Codex) and conditionally skips the rules and sub-agent install steps. The `sessionStart` hook is always installed since Cursor requires its own context injection mechanism regardless of other plugins.

**Sub-agents:** `agents/draft-{researcher,executor,learner}.md` are installed to `~/.cursor/agents/` when Claude Code is not detected. When Claude Code is installed, Cursor reads these from `~/.claude/agents/` directly.

---

## [1.0.0] — 2026-04-17

First official release. Adds Codex CLI support and publishes the plugin to the Claude Code marketplace.

### Added — Codex support

- `scripts/codex-setup.sh` — one-time setup script for Codex. Installs SessionStart hook, sub-agent TOML definitions, pm-agent instructions, and the `$draft-setup` skill directly into `~/.codex/` and `~/.agents/skills/`. Run via `curl -fsSL https://raw.githubusercontent.com/idodekerobo/draft-cli-plugin/main/scripts/codex-setup.sh | bash` or `bash ./scripts/codex-setup.sh` from a local clone.
- `scripts/codex-uninstall.sh` — cleanly removes everything the setup script installed. Preserves `~/.draft/workspace/` (PM brain data is never touched).
- `.codex/AGENTS.md` — pm-agent instructions for Codex. Installed to `~/.codex/AGENTS.md`. Adapted from `agents/pm-agent.md` for Codex conventions: sub-agent delegation uses Codex spawning language, session context section references the hook.
- `.codex/agents/draft-{researcher,executor,learner}.toml` — Codex custom agent definitions for the three sub-agents. Installed to `~/.codex/agents/` by `codex-setup.sh`.
- `.claude-plugin/marketplace.json` — plugin marketplace catalog entry. Enables installation via `/plugin marketplace add idodekerobo/draft-cli-plugin`.

**Note on Codex plugin approach:** Codex plugin marketplace distribution was attempted but encountered unresolvable TUI read errors. The direct install approach via `codex-setup.sh` is the working path. `.codex-plugin/` has been removed from the repo.

### Changed

- `scripts/inject-context.sh` — now shared between Claude Code and Codex. `codex-setup.sh` installs it to `~/.codex/hooks/draft/`. Runs unconditionally at `SessionStart` and injects workspace snapshot (context tree, context index, priorities, memory) as developer context.
- `agents/pm-agent.md` — sub-agent delegation instructions updated to use fully-qualified agent names (`draft:draft-executor`, `draft:draft-researcher`, `draft:draft-learner`). Previously used short names which caused "agent not found" errors when pm-agent attempted to spawn sub-agents.
- `agents/pm-agent.md` — orchestrator agent now fully owns all PM behavior: orchestration rules, delegation patterns, document writing flow, staleness policy, proactive memory, onboarding detection, and skills reference. No model or maxTurns set — inherits user defaults.
- `workspace-template/CLAUDE.md` — stripped to dynamic context injection only. All behavioral prose moved to `pm-agent.md` to eliminate duplication with the agent system prompt.
- `session-init.sh` — adds `Write`, `Read`, and `Edit` permissions for `~/.draft/**` to `~/.claude/settings.json` so Claude can read/write workspace files without prompting. Status messages redirected to stderr.
- `settings.json` — activates `draft:pm-agent` as the main Claude Code thread. Agent names use the plugin-prefixed form (`draft:<name>`) — Claude Code registers all plugin agents under `<plugin-id>:<agent-name>`.

---

## [1.0.0-beta] — 2026-04-11

Initial beta release. Claude Code only.

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
