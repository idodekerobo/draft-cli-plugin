#!/bin/bash
# SessionStart hook — injects Draft workspace context into every session.
#
# Runs the same commands as ~/.draft/workspace/CLAUDE.md directly,
# so ! bash commands are always executed (not just printed as raw text).
#
# stdout: formatted context injected into Claude's system prompt
# stderr: silent

DRAFT_WORKSPACE="${DRAFT_WORKSPACE:-$HOME/.draft/workspace}"

# Skip gracefully if workspace not yet initialized
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
ws = os.environ.get('DRAFT_WORKSPACE', os.path.expanduser('~/.draft/workspace'))
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
# ── Memory (personal layer) ────────────────────────────────────────────────────
if [ -f "$DRAFT_WORKSPACE/personal/memory.md" ]; then
    echo ""
    echo "## Memory"
    cat "$DRAFT_WORKSPACE/personal/memory.md" 2>/dev/null
fi

# ── Collaboration status ───────────────────────────────────────────────────────
if [ -f "$DRAFT_WORKSPACE/config/collaboration.md" ]; then
    echo ""
    echo "## Collaboration"
    python3 -c "
import os
from pathlib import Path
ws = Path(os.environ.get('DRAFT_WORKSPACE', os.path.expanduser('~/.draft/workspace')))
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
