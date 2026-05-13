#!/bin/bash
# SessionStart hook — injects Draft workspace context into every session.
#
# Runs the same commands as the workspace CLAUDE.md directly,
# so ! bash commands are always executed (not just printed as raw text).
#
# stdout: formatted context injected into Claude's system prompt
# stderr: profile banner, migration notices
#
# Profile resolution order:
#   0. If $DRAFT_WORKSPACE is set externally, use it (banner shows path, not name)
#   1. Read ~/.draft/active-profile → get profile name
#   2. Set DRAFT_WORKSPACE=~/.draft/workspaces/<profile-name>
#
# Personal layer: always at ~/.draft/personal/ (global — shared across all profiles)

DRAFT_GLOBAL="$HOME/.draft"

# ── Migration: workspace/ → workspaces/default/ ────────────────────────────────
# Runs once for existing users upgrading to multi-profile support.
# Idempotent — safe to re-run (checks for workspaces/ before acting).
# Guard: if workspace/ is a symlink (power-user trick), skip migration entirely.
if [ -z "${DRAFT_WORKSPACE:-}" ] && [ -d "$DRAFT_GLOBAL/workspace" ] && [ ! -d "$DRAFT_GLOBAL/workspaces" ]; then
    if [ -L "$DRAFT_GLOBAL/workspace" ]; then
        echo "[Draft] workspace is a symlink — manual migration may be needed. See docs." >&2
    else
        # Step 1: Move workspace → workspaces/default
        mkdir -p "$DRAFT_GLOBAL/workspaces"
        mv "$DRAFT_GLOBAL/workspace" "$DRAFT_GLOBAL/workspaces/default"
        echo "default" > "$DRAFT_GLOBAL/active-profile"

        # Step 2: Elevate personal/ to global layer (~/.draft/personal/)
        _src="$DRAFT_GLOBAL/workspaces/default/personal"
        _dst="$DRAFT_GLOBAL/personal"

        if [ -d "$_src" ]; then
            if [ ! -d "$_dst" ]; then
                mv "$_src" "$_dst"
            else
                # Destination exists — merge: copy files that don't exist at destination
                find "$_src" -type f | while IFS= read -r _f; do
                    _rel="${_f#$_src/}"
                    _dest_f="$_dst/$_rel"
                    if [ ! -f "$_dest_f" ]; then
                        mkdir -p "$(dirname "$_dest_f")"
                        mv "$_f" "$_dest_f"
                        echo "[Draft] Merged: personal/$_rel" >&2
                    else
                        echo "[Draft] Skipped (exists): personal/$_rel" >&2
                    fi
                done
                rm -rf "$_src"
            fi
        fi

        echo "[Draft] Migrated to multi-profile. Active profile: default. Run /draft:profiles to manage profiles." >&2
    fi
fi

# ── Profile resolution ─────────────────────────────────────────────────────────
if [ -n "${DRAFT_WORKSPACE:-}" ]; then
    # Externally set — use it as-is; banner shows path (no profile name available)
    # Platform: Claude Code / Codex — banner to stderr
    echo "[Draft] Active workspace: $DRAFT_WORKSPACE" >&2
else
    _active_profile_file="$DRAFT_GLOBAL/active-profile"
    _active_profile=""

    if [ -f "$_active_profile_file" ]; then
        _active_profile=$(tr -d '[:space:]' < "$_active_profile_file")
    fi

    if [ -z "$_active_profile" ]; then
        # No active-profile set
        if [ -d "$DRAFT_GLOBAL/workspaces" ]; then
            if [ -d "$DRAFT_GLOBAL/workspaces/default" ]; then
                # Fall back to default if it exists
                _active_profile="default"
            else
                echo "[Draft] No active profile set. Run /draft:profiles to create one." >&2
                exit 0
            fi
        else
            # Net-new install — silent default (setup will create the directory)
            _active_profile="default"
        fi
    fi

    DRAFT_WORKSPACE="$DRAFT_GLOBAL/workspaces/$_active_profile"

    if [ ! -d "$DRAFT_WORKSPACE" ] && [ -d "$DRAFT_GLOBAL/workspaces" ]; then
        echo "[Draft] Profile '$_active_profile' not found. Run /draft:profiles to see available profiles." >&2
        exit 0
    fi

    # Platform: Claude Code / Codex — banner to stderr
    echo "[Draft] Active profile: $_active_profile" >&2
fi

export DRAFT_WORKSPACE
DRAFT_PERSONAL="$DRAFT_GLOBAL/personal"

# ── Skip gracefully if workspace not yet initialized ───────────────────────────
if [ ! -d "$DRAFT_WORKSPACE/context" ]; then
    echo "(Draft workspace not initialized — run /draft:setup)"
    exit 0
fi

echo "# Draft — Workspace Context"
echo ""
echo "## Workspace structure"
tree -L 2 --charset ascii "$DRAFT_WORKSPACE/context/" 2>/dev/null || echo "(context/ not found — run /draft:setup)"
echo ""
echo "## Context index"
python3 -c "
import os
from pathlib import Path
ws = os.environ.get('DRAFT_WORKSPACE', os.path.expanduser('~/.draft/workspaces/default'))
ctx = Path(ws) / 'context'
files = sorted(ctx.glob('*/index.md'))
if not files:
    print('No context loaded yet — run /draft:setup to initialize your PM brain.')
else:
    for idx in files:
        try:
            text = idx.read_text()
            parts = text.split('---')
            fm = parts[1].strip() if len(parts) >= 3 else text[:300]
            print(f'**{idx.parent.name}**')
            print(fm)
            print()
        except Exception:
            pass
" 2>/dev/null || echo "Run /draft:setup to initialize your PM brain."
echo ""
echo "## Current priorities"
cat "$DRAFT_WORKSPACE/context/priorities/index.md" 2>/dev/null || echo "No priorities recorded yet."

# ── Memory (personal layer — global, shared across all profiles) ───────────────
if [ -f "$DRAFT_PERSONAL/memory.md" ]; then
    echo ""
    echo "## Memory"
    cat "$DRAFT_PERSONAL/memory.md" 2>/dev/null
fi

# ── Collaboration status (per-profile — reads from active workspace config/) ───
if [ -f "$DRAFT_WORKSPACE/config/collaboration.md" ]; then
    echo ""
    echo "## Collaboration"
    python3 -c "
import os
from pathlib import Path
ws = Path(os.environ.get('DRAFT_WORKSPACE', os.path.expanduser('~/.draft/workspaces/default')))
collab = ws / 'config' / 'collaboration.md'
local = ws / 'config' / 'local.md'

def read_frontmatter(path):
    if not path.exists(): return {}
    text = path.read_text()
    parts = text.split('---')
    if len(parts) >= 3:
        import re
        fm = {}
        for line in parts[1].strip().splitlines():
            m = re.match(r'^(\w+):\s*(.+)$', line.strip())
            if m: fm[m.group(1)] = m.group(2).strip()
        return fm
    return {}

c = read_frontmatter(collab)
l = read_frontmatter(local)

if c.get('mode') == 'github':
    print(f\"mode: {c.get('mode', '—')}\")
    print(f\"repo: {c.get('team_repo_url', '—')} / {c.get('team_repo_subdir', 'root')}\")
    print(f\"teammates: {c.get('teammates', '—')}\")
    print(f\"last_published: {l.get('last_published', 'never')}\")
    print(f\"last_loaded: {l.get('last_loaded', 'never')}\")
" 2>/dev/null
fi

# ── Update notification ────────────────────────────────────────────────────────
# Read cached check result — written by draft-update-check.sh in background.
# If an upgrade is available, inject a notice so pm-agent surfaces it to the user.

LAST_CHECK="$HOME/.draft/last-update-check"
if [ -f "$LAST_CHECK" ]; then
    read -r UPDATE_STATUS OLD_VER NEW_VER EXTRA < "$LAST_CHECK" 2>/dev/null || true
    if [ "${UPDATE_STATUS:-}" = "UPGRADE_AVAILABLE" ]; then
        echo ""
        echo "## Draft Update Available"
        echo "v${NEW_VER} is available (currently on v${OLD_VER}). Mention this to the user and offer to run \`/draft:update\` to upgrade."
    fi
fi

# Fire background update check — never blocks session start.
# Writes fresh result to ~/.draft/last-update-check for the next session.
if [ -f "$HOME/.draft/scripts/draft-update-check.sh" ]; then
    bash "$HOME/.draft/scripts/draft-update-check.sh" >/dev/null 2>&1 &
fi
