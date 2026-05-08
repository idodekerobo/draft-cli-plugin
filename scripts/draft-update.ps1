# Draft — Self-update (Windows PowerShell)
#
# Downloads the latest version from GitHub Releases and updates all installed files.
# Called by the /draft:update skill after user confirmation.
#
# Safe: never touches ~/.draft/workspace/ (user's PM brain data)
#
# Called with: powershell -ExecutionPolicy Bypass -File "draft-update.ps1"

$ErrorActionPreference = 'Stop'

$draftDir      = Join-Path $HOME ".draft"
$versionFile   = Join-Path $draftDir "version"
$lastCheckFile = Join-Path $draftDir "last-update-check"
$githubApi     = "https://api.github.com/repos/idodekerobo/draft-cli-plugin/releases/latest"

function Log  { param($msg) Write-Host "[Draft] $msg" -ForegroundColor Green }
function Warn { param($msg) Write-Host "[Draft] $msg" -ForegroundColor Yellow }
function Err  { param($msg) Write-Host "[Draft] $msg" -ForegroundColor Red }

$installed = "unknown"
if (Test-Path $versionFile) {
    $installed = (Get-Content $versionFile -Raw -ErrorAction SilentlyContinue).Trim()
}

Log "Fetching latest release info..."

# ── Get latest tag from GitHub Releases API ───────────────────────────────────

$latestTag = ""
try {
    $apiResponse = Invoke-WebRequest -Uri $githubApi -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
    $releaseData = $apiResponse.Content | ConvertFrom-Json
    $latestTag   = $releaseData.tag_name
} catch {
    Err "Could not fetch latest version from GitHub. Check your connection and try again."
    exit 1
}

if (-not $latestTag) {
    Err "Could not fetch latest version from GitHub. Check your connection and try again."
    exit 1
}

# Strip leading 'v' if present
$latest = $latestTag -replace '^v', ''

# ── Already current? ──────────────────────────────────────────────────────────

if ($installed -eq $latest) {
    Log "Already on the latest version (v$installed). Nothing to do."
    exit 0
}

Write-Host ""
Log "Updating Draft: v$installed -> v$latest"
Write-Host ""

$githubRaw = "https://raw.githubusercontent.com/idodekerobo/draft-cli-plugin/$latestTag"

# ── Always: update shared scripts ─────────────────────────────────────────────

Log "Updating shared scripts..."
$draftScripts = Join-Path $draftDir "scripts"
New-Item -ItemType Directory -Path $draftScripts -Force | Out-Null

# Bash scripts
Invoke-WebRequest -Uri "$githubRaw/scripts/draft-update-check.sh" -OutFile (Join-Path $draftScripts "draft-update-check.sh") -UseBasicParsing -ErrorAction Stop
Invoke-WebRequest -Uri "$githubRaw/scripts/draft-update.sh"       -OutFile (Join-Path $draftScripts "draft-update.sh")       -UseBasicParsing -ErrorAction Stop

# PowerShell scripts
Invoke-WebRequest -Uri "$githubRaw/scripts/draft-update-check.ps1" -OutFile (Join-Path $draftScripts "draft-update-check.ps1") -UseBasicParsing -ErrorAction Stop
Invoke-WebRequest -Uri "$githubRaw/scripts/draft-update.ps1"       -OutFile (Join-Path $draftScripts "draft-update.ps1")       -UseBasicParsing -ErrorAction Stop

Log "  Shared scripts updated at ~/.draft/scripts/"

# ── Codex: update if installed ────────────────────────────────────────────────

$codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME ".codex" }
$codexDetect = Join-Path $codexHome "agents" "draft-researcher.toml"

if (Test-Path $codexDetect) {
    Log "Codex install detected — updating..."

    $codexHookDir = Join-Path $codexHome "hooks" "draft"
    New-Item -ItemType Directory -Path $codexHookDir -Force | Out-Null
    Invoke-WebRequest -Uri "$githubRaw/scripts/inject-context.sh" -OutFile (Join-Path $codexHookDir "inject-context.sh") -UseBasicParsing -ErrorAction SilentlyContinue

    foreach ($agent in @("draft-researcher", "draft-executor", "draft-learner")) {
        $dest = Join-Path $codexHome "agents" "$agent.toml"
        Invoke-WebRequest -Uri "$githubRaw/.codex/agents/$agent.toml" -OutFile $dest -UseBasicParsing -ErrorAction SilentlyContinue
    }
    Invoke-WebRequest -Uri "$githubRaw/.codex/AGENTS.md" -OutFile (Join-Path $codexHome "AGENTS.md") -UseBasicParsing -ErrorAction SilentlyContinue

    $userSkills = Join-Path $HOME ".agents" "skills"
    foreach ($skill in @("draft-setup", "draft-learn", "draft-update")) {
        $skillDir = Join-Path $userSkills $skill
        if (Test-Path $skillDir) {
            Invoke-WebRequest -Uri "$githubRaw/skills/$skill/SKILL.md" -OutFile (Join-Path $skillDir "SKILL.md") -UseBasicParsing -ErrorAction SilentlyContinue
            Log "  Updated $skill skill."
        }
    }
    Log "  Codex files updated."
}

# ── Cursor: update if installed ───────────────────────────────────────────────

$cursorHome = if ($env:CURSOR_HOME) { $env:CURSOR_HOME } else { Join-Path $HOME ".cursor" }
$cursorDetectSh  = Join-Path $cursorHome "hooks" "draft" "cursor-session-start.sh"
$cursorDetectPs1 = Join-Path $cursorHome "hooks" "draft" "cursor-session-start.ps1"

if ((Test-Path $cursorDetectSh) -or (Test-Path $cursorDetectPs1)) {
    Log "Cursor install detected — updating..."

    $cursorHookDir = Join-Path $cursorHome "hooks" "draft"
    New-Item -ItemType Directory -Path $cursorHookDir -Force | Out-Null

    if (Test-Path $cursorDetectSh) {
        Invoke-WebRequest -Uri "$githubRaw/scripts/cursor-session-start.sh" -OutFile $cursorDetectSh -UseBasicParsing -ErrorAction SilentlyContinue
    }
    if (Test-Path $cursorDetectPs1) {
        Invoke-WebRequest -Uri "$githubRaw/scripts/cursor-session-start.ps1" -OutFile $cursorDetectPs1 -UseBasicParsing -ErrorAction SilentlyContinue
    }

    $cursorRules = Join-Path $cursorHome "rules" "draft-context.mdc"
    if (Test-Path $cursorRules) {
        Invoke-WebRequest -Uri "$githubRaw/.cursor/rules/draft-context.mdc" -OutFile $cursorRules -UseBasicParsing -ErrorAction SilentlyContinue
    }

    foreach ($agent in @("draft-researcher", "draft-executor", "draft-learner")) {
        $agentFile = Join-Path $cursorHome "agents" "$agent.md"
        if (Test-Path $agentFile) {
            Invoke-WebRequest -Uri "$githubRaw/agents/$agent.md" -OutFile $agentFile -UseBasicParsing -ErrorAction SilentlyContinue
        }
    }

    foreach ($skill in @("draft-setup", "draft-learn", "draft-update")) {
        $cursorSkillDir = Join-Path $cursorHome "skills" $skill
        if (Test-Path $cursorSkillDir) {
            Invoke-WebRequest -Uri "$githubRaw/skills/$skill/SKILL.md" -OutFile (Join-Path $cursorSkillDir "SKILL.md") -UseBasicParsing -ErrorAction SilentlyContinue
        }
        $userSkillDir = Join-Path $HOME ".agents" "skills" $skill
        if (Test-Path $userSkillDir) {
            Invoke-WebRequest -Uri "$githubRaw/skills/$skill/SKILL.md" -OutFile (Join-Path $userSkillDir "SKILL.md") -UseBasicParsing -ErrorAction SilentlyContinue
        }
    }
    Log "  Cursor files updated."
}

# ── Claude Code note ──────────────────────────────────────────────────────────

Warn "Claude Code: agent/skill files are managed by Anthropic's plugin system."
Warn "  They will update when the latest plugin version is processed by the marketplace."

# ── Record new version and reset cache ───────────────────────────────────────

Set-Content -Path $versionFile   -Value $latest        -NoNewline
Set-Content -Path $lastCheckFile -Value "UP_TO_DATE $latest" -NoNewline

Write-Host ""
Log "Draft updated to v$latest."
Write-Host ""
Write-Host "  Restart your session to apply changes."
Write-Host ""
