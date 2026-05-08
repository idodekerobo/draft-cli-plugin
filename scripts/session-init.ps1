# Draft — Session init (Windows PowerShell)
# SessionStart hook — runs on every session start.
#
# First run only:
#   - Bootstraps ~/.draft/workspace/ from template
#   - Writes DRAFT_WORKSPACE + additionalDirectories + permissions to settings.json
#
# Context injection is handled separately by inject-context.ps1.
#
# stdout: empty (inject-context.ps1 handles context injection)
# stderr: status messages (not shown to Claude)
#
# Called with: powershell -ExecutionPolicy Bypass -File "session-init.ps1"

$ErrorActionPreference = 'Stop'

$workspace   = Join-Path $HOME ".draft" "workspace"
$template    = Join-Path $env:CLAUDE_PLUGIN_ROOT "workspace-template"
$settingsPath = Join-Path $HOME ".claude" "settings.json"
$draftDir    = Join-Path $HOME ".draft"

# ── 1. Bootstrap workspace ────────────────────────────────────────────────────

if (-not (Test-Path $workspace)) {
    Write-Host "[Draft] Initializing workspace at $workspace..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $workspace -Force | Out-Null
    Copy-Item -Path (Join-Path $template "*") -Destination $workspace -Recurse -Force
    Write-Host "[Draft] Workspace ready. Run /draft:setup to load your PM brain." -ForegroundColor Yellow
}

# ── 1b. Record installed version ──────────────────────────────────────────────

$versionFile = Join-Path $env:CLAUDE_PLUGIN_ROOT "VERSION"
$pluginVersion = "unknown"
if (Test-Path $versionFile) {
    $pluginVersion = (Get-Content $versionFile -Raw).Trim()
}
New-Item -ItemType Directory -Path $draftDir -Force | Out-Null
Set-Content -Path (Join-Path $draftDir "version") -Value $pluginVersion -NoNewline

# ── 1c. Install shared scripts ─────────────────────────────────────────────────

$pluginScripts = Join-Path $env:CLAUDE_PLUGIN_ROOT "scripts"
$draftScripts  = Join-Path $draftDir "scripts"

if (Test-Path (Join-Path $pluginScripts "draft-update-check.ps1")) {
    New-Item -ItemType Directory -Path $draftScripts -Force | Out-Null
    Copy-Item (Join-Path $pluginScripts "draft-update-check.ps1") $draftScripts -Force
    Copy-Item (Join-Path $pluginScripts "draft-update.ps1")       $draftScripts -Force
    # Also copy bash versions if present (for users who switch platforms)
    if (Test-Path (Join-Path $pluginScripts "draft-update-check.sh")) {
        Copy-Item (Join-Path $pluginScripts "draft-update-check.sh") $draftScripts -Force
        Copy-Item (Join-Path $pluginScripts "draft-update.sh")       $draftScripts -Force
    }
}

# ── 2. Configure ~/.claude/settings.json ─────────────────────────────────────
# Adds DRAFT_WORKSPACE env var, additionalDirectories (file access), and
# ~/.draft/** read/write/edit permissions.
#
# Path note: the workspace path written to settings.json uses forward slashes
# to match the format the bash version writes, so the same settings.json works
# on both platforms.

try {
    # Normalise workspace path to forward slashes for settings.json (matches bash output)
    $workspaceForward = $workspace.Replace('\', '/')

    # Draft dir glob — parent of workspace, forward slashes
    $draftDirForward = (Split-Path $workspace -Parent).Replace('\', '/')
    $draftGlob       = $draftDirForward + "/**"

    $permStrings = @(
        "Write($draftGlob)",
        "Read($draftGlob)",
        "Edit($draftGlob)"
    )

    # Load or create settings
    if (Test-Path $settingsPath) {
        try {
            $configText = Get-Content $settingsPath -Raw
            $config = $configText | ConvertFrom-Json
        } catch {
            $config = [PSCustomObject]@{}
        }
    } else {
        $config = [PSCustomObject]@{}
    }

    $changed = $false

    # ── env.DRAFT_WORKSPACE ───────────────────────────────────────────────────
    if (-not (Get-Member -InputObject $config -Name 'env' -MemberType NoteProperty)) {
        $config | Add-Member -NotePropertyName 'env' -NotePropertyValue ([PSCustomObject]@{})
    }
    $currentDW = $null
    if (Get-Member -InputObject $config.env -Name 'DRAFT_WORKSPACE' -MemberType NoteProperty) {
        $currentDW = $config.env.DRAFT_WORKSPACE
    }
    if ($currentDW -ne $workspaceForward) {
        if (Get-Member -InputObject $config.env -Name 'DRAFT_WORKSPACE' -MemberType NoteProperty) {
            $config.env.DRAFT_WORKSPACE = $workspaceForward
        } else {
            $config.env | Add-Member -NotePropertyName 'DRAFT_WORKSPACE' -NotePropertyValue $workspaceForward
        }
        $changed = $true
    }

    # ── permissions object ────────────────────────────────────────────────────
    if (-not (Get-Member -InputObject $config -Name 'permissions' -MemberType NoteProperty)) {
        $config | Add-Member -NotePropertyName 'permissions' -NotePropertyValue ([PSCustomObject]@{})
    }

    # ── permissions.additionalDirectories ────────────────────────────────────
    if (-not (Get-Member -InputObject $config.permissions -Name 'additionalDirectories' -MemberType NoteProperty)) {
        $config.permissions | Add-Member -NotePropertyName 'additionalDirectories' -NotePropertyValue @()
    }
    # ConvertFrom-Json may give a single string instead of array for single-element arrays
    $dirs = @($config.permissions.additionalDirectories)
    if ($workspaceForward -notin $dirs) {
        $dirs += $workspaceForward
        $config.permissions.additionalDirectories = $dirs
        $changed = $true
    }

    # ── permissions.allow ────────────────────────────────────────────────────
    if (-not (Get-Member -InputObject $config.permissions -Name 'allow' -MemberType NoteProperty)) {
        $config.permissions | Add-Member -NotePropertyName 'allow' -NotePropertyValue @()
    }
    $allow = @($config.permissions.allow)
    foreach ($perm in $permStrings) {
        if ($perm -notin $allow) {
            $allow += $perm
            $changed = $true
        }
    }
    $config.permissions.allow = $allow

    # ── Write if changed ──────────────────────────────────────────────────────
    if ($changed) {
        $claudeDir = Split-Path $settingsPath -Parent
        New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
        # Depth 10 prevents truncation of nested objects; trailing newline matches bash version
        $json = $config | ConvertTo-Json -Depth 10
        Set-Content -Path $settingsPath -Value ($json + "`n") -Encoding UTF8
        Write-Host "[Draft] Settings updated." -ForegroundColor Yellow
    }
} catch {
    Write-Host "[Draft] Warning: could not update settings.json — $_" -ForegroundColor Yellow
}
