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
echo ""
echo "## Memory"
cat "$DRAFT_WORKSPACE/memory/memory.md" 2>/dev/null || echo "No memory yet."
