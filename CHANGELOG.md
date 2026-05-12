# Changelog

All notable changes to the Draft plugin will be documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Version numbers follow [Semantic Versioning](https://semver.org/).

---

## [Unreleased]

---

## [1.5.0] — 2026-05-12

### Added — Team context sharing

**Three new skills:**

- `skills/draft-setup-collab/SKILL.md` — `/draft:setup-collab` configures team collaboration: checks gh CLI auth, lets the curator choose or create a shared GitHub repo, writes `config/collaboration.md` + `config/local.md`, and auto-seeds the shared repo on first use. Can be run standalone or invoked inline from `/draft:setup` Q5.5.
- `skills/draft-publish-team/SKILL.md` — `/publish-team` publishes the curator's local context to the shared repo. Reads log entries since last publish, builds `CHANGES.jsonl` (append-only, deterministic IDs via sha256), pushes via the separate-clone pattern. Supports `--no-confirm` flag for automation.
- `skills/draft-load-team/SKILL.md` — `/load-team` pulls the latest team context from the shared repo directly into `context/`. Reads `CHANGES.jsonl`, filters to entries since `last_loaded`, deduplicates by ID, writes updated context files. Personal layer is never touched.

**Workspace restructure — personal layer:**

- `workspace-template/personal/user/index.md` — personal layer for working style and preferences (moved from `context/user/index.md`). Never shared with the team.
- `workspace-template/personal/memory.md` — personal layer for dynamic AI learnings (moved from `memory/memory.md`). Never shared with the team.
- `workspace-template/personal/wip/.gitkeep` — scaffolds `wip/` for drafts not ready to share.
- `workspace-template/context/user/index.md` — DELETED. User context now lives in `personal/user/index.md`.
- `workspace-template/memory/memory.md` — DELETED. Memory now lives in `personal/memory.md`.

**Workspace restructure — log directories:**

- `workspace-template/context/company/log/.gitkeep` — scaffolds append-only log for company dimension.
- `workspace-template/context/product/log/.gitkeep` — scaffolds append-only log for product dimension.
- `workspace-template/context/team/log/.gitkeep` — scaffolds append-only log for team dimension.
- `workspace-template/context/priorities/log/.gitkeep` — scaffolds append-only log for priorities dimension.

**Key data structures:**

- `config/collaboration.md` — shared config (mode, team_repo_url, team_repo_subdir, repo_is_private, teammates). Written by `/draft:setup-collab`, pushed by `/publish-team`, merged by `/load-team`. Lives in the shared repo.
- `config/local.md` — machine state (gh_cli_authenticated, last_published, last_loaded). Written by `/draft:setup-collab`. Never pushed to shared repo.
- `CHANGES.jsonl` — append-only change record in the shared repo. IDs are deterministic sha256 hashes. Foundation for all future rendering surfaces (Slack, web, Drive).

### Changed

- `skills/draft-setup/SKILL.md` — added Q5.5 (collaboration question after Q5, before Q6). If yes → invokes `/draft:setup-collab` inline. Updated workspace layout in welcome orientation. Updated "After the interview" file paths: `context/user/index.md` → `personal/user/index.md`, `memory/memory.md` → `personal/memory.md`.
- `agents/pm-agent.md` — updated session context description (user dimension moved to personal layer). Added personal/ layer and collaboration config awareness to workspace layout. Updated all memory path references from `memory/memory.md` → `personal/memory.md`.
- `scripts/inject-context.sh` — updated memory block to read from `personal/memory.md`. Added collaboration status block (reads `config/collaboration.md` + `config/local.md`; only fires when collaboration is configured).
- `workspace-template/CLAUDE.md` — updated memory path from `memory/memory.md` → `personal/memory.md` (Cursor session context injection).
- `scripts/codex-setup.sh` — updated workspace bootstrap: `context/user` removed (user moves to `personal/user`), `memory/` removed (memory moves to `personal/`), `personal/user` and `personal/wip` created, `context/*/log/` directories scaffolded. Added install blocks for `draft-setup-collab`, `draft-publish-team`, `draft-load-team` skills.
- `scripts/cursor-setup.sh` — added install blocks for `draft-setup-collab`, `draft-publish-team`, `draft-load-team` skills.
- `.cursor-plugin/plugin.json` — registered `draft-setup-collab`, `draft-publish-team`, `draft-load-team`. Version bumped to 1.5.0.
- `VERSION` — bumped to 1.5.0.
- `skills/draft-update/SKILL.md` — `/draft:update` now uses the `AskUserQuestion` tool for confirmation before running the update and before workspace migration. Added Step 3.5: intelligent v1.5 workspace migration. When upgrading from a version below 1.5.0, the skill detects old workspace paths (`context/user/index.md`, `memory/memory.md`), explains the structural change to the user, confirms before acting, moves files to the new `personal/` layout, scans for any additional user-added files, and creates `config/` scaffolding if absent. Migration is skipped if already on the new layout.

### Architecture notes

- **Separate-clone pattern:** The Draft workspace (`~/.draft/workspace`) is never initialized as a git repo. All git operations for `/publish-team` and `/load-team` run in short-lived temp directories (`mktemp -d`), then clean up. This keeps workspace files safe from accidental commits and makes the sharing mechanism storage-agnostic.
- **Single curator:** `/publish-team` is the write path; `/load-team` is read-only for teammates. Multi-curator (write contention, merge resolution) is planned for a future release.
- **Load-team writes to context/ directly:** After `/load-team`, the teammate's `context/` IS the shared brain. No separate team-snapshot/ directory. The `personal/` layer is structurally separated and untouched by any team operation.
- **CHANGES.jsonl is the foundation:** All future rendering surfaces (web UI, Slack digest, Drive sync) must read from `CHANGES.jsonl`. Do not build parallel change records — they will diverge.

### Known gaps (deferred TODOs)

1. **Atomic write for /load-team** — `/load-team` now writes directly to the active `context/` layer. A partial file copy (process killed mid-copy) would leave the agent's live context in an inconsistent state. Mitigation: write to `context/.loading-tmp/` first, rename atomically on success. Prioritize before wider rollout.
2. Shallow clone for publish + load (after 50+ commits)
3. Auto-notification at session start ("team context updated X days ago — run /load-team?")
4. CHANGES.md rendered file for non-technical teammates
5. `/invite-teammate` skill — deferred; GitHub UI is sufficient for collaborator management in beta

---

## [1.4.0] — 2026-05-08

### Changed — Simplified workspace structure

- `context/decisions/` is now the single destination for all decisions. Previously, agent instructions split decisions between `context/decisions/` (for lightweight decisions via `/draft:learn`) and `docs/decisions/` (for full FANG-format docs via `draft-executor`). This inconsistency caused the agent to write to the wrong path. Now all decisions — regardless of how they were created — go to `context/decisions/{slug}.md`.
- `docs/` is now defined as a flat folder of written artifacts (analyses, PRDs, strategies, specs). Files must follow the naming convention `YYYYMMDDHHMMSS_descriptive-slug.md`. No subdirectories inside `docs/`.
- Removed all references to `templates/` from agent instructions and skill files. Template references were aspirational and not backed by actual files — removing them eliminates confusion.
- `workspace-template/context/decisions/` — added `.gitkeep` placeholder so the `decisions/` directory is scaffolded on fresh installs.
- `workspace-template/docs/` — added `.gitkeep` placeholder so `docs/` is scaffolded on fresh installs.
- `agents/draft-executor.md` — updated "Where to write" section with the new routing rules.
- `agents/pm-agent.md` — updated workspace layout reference; removed `templates/` line; added docs naming convention note in document writing section.
- `skills/draft-setup/SKILL.md` — updated welcome orientation tree to show `context/decisions/` and the new `docs/` description. Removed `templates/` from tree.

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
