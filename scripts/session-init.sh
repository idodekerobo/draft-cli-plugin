#!/bin/bash
# SessionStart hook — runs on every session start.
#
# First run only:
#   - Bootstraps ~/.draft/workspace/ from template
#   - Writes DRAFT_WORKSPACE + additionalDirectories + permissions to settings.json
#
# Context injection is handled separately by inject-context.sh.
#
# stdout: empty (inject-context.sh handles context injection)
# stderr: status messages (not shown to Claude)

set -euo pipefail

WORKSPACE="$HOME/.draft/workspace"
TEMPLATE="${CLAUDE_PLUGIN_ROOT}/workspace-template"
SETTINGS="$HOME/.claude/settings.json"

# ── 1. Bootstrap workspace ────────────────────────────────────────────────────

if [ ! -d "$WORKSPACE" ]; then
    echo "[Draft] Initializing workspace at $WORKSPACE..." >&2
    mkdir -p "$WORKSPACE"
    cp -r "$TEMPLATE/." "$WORKSPACE/"
    echo "[Draft] Workspace ready. Run /draft:setup to load your PM brain." >&2
fi

# ── 1b. Record installed version ──────────────────────────────────────────────
# CLAUDE_PLUGIN_ROOT is set by Claude Code when running hooks (already used above for TEMPLATE).
# Runs every session so the recorded version always matches the installed plugin.

PLUGIN_VERSION=$(cat "${CLAUDE_PLUGIN_ROOT}/VERSION" 2>/dev/null || echo "unknown")
mkdir -p "$HOME/.draft"
echo "$PLUGIN_VERSION" > "$HOME/.draft/version"

# ── 1c. Install shared scripts ─────────────────────────────────────────────────
# Copies update scripts to ~/.draft/scripts/ so they're accessible from all platforms.
# Runs every session so Codex/Cursor users always get the latest version after a Claude Code update.
# Guarded: skips gracefully if scripts aren't present in this plugin version yet.

if [ -f "${CLAUDE_PLUGIN_ROOT}/scripts/draft-update-check.sh" ]; then
    mkdir -p "$HOME/.draft/scripts"
    cp "${CLAUDE_PLUGIN_ROOT}/scripts/draft-update-check.sh" "$HOME/.draft/scripts/draft-update-check.sh"
    cp "${CLAUDE_PLUGIN_ROOT}/scripts/draft-update.sh" "$HOME/.draft/scripts/draft-update.sh"
    chmod +x "$HOME/.draft/scripts/draft-update-check.sh" "$HOME/.draft/scripts/draft-update.sh"
fi

# ── 2. Configure ~/.claude/settings.json (one-time) ──────────────────────────
# Adds DRAFT_WORKSPACE env var, additionalDirectories (file access), and
# ~/.draft/** read/write/edit permissions.

python3 - <<PYEOF
import json, sys
from pathlib import Path

settings_path = Path("$SETTINGS")
workspace = "$WORKSPACE"

if settings_path.exists():
    try:
        settings = json.loads(settings_path.read_text())
    except Exception:
        settings = {}
else:
    settings = {}

changed = False

# Set DRAFT_WORKSPACE env var
env = settings.setdefault("env", {})
if env.get("DRAFT_WORKSPACE") != workspace:
    env["DRAFT_WORKSPACE"] = workspace
    changed = True

# Set additionalDirectories (file access)
perms = settings.setdefault("permissions", {})
dirs = perms.setdefault("additionalDirectories", [])
if workspace not in dirs:
    dirs.append(workspace)
    changed = True

# Grant ~/.draft/** permissions so Claude can read/write workspace files
draft_dir = str(Path(workspace).parent)
draft_glob = draft_dir + "/**"
allow = perms.setdefault("allow", [])
for perm in [f"Write({draft_glob})", f"Read({draft_glob})", f"Edit({draft_glob})"]:
    if perm not in allow:
        allow.append(perm)
        changed = True

if changed:
    settings_path.parent.mkdir(parents=True, exist_ok=True)
    settings_path.write_text(json.dumps(settings, indent=2) + "\n")
    print("[Draft] Settings updated.", file=sys.stderr)
PYEOF
