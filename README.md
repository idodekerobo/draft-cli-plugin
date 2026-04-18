# Draft — Claude Code + Codex CLI

AI-powered PM co-pilot. Gives your AI CLI persistent memory about your product, priorities, and context so every session starts grounded — from any directory.

> **Platform support: macOS and Linux only.** The plugin's session hook is a bash script and requires a POSIX shell environment. Windows (including WSL) is untested and not currently supported.

---

## Installation

### Claude Code

**Option 1 — Plugin marketplace (recommended):**

```bash
/plugin marketplace add idodekerobo/draft-cli-plugin
/plugin install draft
```

Then run the setup interview:

```
/draft:setup
```

**Option 2 — Local install (for testing/development):**

```bash
claude --plugin-dir ./draft-cli-plugin
/draft:setup
```

The plugin's `SessionStart` hook handles everything else automatically on first launch.

### Codex

This is a **direct install**, not a Codex plugin. The setup script writes directly into your `~/.codex/` directory — no plugin marketplace involved.

**Option 1 — curl (no clone needed):**

```bash
curl -fsSL https://raw.githubusercontent.com/idodekerobo/draft-cli-plugin/main/scripts/codex-setup.sh | bash
```

**Option 2 — from a local clone:**

```bash
bash ./scripts/codex-setup.sh
```

The script installs seven things:
1. Creates `~/.draft/workspace/` with a blank context/memory structure
2. Installs `inject-context.sh` to `~/.codex/hooks/draft/`
3. Registers the `SessionStart` hook in `~/.codex/hooks.json`
4. Enables the `codex_hooks` feature flag in `~/.codex/config.toml`
5. Installs sub-agent TOML files to `~/.codex/agents/`
6. Writes pm-agent instructions to `~/.codex/AGENTS.md`
7. Installs the `$draft-setup` skill to `~/.agents/skills/draft-setup/SKILL.md`

After the script completes, restart Codex, then run:

```
$draft-setup
```

> **Note on `$` prefix:** `$draft-setup` is how Codex invokes skills. The `$` prefix is Codex-specific — slash commands (like `/draft:setup`) are Codex built-ins only and cannot be extended by external installs.

---

## How it works

### Agent architecture

Draft uses an orchestrator + three sub-agents pattern. The pm-agent is the main thread — it handles all PM work and delegates to specialists.

| Agent | Role |
|---|---|
| `pm-agent` | **Orchestrator.** Owns all PM behavior. Delegates to the three agents below. |
| `draft-researcher` | Need to KNOW something — reads workspace files, fetches web content |
| `draft-executor` | Need to DO something — writes PRDs, decision docs, updates files |
| `draft-learner` | Need to REMEMBER something — updates context files, logs decisions |

Most requests follow: `draft-researcher` gathers context → `draft-executor` acts → `draft-learner` saves.

#### Claude Code
`settings.json` activates `draft:pm-agent` as the main Claude Code thread. Every session opens with the pm-agent system prompt rather than the default Claude Code prompt.

#### Codex
`~/.codex/AGENTS.md` contains the pm-agent instructions and loads as persistent context for every Codex session. Sub-agents are installed as custom agent `.toml` files in `~/.codex/agents/`.

---

### Context loading

There are two layers of context loaded at session start:

**1. Agent system prompt — static**

The pm-agent's instructions define:
- PM role and orchestration behavior
- Delegation rules and when to use each sub-agent
- Document writing flow and template selection
- Context staleness policy (7-day / 21-day)
- Proactive memory rules and what's worth persisting
- Onboarding detection (auto-starts setup interview if no context exists)

**2. Workspace context (`scripts/inject-context.sh`) — dynamic**

Runs on every `SessionStart` via hook. Executes four commands and outputs the results directly into the session context:

| Command | What it injects |
|---|---|
| `tree` | Two-level directory listing of `context/` |
| Python script | Frontmatter from each `context/*/index.md`: name, description, last_updated, source |
| `cat priorities/index.md` | Full current priorities file |
| `cat memory/memory.md` | Full memory — vocabulary, preferences, patterns, goals |

The pm-agent uses this as its orientation layer. When a task needs more detail than the frontmatter provides, it reads the relevant file in full.

---

### Session lifecycle

#### Claude Code — first session (after install)

1. **`SessionStart` hook fires** → runs `scripts/session-init.sh`
2. **Workspace bootstrap** (guarded — runs once): copies `workspace-template/` → `~/.draft/workspace/`
3. **`~/.claude/settings.json` updated** (guarded — runs once): sets `DRAFT_WORKSPACE` env var, adds `~/.draft/workspace` to `additionalDirectories`, grants `Read/Write/Edit` for `~/.draft/**`
4. Settings take effect on the next session start

#### Claude Code — every subsequent session

1. `session-init.sh` guards pass, exits in <10ms
2. `inject-context.sh` runs — outputs live workspace snapshot into session context
3. `draft:pm-agent` activates as main thread
4. pm-agent is oriented: context dimensions, freshness, priorities, memory

#### Codex — after running `codex-setup.sh`

1. `SessionStart` hook fires → `inject-context.sh` runs, outputs workspace snapshot as developer context
2. `~/.codex/AGENTS.md` (pm-agent instructions) loads as persistent context
3. pm-agent is oriented and ready

---

## Plugin structure

```
draft-cli-plugin/
├── .claude-plugin/
│   ├── plugin.json               Claude Code plugin manifest
│   └── marketplace.json          Plugin marketplace catalog
├── .codex/
│   ├── AGENTS.md                 pm-agent instructions for Codex (installed to ~/.codex/AGENTS.md)
│   └── agents/
│       ├── draft-researcher.toml Codex sub-agent definition
│       ├── draft-executor.toml   Codex sub-agent definition
│       └── draft-learner.toml    Codex sub-agent definition
├── agents/
│   ├── pm-agent.md               Claude Code — main orchestrator agent
│   ├── draft-researcher.md       Claude Code — researcher sub-agent
│   ├── draft-executor.md         Claude Code — executor sub-agent
│   └── draft-learner.md          Claude Code — learner sub-agent
├── skills/
│   └── draft-setup/SKILL.md      /draft:setup (Claude Code) / $draft-setup (Codex) — onboarding interview
├── hooks/
│   └── hooks.json                Claude Code SessionStart hooks
├── scripts/
│   ├── session-init.sh           Claude Code — guarded bootstrap + settings.json configuration
│   ├── inject-context.sh         Shared — context injection (runs on every session start)
│   ├── codex-setup.sh            Codex — one-time setup script (curl or local clone)
│   └── codex-uninstall.sh        Codex — removes everything codex-setup.sh installed
├── workspace-template/           Blank workspace, copied to ~/.draft/workspace on first run
│   ├── CLAUDE.md
│   ├── context/
│   │   ├── company/index.md
│   │   ├── product/index.md
│   │   ├── priorities/index.md
│   │   ├── team/index.md
│   │   ├── user/index.md
│   │   └── tensions.md
│   └── memory/
│       └── memory.md
├── README.md
└── CHANGELOG.md
```

---

## Workspace layout

Both Claude Code and Codex share the same workspace at `~/.draft/workspace/`:

```
~/.draft/workspace/
├── context/
│   ├── company/index.md + log/
│   ├── product/index.md + log/
│   ├── user/index.md
│   ├── team/index.md + log/
│   ├── priorities/index.md + log/
│   ├── decisions/
│   └── tensions.md
├── memory/
│   └── memory.md
├── docs/
│   ├── prds/
│   └── decisions/
└── templates/
    ├── prd.md
    └── fang-decision-doc.md
```

The workspace lives outside `~/.claude/` and `~/.codex/` intentionally — it's shared across both CLIs.

---

## Path conventions

| Variable | Resolves to | Set by |
|---|---|---|
| `$DRAFT_WORKSPACE` | `~/.draft/workspace` | `session-init.sh` (Claude Code) / `codex-setup.sh` (Codex) |

---

## Testing locally

### Claude Code

```bash
# Load the plugin for a single session
claude --plugin-dir ./draft-cli-plugin

# Verify settings were written after first session
cat ~/.claude/settings.json | python3 -m json.tool

# Run setup
/draft:setup

# Verify workspace
ls ~/.draft/workspace/
```

### Codex

```bash
# Run the setup script directly from the plugin repo
bash ./scripts/codex-setup.sh

# Verify hook was registered
cat ~/.codex/hooks.json | python3 -m json.tool

# Verify agents were installed
ls ~/.codex/agents/

# Verify AGENTS.md was written
head -5 ~/.codex/AGENTS.md

# Verify the skill was installed
ls ~/.agents/skills/

# Restart Codex, then run setup
$draft-setup

# To uninstall
bash ./scripts/codex-uninstall.sh
```
