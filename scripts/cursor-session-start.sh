#!/bin/bash
# Draft — Cursor sessionStart hook
#
# Injects Draft workspace context into every Cursor session as additional_context.
# Cursor treats this as initial system context for the conversation.
#
# Output protocol:
#   stdout: JSON { "additional_context": "<workspace context>" }
#   stderr: silent (Cursor does not surface hook stderr to the user)
#   exit 0: always (sessionStart is fire-and-forget)
#
# Installed by cursor-setup.sh to ~/.cursor/hooks/draft/cursor-session-start.sh

DRAFT_WORKSPACE="${DRAFT_WORKSPACE:-$HOME/.draft/workspace}"
export DRAFT_WORKSPACE

# ── Guard: workspace not initialized ──────────────────────────────────────────
if [ ! -d "$DRAFT_WORKSPACE/context" ]; then
    python3 -c "
import json
print(json.dumps({
    'additional_context': 'Draft workspace not initialized. Run /draft-setup to load your PM brain.'
}))
"
    exit 0
fi

# ── Build and emit context as JSON ────────────────────────────────────────────
#
# Python handles JSON encoding to avoid shell quoting hazards.
# Context files contain arbitrary markdown (quotes, newlines, special chars).

python3 - <<'PYEOF'
import os, json, subprocess
from pathlib import Path

ws = os.environ.get("DRAFT_WORKSPACE", os.path.expanduser("~/.draft/workspace"))
ctx_dir = Path(ws) / "context"
mem_file = Path(ws) / "memory" / "memory.md"

parts = ["# Draft — Workspace Context", ""]

# ── Workspace directory tree (2 levels) ───────────────────────────────────────
parts.append("## Workspace structure")
try:
    result = subprocess.run(
        ["tree", "-L", "2", "--charset", "ascii", str(ctx_dir)],
        capture_output=True, text=True, timeout=5
    )
    parts.append(result.stdout.strip() if result.returncode == 0 else "(tree not available)")
except Exception:
    # tree not installed; fall back to a simple listing
    try:
        dirs = sorted([p.name for p in ctx_dir.iterdir() if p.is_dir()])
        parts.append("context/")
        for d in dirs:
            parts.append(f"  {d}/")
    except Exception:
        parts.append("(context/ not found — run /draft-setup)")
parts.append("")

# ── Context index: frontmatter description from each dimension ─────────────────
parts.append("## Context index")
index_files = sorted(ctx_dir.glob("*/index.md"))
if index_files:
    for idx in index_files:
        try:
            text = idx.read_text()
            sections = text.split("---")
            # YAML frontmatter lives between the first and second ---
            fm = sections[1].strip() if len(sections) >= 3 else text[:300]
            parts.append(f"**{idx.parent.name}**")
            parts.append(fm)
            parts.append("")
        except Exception:
            pass
else:
    parts.append("No context loaded yet — run /draft-setup to initialize your PM brain.")
    parts.append("")

# ── Current priorities (full content) ─────────────────────────────────────────
parts.append("## Current priorities")
priorities = ctx_dir / "priorities" / "index.md"
if priorities.exists():
    parts.append(priorities.read_text().strip())
else:
    parts.append("No priorities recorded yet.")
parts.append("")

# ── Memory (full content) ──────────────────────────────────────────────────────
parts.append("## Memory")
if mem_file.exists():
    parts.append(mem_file.read_text().strip())
else:
    parts.append("No memory yet.")

# ── Update notification ────────────────────────────────────────────────────────
import pathlib as _pl
_last_check = _pl.Path.home() / ".draft" / "last-update-check"
if _last_check.exists():
    try:
        _check = _last_check.read_text().strip().split()
        if len(_check) >= 3 and _check[0] == "UPGRADE_AVAILABLE":
            _old_ver, _new_ver = _check[1], _check[2]
            parts.append("")
            parts.append("## Draft Update Available")
            parts.append(f"v{_new_ver} is available (currently on v{_old_ver}). Mention this to the user and offer to run `/draft-update` to upgrade.")
    except Exception:
        pass

print(json.dumps({"additional_context": "\n".join(parts)}))
PYEOF

# Fire background update check — never blocks session start.
# Writes fresh result to ~/.draft/last-update-check for the next session.
if [ -f "$HOME/.draft/scripts/draft-update-check.sh" ]; then
    bash "$HOME/.draft/scripts/draft-update-check.sh" >/dev/null 2>&1 &
fi
