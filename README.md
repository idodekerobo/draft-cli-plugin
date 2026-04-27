# Draft — Claude Code + Codex CLI + Cursor

**Draft is a PM brain for Claude Code, Codex CLI, and Cursor.** Install it once, run `/setup`, and every session starts with full product context — no re-explaining required.

> **Platform support: macOS and Linux only.** The plugin's session hook is a bash script and requires a POSIX shell environment. Windows (including WSL) is untested and not currently supported.

---

## Quick start

### Claude Code

```bash
/plugin marketplace add idodekerobo/draft-cli-plugin
/plugin install draft
/draft:setup
```

### Codex

```bash
curl -fsSL https://raw.githubusercontent.com/idodekerobo/draft-cli-plugin/main/scripts/codex-setup.sh | bash
```

Restart Codex, then run:

```
$draft-setup
```

### Cursor

```bash
curl -fsSL https://raw.githubusercontent.com/idodekerobo/draft-cli-plugin/main/scripts/cursor-setup.sh | bash
```

Restart Cursor. Your product context loads automatically into every new Composer session — no action needed. If this is your first time using Draft, run `/draft-setup` in the Agent tab.

---

## Why Draft

You open a new Claude session. It doesn't know what you shipped last week. It doesn't know you changed the ICP. It doesn't know you dropped that feature. You're back to square one — again.

That's the default. Every session starts blank.

Draft fixes two things that make this worse over time:

**Context amnesia** — the blank slate problem. Without Draft, you're re-explaining your product, your stack, your priorities at the start of every session. It's not just annoying — it means Claude is reasoning from whatever scraps you happened to paste in, not from a real picture of what you're building. Draft's session hook injects a live snapshot of your full product context (company, product, team, priorities, memory) before you type a single word.

**Context rot** — the slow decay problem. Even if you have a `CLAUDE.md` or context files, they go stale. You shipped something, changed direction, dropped a bet — and your docs still describe the old world. The longer you work, the more your context diverges from reality. Claude is confidently reasoning from a version of your product that no longer exists.

Draft solves this with an append-only log and a persistent index of recent changes. Every time something meaningful happens — a decision, a scope change, something shipped or dropped — `draft-learner` logs it and updates the index. That index loads in every session automatically. So even if your full context documents haven't been touched in weeks, the session always knows what just happened.

The feeling: your AI tool behaves like a collaborator who was in every previous session — not a new hire you brief from scratch each time.

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

---

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

To uninstall:

```bash
bash ./scripts/codex-uninstall.sh
```

---

### Cursor

This is a **direct install** into `~/.cursor/`. The setup script is smart about what it installs — if the Claude Code or Codex plugin is already installed, it skips anything that would create a duplicate PM brain in Cursor's context (see [Multi-editor setup](#multi-editor-setup) below).

**Option 1 — curl (no clone needed):**

```bash
curl -fsSL https://raw.githubusercontent.com/idodekerobo/draft-cli-plugin/main/scripts/cursor-setup.sh | bash
```

**Option 2 — from a local clone:**

```bash
bash ./scripts/cursor-setup.sh
```

The script installs:
1. Creates `~/.draft/workspace/` if it doesn't already exist
2. Installs `cursor-session-start.sh` to `~/.cursor/hooks/draft/`
3. Registers the `sessionStart` hook in `~/.cursor/hooks.json`
4. [If no Claude Code/Codex plugin] Installs `draft-context.mdc` to `~/.cursor/rules/`
5. [If no Claude Code plugin] Installs sub-agents to `~/.cursor/agents/`
6. Installs the `/draft-setup` skill to `~/.cursor/skills/` and `~/.agents/skills/`

After the script completes, **restart Cursor**. Your product context will be automatically injected into every new Agent tab (Composer) session — you don't need to do anything. The injection happens silently in the background via the `sessionStart` hook.

If this is a fresh Draft install, open the Agent tab and run:

```
/draft-setup
```

To uninstall:

```bash
bash ./scripts/cursor-uninstall.sh
```

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

Most requests follow: `draft-researcher` gathers context → `draft-executor` acts → `draft-learner` saves. You can also invoke `draft-learner` directly — run `/draft:learn` anytime to capture a decision, scope change, or anything worth remembering outside of a full PM session.

---

### Slash commands

Draft ships two slash commands (skills). Both are auto-discovered by Claude Code, and manually installed by the Codex and Cursor setup scripts.

#### `/draft:setup` (`$draft-setup` on Codex, `/draft-setup` on Cursor)

Runs the PM brain initialization interview. Ask it once at install, or again after a significant product shift. See [Quick start](#quick-start).

---

#### `/draft:learn` (`$draft-learn` on Codex, `/draft-learn` on Cursor)

Manually tells Draft to remember something — a decision you made, a priority that shifted, a term your team uses, anything worth persisting to your workspace. You can call it three ways:

**1. No arguments — conversational**

```
/draft:learn
```

Draft asks one question: *"What did you learn or decide?"* You answer, it figures out where to write it, confirms what it saved.

Best when: you want to capture something but haven't formed it into a statement yet.

---

**2. Free-form statement**

```
/draft:learn we decided to drop the bridge daemon and go plugin-only
```

Draft reads the statement, classifies the type of learning (decision, priority shift, product direction, company update, team change, or preference), routes it to the right file(s), and confirms. It will only ask a clarifying question if the classification is genuinely ambiguous — most statements are clear enough to route automatically.

Best when: you know what you want to save and just want to say it.

---

**3. Explicit tag**

```
/draft:learn [decision] drop the bridge daemon
/draft:learn [priority] bridge daemon is now deferred
/draft:learn [product] ICP is now "the curator" — one high-agency PM who owns source of truth
/draft:learn [vocab] "builders" = PMs and founders using Claude Code
```

The tag tells Draft exactly where to write without any inference. Supported tags: `[decision]`, `[priority]`, `[product]`, `[company]`, `[team]`, `[memory]`, `[pref]`, `[vocab]`.

Best when: you know the type and want the fastest, most predictable path.

---

**What gets written and where**

| Learning type | Destination | Log entry? |
|---|---|---|
| `[decision]` | `context/decisions/{slug}.md` | No (plus any affected index files) |
| `[priority]` | `context/priorities/index.md` | Yes |
| `[product]` | `context/product/index.md` | Yes |
| `[company]` | `context/company/index.md` | Structural changes only |
| `[team]` | `context/team/index.md` | Structural changes only |
| `[memory]` / `[pref]` / `[vocab]` | `memory/memory.md` | No |

A single learning can map to multiple files. "We decided to cut the bridge daemon" writes a decision file, updates `context/product/index.md`, and updates `context/priorities/index.md` — because all three reflect the new reality.

#### Claude Code
`settings.json` activates `draft:pm-agent` as the main Claude Code thread. Every session opens with the pm-agent system prompt rather than the default Claude Code prompt.

#### Codex
`~/.codex/AGENTS.md` contains the pm-agent instructions and loads as persistent context for every Codex session. Sub-agents are installed as custom agent `.toml` files in `~/.codex/agents/`.

#### Cursor
`~/.cursor/rules/draft-context.mdc` (installed with `alwaysApply: true`) contains the pm-agent instructions and is injected into every Agent tab session. Sub-agents are available in `~/.cursor/agents/` and invocable by name in the Agent tab. When Claude Code is also installed, Cursor reads `~/.claude/agents/` directly and `draft-context.mdc` is skipped to avoid duplication.

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

**2. Workspace context — dynamic**

Injected on every session start via hook. Outputs a live snapshot of:

| Section | What it contains |
|---|---|
| Workspace structure | Two-level directory listing of `context/` |
| Context index | Frontmatter from each `context/*/index.md`: name, description, last_updated, source |
| Current priorities | Full `context/priorities/index.md` |
| Memory | Full `memory/memory.md` — vocabulary, preferences, patterns, goals |

The pm-agent uses this as its orientation layer. When a task needs more detail than the frontmatter provides, it reads the relevant file in full.

| Editor | Hook mechanism | Output format |
|---|---|---|
| Claude Code | `SessionStart` → `inject-context.sh` | Raw text into session context |
| Codex | `SessionStart` → `inject-context.sh` | Raw text as developer context |
| Cursor | `sessionStart` → `cursor-session-start.sh` | `{ "additional_context": "..." }` JSON into initial system context |

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

#### Cursor — after running `cursor-setup.sh`

1. New Agent tab (Composer) session opens
2. `sessionStart` hook fires → `cursor-session-start.sh` runs silently in the background
3. Workspace snapshot injected as initial system context via `additional_context`
4. `draft-context.mdc` rule loaded (if Claude Code plugin is not also installed)
5. pm-agent is oriented and ready — context loads before you type your first message

---

### Multi-editor setup

Draft's workspace at `~/.draft/workspace/` is shared across all editors. Running setup for multiple editors does not create multiple workspaces — it just connects each editor to the same PM brain.

**If you use Claude Code + Cursor:** Run `claude plugin install` first, then `cursor-setup.sh`. The Cursor setup script detects the Claude Code plugin and skips installing duplicate rules and sub-agents. Cursor reads `~/.claude/agents/` natively.

**If you use Codex + Cursor:** Run `codex-setup.sh` first, then `cursor-setup.sh`. The Cursor setup script detects `~/.codex/AGENTS.md` and skips the rules install. Sub-agents are still installed to `~/.cursor/agents/` since Cursor does not read `~/.codex/agents/` natively.

**If you use all three:** Claude Code install first, then Codex, then Cursor. Cursor will use Claude Code's agents and skip its own rules install.

---

## Plugin structure

```
draft-cli-plugin/
├── .claude-plugin/
│   ├── plugin.json               Claude Code plugin manifest
│   └── marketplace.json          Plugin marketplace catalog
├── .codex/
│   ├── AGENTS.md                 pm-agent instructions for Codex (→ ~/.codex/AGENTS.md)
│   └── agents/
│       ├── draft-researcher.toml Codex sub-agent definition
│       ├── draft-executor.toml   Codex sub-agent definition
│       └── draft-learner.toml    Codex sub-agent definition
├── .cursor/
│   ├── hooks.json                In-repo Cursor hooks config (dev use)
│   └── rules/
│       └── draft-context.mdc     pm-agent instructions for Cursor (→ ~/.cursor/rules/)
├── .cursor-plugin/
│   └── plugin.json               Cursor marketplace manifest (pending submission)
├── agents/
│   ├── pm-agent.md               Orchestrator agent (Claude Code + Cursor)
│   ├── draft-researcher.md       Researcher sub-agent
│   ├── draft-executor.md         Executor sub-agent
│   └── draft-learner.md          Learner sub-agent
├── skills/
│   ├── draft-setup/SKILL.md      Onboarding interview skill
│   └── draft-learn/SKILL.md      Manual learning capture skill
├── hooks/
│   └── hooks.json                Claude Code SessionStart hooks config
├── scripts/
│   ├── session-init.sh           Claude Code — guarded bootstrap + settings config
│   ├── inject-context.sh         Claude Code + Codex — context injection hook
│   ├── cursor-session-start.sh   Cursor — context injection hook (JSON output)
│   ├── codex-setup.sh            Codex — one-time setup
│   ├── codex-uninstall.sh        Codex — removes everything codex-setup.sh installed
│   ├── cursor-setup.sh           Cursor — one-time setup
│   └── cursor-uninstall.sh       Cursor — removes everything cursor-setup.sh installed
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

All editors share the same workspace at `~/.draft/workspace/`:

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

The workspace lives outside `~/.claude/`, `~/.codex/`, and `~/.cursor/` intentionally — it's editor-agnostic and shared across all three.

---

## Path conventions

| Variable | Resolves to | Set by |
|---|---|---|
| `$DRAFT_WORKSPACE` | `~/.draft/workspace` | `session-init.sh` (Claude Code) / `codex-setup.sh` (Codex) / `cursor-setup.sh` (Cursor) |

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
# Run the setup script from the plugin repo
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

### Cursor

```bash
# Run the setup script from the plugin repo
bash ./scripts/cursor-setup.sh

# Verify hook was registered
cat ~/.cursor/hooks.json | python3 -m json.tool

# Verify the session-start script outputs valid JSON
bash ~/.cursor/hooks/draft/cursor-session-start.sh

# Verify sub-agents were installed (if Claude Code plugin is not present)
ls ~/.cursor/agents/

# Verify rules file was installed (if Claude Code plugin is not present)
ls ~/.cursor/rules/

# Verify the skill was installed
ls ~/.cursor/skills/

# Restart Cursor — context loads automatically in every new Agent tab session
# If fresh install, run /draft-setup in the Agent tab

# To uninstall
bash ./scripts/cursor-uninstall.sh
```
