# Draft — Claude Code Plugin

AI-powered PM co-pilot. Gives Claude persistent memory about your product, priorities, and context so every session starts grounded — from any directory.

> **Platform support: macOS and Linux only.** The plugin's session hook is a bash script and requires a POSIX shell environment. Windows (including WSL) is untested and not currently supported.

---

## Plugin structure

```
cli-agent-plugin/
├── .claude-plugin/
│   └── plugin.json               Plugin manifest (name: "draft", v1.0.0-beta)
├── settings.json                 Activates pm-agent as the main Claude Code thread
├── agents/
│   ├── pm-agent.md               Main thread — orchestrator with all PM behavior
│   ├── draft-researcher.md       Finds and retrieves information
│   ├── draft-executor.md         Takes concrete actions (writes docs)
│   └── draft-learner.md          Updates persistent memory files
├── skills/
│   └── setup/SKILL.md            /draft:setup — onboarding interview skill
├── hooks/
│   └── hooks.json                SessionStart → session-init.sh + inject-context.sh
├── scripts/
│   ├── session-init.sh           Guarded bootstrap + settings.json configuration
│   └── inject-context.sh         Unconditional context injection on every session start
├── workspace-template/           Blank workspace copied to ~/.draft/workspace on first run
│   ├── CLAUDE.md                 Dynamic context injection (workspace snapshot — no behavioral prose)
│   ├── context/
│   │   ├── company/index.md
│   │   ├── product/index.md
│   │   ├── priorities/index.md
│   │   ├── team/index.md
│   │   ├── user/index.md
│   │   └── tensions.md
│   └── memory/
│       └── memory.md
└── README.md
```

---

## How it works

### Agent architecture

When the plugin is enabled, `settings.json` activates `draft:pm-agent` as the main Claude Code thread. This means every session opens with the pm-agent system prompt rather than the default Claude Code prompt.

> **Note:** The agent name must be prefixed with `draft:` (the plugin identifier). Claude Code registers all plugin agents under `<plugin-name>:<agent-name>`, so `pm-agent` alone is not found.

`pm-agent` is the orchestrator — it handles all PM work and delegates to three specialized sub-agents:

| Agent | Role |
|---|---|
| `pm-agent` | **Orchestrator.** Owns all PM behavior. Delegates to the three agents below. |
| `draft-researcher` | Need to KNOW something — reads workspace files, fetches web content |
| `draft-executor` | Need to DO something — writes PRDs, decision docs, updates files |
| `draft-learner` | Need to REMEMBER something — updates context files, logs decisions |

Most requests follow: `draft-researcher` gathers context → `draft-executor` acts → `draft-learner` saves.

---

### Context loading

There are two layers of context loaded at session start:

**1. Agent system prompt (`agents/pm-agent.md`) — static**

The pm-agent's instructions are baked in at plugin install time. They define:
- PM role and orchestration behavior
- Delegation rules and when to use each sub-agent
- Document writing flow and template selection
- Context staleness policy (7-day / 21-day)
- Proactive memory rules and what's worth persisting
- Onboarding detection (auto-starts `/draft:setup` interview if no context exists)
- Skills reference for connected integrations

**2. Workspace context (`scripts/inject-context.sh`) — dynamic**

Runs unconditionally on every `SessionStart` via the plugin hook. Executes four commands and outputs the results directly into the session context:

| Command | What it injects |
|---|---|
| `tree` | Two-level directory listing of `context/` — shows what dimensions exist |
| Python script | Frontmatter block from each `context/*/index.md`: `name`, `description`, `last_updated`, `source` |
| `cat priorities/index.md` | Full body of the current priorities file |
| `cat memory/memory.md` | Full body of memory — vocabulary, preferences, patterns, goals |

The pm-agent uses the context summaries as its orientation layer each session. When a task requires more detail than the frontmatter provides, it reads the relevant file in full.

> **Why not `CLAUDE.md` with `!` commands?** `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD` is not a recognized Claude Code setting — it does not cause Claude Code to scan additional directories for `CLAUDE.md` files. `inject-context.sh` runs the commands directly and is guaranteed to work.

---

### Session lifecycle

#### First session (after install)

1. **`SessionStart` hook fires** → runs `scripts/session-init.sh`
2. **Workspace bootstrap** (guarded — runs once):
   - Copies `workspace-template/` → `~/.draft/workspace/`
3. **`~/.claude/settings.json` configuration** (guarded — runs once):
   - Sets `DRAFT_WORKSPACE` env var
   - Adds `~/.draft/workspace` to `additionalDirectories`
   - Adds `Read/Write/Edit` permissions for `~/.draft/**`
4. Settings take effect on the next session start

#### Every subsequent session

1. **`SessionStart` hook fires** → `session-init.sh` guards pass, exits in <10ms
2. **`inject-context.sh` runs** — executes context commands and outputs live workspace state
3. **`draft:pm-agent` activates** as the main thread (via `settings.json`)
4. **pm-agent is oriented** — knows what context dimensions exist, how fresh they are, current priorities, and memory

If the workspace has no context yet, the dynamic sections fall back to "No context loaded yet — run /draft:setup."

---

## Path conventions

| Variable | Resolves to | Used in |
|---|---|---|
| `$DRAFT_WORKSPACE` | `~/.draft/workspace` (set by `session-init.sh`) | `CLAUDE.md` `!` commands, agent instructions |

All agent files reference `$DRAFT_WORKSPACE` for file paths. The workspace lives outside `~/.claude/` intentionally — so the same files can be read by other tools (Codex, etc.) without requiring Claude Code-specific path resolution.

---

## Testing locally

```bash
# Load the plugin for a single session (dev/test)
claude --plugin-dir ./cli-agent-plugin

# After first session, verify settings were written
cat ~/.claude/settings.json | python3 -m json.tool

# Run the setup interview
/draft:setup

# Verify workspace was created
ls ~/.draft/workspace/
```
