# Draft — Inject context (Windows PowerShell)
# SessionStart hook — injects Draft workspace context into every session.
#
# Runs the same commands as ~/.draft/workspace/CLAUDE.md directly,
# so ! bash commands are always executed (not just printed as raw text).
#
# stdout: formatted context injected into Claude's system prompt
# stderr: silent
#
# Called with: powershell -ExecutionPolicy Bypass -File "inject-context.ps1"

# ── Workspace path ─────────────────────────────────────────────────────────────

$draftWorkspace = if ($env:DRAFT_WORKSPACE) {
    $env:DRAFT_WORKSPACE
} else {
    Join-Path $HOME ".draft" "workspace"
}

# ── Guard: workspace not yet initialized ──────────────────────────────────────

if (-not (Test-Path (Join-Path $draftWorkspace "context"))) {
    Write-Output "(Draft workspace not initialized — run /draft:setup)"
    exit 0
}

# ── Helper: tree-like listing (replaces `tree -L 2 --charset ascii`) ──────────

function Show-DraftTree {
    param(
        [string]$RootPath,
        [int]$MaxDepth = 2,
        [int]$CurrentDepth = 0,
        [string]$Prefix = ""
    )

    if ($CurrentDepth -ge $MaxDepth) { return }

    try {
        $items = Get-ChildItem -Path $RootPath -ErrorAction SilentlyContinue |
                 Sort-Object { $_.PSIsContainer -eq $false }, Name
    } catch {
        return
    }

    $count = $items.Count
    for ($i = 0; $i -lt $count; $i++) {
        $item   = $items[$i]
        $isLast = ($i -eq $count - 1)
        $connector = "|-- "
        $childPfx  = "|   "

        Write-Output ($Prefix + $connector + $item.Name)

        if ($item.PSIsContainer -and ($CurrentDepth + 1) -lt $MaxDepth) {
            Show-DraftTree -RootPath $item.FullName `
                           -MaxDepth $MaxDepth `
                           -CurrentDepth ($CurrentDepth + 1) `
                           -Prefix ($Prefix + $childPfx)
        }
    }
}

# ── Header ─────────────────────────────────────────────────────────────────────

Write-Output "# Draft — Workspace Context"
Write-Output ""
Write-Output "## Workspace structure"

$contextPath = Join-Path $draftWorkspace "context"
if (Test-Path $contextPath) {
    # Print root directory name then recurse
    $contextRelative = "context/"
    Write-Output $contextRelative
    Show-DraftTree -RootPath $contextPath -MaxDepth 2
} else {
    Write-Output "(context/ not found — run /draft:setup)"
}

Write-Output ""
Write-Output "## Context index"

# ── Parse YAML frontmatter via python3 (same logic as bash version) ──────────

$python = $null
if (Get-Command python3 -ErrorAction SilentlyContinue) {
    $python = "python3"
} elseif (Get-Command python -ErrorAction SilentlyContinue) {
    $python = "python"
}

if ($python) {
    $pyScript = @"
import os
from pathlib import Path
ws = os.environ.get('DRAFT_WORKSPACE', os.path.join(os.path.expanduser('~'), '.draft', 'workspace'))
ctx = Path(ws) / 'context'
files = sorted(ctx.glob('*/index.md'))
if not files:
    print('No context loaded yet -- run /draft:setup to initialize your PM brain.')
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
"@

    try {
        $result = & $python -c $pyScript 2>$null
        if ($result) {
            Write-Output $result
        } else {
            Write-Output "Run /draft:setup to initialize your PM brain."
        }
    } catch {
        Write-Output "Run /draft:setup to initialize your PM brain."
    }
} else {
    Write-Output "Run /draft:setup to initialize your PM brain."
}

Write-Output ""
Write-Output "## Current priorities"

$prioritiesFile = Join-Path $draftWorkspace "context" "priorities" "index.md"
if (Test-Path $prioritiesFile) {
    Write-Output (Get-Content $prioritiesFile -Raw).TrimEnd()
} else {
    Write-Output "No priorities recorded yet."
}

Write-Output ""
Write-Output "## Memory"

$memoryFile = Join-Path $draftWorkspace "memory" "memory.md"
if (Test-Path $memoryFile) {
    Write-Output (Get-Content $memoryFile -Raw).TrimEnd()
} else {
    Write-Output "No memory yet."
}

# ── Update notification ────────────────────────────────────────────────────────
# Read cached check result — written by draft-update-check.ps1 in background.
# If an upgrade is available, inject a notice so pm-agent surfaces it to the user.

$lastCheckFile = Join-Path $HOME ".draft" "last-update-check"
if (Test-Path $lastCheckFile) {
    try {
        $checkLine = (Get-Content $lastCheckFile -TotalCount 1 -ErrorAction SilentlyContinue) -split '\s+'
        $updateStatus = $checkLine[0]
        $oldVer       = if ($checkLine.Count -gt 1) { $checkLine[1] } else { "" }
        $newVer       = if ($checkLine.Count -gt 2) { $checkLine[2] } else { "" }

        if ($updateStatus -eq "UPGRADE_AVAILABLE") {
            Write-Output ""
            Write-Output "## Draft Update Available"
            Write-Output "v${newVer} is available (currently on v${oldVer}). Mention this to the user and offer to run ``/draft:update`` to upgrade."
        }
    } catch {
        # Ignore — update notification is non-critical
    }
}

# ── Background update check — never blocks session start ──────────────────────
# Writes fresh result to ~/.draft/last-update-check for the next session.

$updateCheckScript = Join-Path $HOME ".draft" "scripts" "draft-update-check.ps1"
if (Test-Path $updateCheckScript) {
    Start-Job -ScriptBlock {
        param($scriptPath)
        try {
            & powershell -ExecutionPolicy Bypass -File $scriptPath 2>$null
        } catch {}
    } -ArgumentList $updateCheckScript | Out-Null
}
