#!/bin/bash
# Draft — One-time Cursor setup
#
# End-user install (no local repo needed):
#   curl -fsSL https://raw.githubusercontent.com/idodekerobo/draft-cli-plugin/main/scripts/cursor-setup.sh | bash
#
# Local development (from plugin repo root):
#   bash ./scripts/cursor-setup.sh
#
# What this does:
#   1. Creates ~/.draft/workspace/ with blank context/memory structure (idempotent)
#   2. Installs cursor-session-start.sh to ~/.cursor/hooks/draft/
#   3. Registers the sessionStart hook in ~/.cursor/hooks.json
#   4. [If no Claude Code plugin] Installs draft-context.mdc to ~/.cursor/rules/
#   5. [If no Claude Code plugin] Installs sub-agents to ~/.cursor/agents/
#   6. Installs draft-setup skill to ~/.cursor/skills/ and ~/.agents/skills/
#
# Cursor reads ~/.claude/agents/ and ~/.codex/AGENTS.md natively, so if the
# Claude Code or Codex plugins are already installed we skip anything that would
# create a duplicate PM brain in Cursor's context.
#
# After running: restart Cursor. Your product context is automatically injected
# into every new Composer session — no action needed.

set -euo pipefail

GITHUB_RAW="https://raw.githubusercontent.com/idodekerobo/draft-cli-plugin/main"
CURSOR_HOME="${CURSOR_HOME:-$HOME/.cursor}"
DRAFT_WORKSPACE="${DRAFT_WORKSPACE:-$HOME/.draft/workspace}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

log()   { echo -e "${GREEN}[Draft]${NC} $1"; }
warn()  { echo -e "${YELLOW}[Draft]${NC} $1"; }
err()   { echo -e "${RED}[Draft]${NC} $1" >&2; }
info()  { echo -e "${CYAN}[Draft]${NC} $1"; }

# ── Detect local vs remote source ─────────────────────────────────────────────
# BASH_SOURCE[0] is unset when piped via curl | bash.
SCRIPT_DIR=""
PLUGIN_ROOT=""
USE_LOCAL=false

if [ -n "${BASH_SOURCE[0]:-}" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
    if [ -f "$PLUGIN_ROOT/scripts/cursor-session-start.sh" ]; then
        USE_LOCAL=true
    fi
fi

install_file() {
    local src_rel="$1"   # relative path within the plugin repo
    local dest="$2"       # absolute destination path

    if [ "$USE_LOCAL" = true ]; then
        cp "$PLUGIN_ROOT/$src_rel" "$dest"
    else
        curl -fsSL "$GITHUB_RAW/$src_rel" -o "$dest"
    fi
}

# ── Detect existing Draft installations ────────────────────────────────────────
# Cursor reads ~/.claude/agents/ and ~/.codex/AGENTS.md natively. If either
# plugin is installed, the PM brain instructions and subagents are already
# flowing into Cursor — installing them again creates duplicate context blocks.

CLAUDE_CODE_INSTALLED=false
CODEX_INSTALLED=false

if [ -f "$HOME/.claude/agents/pm-agent.md" ]; then
    CLAUDE_CODE_INSTALLED=true
fi

if [ -f "$HOME/.codex/AGENTS.md" ]; then
    CODEX_INSTALLED=true
fi

# Require python3
if ! command -v python3 &>/dev/null; then
    err "python3 is required but not found. Install it and re-run."
    exit 1
fi

echo ""
if [ "$USE_LOCAL" = true ]; then
    log "Setting up Draft for Cursor (local source: $PLUGIN_ROOT)..."
else
    log "Setting up Draft for Cursor (source: GitHub main)..."
fi

if [ "$CLAUDE_CODE_INSTALLED" = true ]; then
    info "Claude Code plugin detected — skipping rules + subagent install (already provided)."
elif [ "$CODEX_INSTALLED" = true ]; then
    info "Codex plugin detected — skipping rules install (AGENTS.md already provided)."
fi
echo ""

# ── 1. Bootstrap workspace ─────────────────────────────────────────────────────

if [ ! -d "$DRAFT_WORKSPACE" ]; then
    log "Creating workspace at $DRAFT_WORKSPACE..."

    mkdir -p \
        "$DRAFT_WORKSPACE/context/company/log" \
        "$DRAFT_WORKSPACE/context/product/log" \
        "$DRAFT_WORKSPACE/context/user" \
        "$DRAFT_WORKSPACE/context/team/log" \
        "$DRAFT_WORKSPACE/context/priorities/log" \
        "$DRAFT_WORKSPACE/context/decisions" \
        "$DRAFT_WORKSPACE/memory" \
        "$DRAFT_WORKSPACE/docs/prds" \
        "$DRAFT_WORKSPACE/docs/decisions" \
        "$DRAFT_WORKSPACE/templates"

    for dim in company product user team priorities; do
        cat > "$DRAFT_WORKSPACE/context/$dim/index.md" <<EOF
---
name: $dim
description: >
  No information recorded yet.
last_updated: ""
source: ""
---
EOF
    done

    cat > "$DRAFT_WORKSPACE/context/tensions.md" <<'EOF'
# Tensions

Active contradictions and inconsistencies noticed across context dimensions.
EOF

    cat > "$DRAFT_WORKSPACE/memory/memory.md" <<'EOF'
---
name: memory
description: Vocabulary, working preferences, and non-obvious patterns.
last_updated: ""
source: ""
---

## Vocabulary

## Preferences

## Goals

## Patterns
EOF

    log "Workspace created at $DRAFT_WORKSPACE"
else
    warn "Workspace already exists at $DRAFT_WORKSPACE — skipping creation."
fi

# ── 2. Install cursor-session-start.sh ─────────────────────────────────────────
# Always installed regardless of other plugins — Cursor needs its own
# sessionStart hook for workspace context injection.

log "Installing cursor-session-start hook script..."
mkdir -p "$CURSOR_HOME/hooks/draft"
install_file "scripts/cursor-session-start.sh" "$CURSOR_HOME/hooks/draft/cursor-session-start.sh"
chmod +x "$CURSOR_HOME/hooks/draft/cursor-session-start.sh"
log "Hook script installed to $CURSOR_HOME/hooks/draft/cursor-session-start.sh"

# ── 3. Register sessionStart hook in ~/.cursor/hooks.json ─────────────────────

log "Registering sessionStart hook..."

python3 - <<PYEOF
import json, sys
from pathlib import Path

hooks_path = Path("$CURSOR_HOME/hooks.json")
hook_command = "bash $CURSOR_HOME/hooks/draft/cursor-session-start.sh"

if hooks_path.exists():
    try:
        data = json.loads(hooks_path.read_text())
    except Exception:
        data = {}
else:
    data = {}

data.setdefault("version", 1)
hooks = data.setdefault("hooks", {})
session_hooks = hooks.setdefault("sessionStart", [])

already = any(
    h.get("command") == hook_command
    for h in session_hooks
    if isinstance(h, dict)
)

if already:
    print("[Draft] sessionStart hook already registered — skipping.")
    sys.exit(0)

session_hooks.append({
    "command": hook_command,
    "timeout": 10,
    "statusMessage": "Loading Draft workspace context"
})

hooks_path.parent.mkdir(parents=True, exist_ok=True)
hooks_path.write_text(json.dumps(data, indent=2) + "\n")
print("[Draft] sessionStart hook registered in ~/.cursor/hooks.json")
PYEOF

# ── 4. Install draft-context.mdc — skip if Claude Code or Codex is installed ──
# Claude Code: pm-agent.md in ~/.claude/agents/ already gives Cursor the PM brain.
# Codex: ~/.codex/AGENTS.md already gives Cursor the PM brain.

if [ "$CLAUDE_CODE_INSTALLED" = true ] || [ "$CODEX_INSTALLED" = true ]; then
    warn "Skipping draft-context.mdc — PM brain instructions already loaded from existing plugin."
else
    log "Installing draft-context.mdc rules file..."
    mkdir -p "$CURSOR_HOME/rules"
    install_file ".cursor/rules/draft-context.mdc" "$CURSOR_HOME/rules/draft-context.mdc"
    log "Rules file installed to $CURSOR_HOME/rules/draft-context.mdc"
fi

# ── 5. Install sub-agents — skip if Claude Code is installed ───────────────────
# Cursor reads ~/.claude/agents/ natively. If Claude Code is installed, the
# draft-researcher/executor/learner agents are already there.

if [ "$CLAUDE_CODE_INSTALLED" = true ]; then
    warn "Skipping sub-agent install — agents already available from Claude Code plugin."
else
    log "Installing sub-agent definitions..."
    mkdir -p "$CURSOR_HOME/agents"

    for agent in draft-researcher draft-executor draft-learner; do
        install_file "agents/$agent.md" "$CURSOR_HOME/agents/$agent.md"
        log "  Installed $agent.md"
    done
fi

# ── 6. Install draft-setup skill ───────────────────────────────────────────────

log "Installing draft-setup skill..."

mkdir -p "$CURSOR_HOME/skills/draft-setup"
install_file "skills/draft-setup/SKILL.md" "$CURSOR_HOME/skills/draft-setup/SKILL.md"
log "  Skill installed to $CURSOR_HOME/skills/draft-setup/SKILL.md"

USER_AGENTS_SKILLS="$HOME/.agents/skills"
mkdir -p "$USER_AGENTS_SKILLS/draft-setup"
install_file "skills/draft-setup/SKILL.md" "$USER_AGENTS_SKILLS/draft-setup/SKILL.md"
log "  Skill installed to $USER_AGENTS_SKILLS/draft-setup/SKILL.md"

# ── Done ──────────────────────────────────────────────────────────────────────

echo ""
log "Setup complete."
echo ""
echo "  Next steps:"
echo "  1. Restart Cursor"
if [ "$CLAUDE_CODE_INSTALLED" = false ] && [ "$CODEX_INSTALLED" = false ]; then
    echo "  2. Run /draft-setup to initialize your PM brain"
else
    echo "  2. Your existing PM brain context will load automatically"
fi
echo ""
echo "  How it works:"
echo "  Your product context is injected silently at the start of every"
echo "  new Cursor Composer session. No action needed — just open Composer"
echo "  and Draft already knows your product, priorities, and team."
echo ""
