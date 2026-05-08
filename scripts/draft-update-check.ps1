# Draft — Update check (Windows PowerShell)
#
# Checks if a Draft update is available. Writes result to ~/.draft/last-update-check.
# Called in background from session hooks — never blocks session start.
#
# Output (written to file, not stdout):
#   UP_TO_DATE <version>
#   UPGRADE_AVAILABLE <installed> <latest>
#
# Flags:
#   -Force   Bypass TTL cache and check immediately
#
# Called with: powershell -ExecutionPolicy Bypass -File "draft-update-check.ps1"

param(
    [switch]$Force
)

$draftDir          = Join-Path $HOME ".draft"
$lastCheckFile     = Join-Path $draftDir "last-update-check"
$versionFile       = Join-Path $draftDir "version"
$remoteVersionUrl  = "https://raw.githubusercontent.com/idodekerobo/draft-cli-plugin/main/VERSION"

# ── No installed version recorded — nothing to check ─────────────────────────

$installed = ""
if (Test-Path $versionFile) {
    $installed = (Get-Content $versionFile -Raw -ErrorAction SilentlyContinue).Trim()
}
if (-not $installed) {
    exit 0
}

# ── TTL check — avoid hitting remote on every session ─────────────────────────
# UP_TO_DATE:        60 min TTL  (3600 seconds)
# UPGRADE_AVAILABLE: 720 min TTL (43200 seconds)

if (-not $Force -and (Test-Path $lastCheckFile)) {
    try {
        $lastStatus = ((Get-Content $lastCheckFile -TotalCount 1 -ErrorAction SilentlyContinue) -split '\s+')[0]
        $lastWrite  = (Get-Item $lastCheckFile).LastWriteTime
        $elapsedMin = ([datetime]::Now - $lastWrite).TotalMinutes

        if ($lastStatus -eq "UP_TO_DATE"        -and $elapsedMin -lt 60)  { exit 0 }
        if ($lastStatus -eq "UPGRADE_AVAILABLE"  -and $elapsedMin -lt 720) { exit 0 }
    } catch {
        # Ignore TTL errors — proceed with check
    }
}

# ── Fetch remote version (5s timeout, fail silently) ──────────────────────────

$remote = ""
try {
    $response = Invoke-WebRequest -Uri $remoteVersionUrl -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
    $remote   = $response.Content.Trim()
} catch {
    exit 0  # Network error — keep old cache, don't overwrite
}

if (-not $remote) {
    exit 0
}

# ── Write result ──────────────────────────────────────────────────────────────

New-Item -ItemType Directory -Path $draftDir -Force | Out-Null

if ($installed -eq $remote) {
    Set-Content -Path $lastCheckFile -Value "UP_TO_DATE $installed" -NoNewline
} else {
    Set-Content -Path $lastCheckFile -Value "UPGRADE_AVAILABLE $installed $remote" -NoNewline
}
