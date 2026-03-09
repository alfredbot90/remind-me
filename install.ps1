# remind-me installer
# Works two ways:
#   Web:  irm https://raw.githubusercontent.com/alfredbot90/remind-me/main/install.ps1 | iex
#   File: Double-click install.bat (from extracted ZIP)

$RAW_BASE   = "https://raw.githubusercontent.com/alfredbot90/remind-me/main"
$ConfigPath = Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::ApplicationData)) "Claude\claude_desktop_config.json"
$BackupPath = "$ConfigPath.bak"

Write-Host ""
Write-Host "  remind-me" -ForegroundColor Cyan -NoNewline
Write-Host " -- Claude Desktop reminders"
Write-Host "  -----------------------------------------"
Write-Host ""

# -- 1. Find or download cron_mcp.ps1 ----------------------------------------
$webInstall = [string]::IsNullOrEmpty($PSScriptRoot)

if ($webInstall) {
    $InstallDir = Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::ApplicationData)) "remind-me"
    $McpScript  = Join-Path $InstallDir "cron_mcp.ps1"
    Write-Host "  Downloading to $InstallDir ..." -ForegroundColor DarkGray
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    try {
        Invoke-RestMethod -Uri "$RAW_BASE/cron_mcp.ps1" -OutFile $McpScript
    } catch {
        Write-Host "  ERROR: Could not download cron_mcp.ps1" -ForegroundColor Red
        Write-Host "  Check your internet connection and try again."
        Write-Host "  $_"
        if (-not $webInstall) { Read-Host "  Press Enter to exit" }
        exit 1
    }
    Write-Host "  OK  Downloaded cron_mcp.ps1" -ForegroundColor Green
} else {
    $McpScript = Join-Path $PSScriptRoot "cron_mcp.ps1"
    if (-not (Test-Path $McpScript)) {
        Write-Host "  ERROR: cron_mcp.ps1 not found in the same folder." -ForegroundColor Red
        Write-Host "  Make sure install.bat and cron_mcp.ps1 are in the same directory."
        Write-Host ""
        Read-Host "  Press Enter to exit"
        exit 1
    }
}

# -- 2. Read or create claude_desktop_config.json -----------------------------
$config = [PSCustomObject]@{ mcpServers = [PSCustomObject]@{} }

if (Test-Path $ConfigPath) {
    # Backup before touching anything
    Copy-Item $ConfigPath $BackupPath -Force
    Write-Host "  OK  Backed up config to $BackupPath" -ForegroundColor DarkGray

    $raw = Get-Content $ConfigPath -Raw -Encoding UTF8

    # Strip UTF-8 BOM if present
    $raw = $raw -replace '^\xef\xbb\xbf', ''
    $raw = $raw.Trim()

    if ($raw -ne '') {
        try {
            $config = $raw | ConvertFrom-Json
        } catch {
            Write-Host ""
            Write-Host "  WARNING: Existing config has invalid JSON." -ForegroundColor Yellow
            Write-Host "  A backup was saved to: $BackupPath"
            Write-Host "  Starting fresh with a clean config."
            Write-Host ""
            $config = [PSCustomObject]@{ mcpServers = [PSCustomObject]@{} }
        }
    }

    # Add mcpServers node if missing
    if (-not ($config | Get-Member -Name "mcpServers" -ErrorAction SilentlyContinue)) {
        $config | Add-Member -NotePropertyName "mcpServers" -NotePropertyValue ([PSCustomObject]@{})
    }
} else {
    $configDir = Split-Path $ConfigPath
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }
}

# -- 3. Inject remind-me entry ------------------------------------------------
$entry = [PSCustomObject]@{
    command = "powershell.exe"
    args    = @("-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", $McpScript)
}
$config.mcpServers | Add-Member -NotePropertyName "remind-me" -NotePropertyValue $entry -Force

# -- 4. Write config ----------------------------------------------------------
$json = $config | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($ConfigPath, $json, (New-Object System.Text.UTF8Encoding $false))

Write-Host "  OK  Config updated" -ForegroundColor Green
Write-Host "      $ConfigPath" -ForegroundColor DarkGray
Write-Host ""

# -- 5. Restart Claude Desktop if running -------------------------------------
$claude = Get-Process -Name "Claude" -ErrorAction SilentlyContinue
if ($claude) {
    Write-Host "  Claude Desktop is running." -ForegroundColor Yellow
    $answer = Read-Host "  Restart it now to activate? (Y/n)"
    if ($answer -ne 'n' -and $answer -ne 'N') {
        $claude | Stop-Process -Force
        Start-Sleep -Seconds 2
        $exePaths = @(
            "$env:LOCALAPPDATA\AnthropicClaude\Claude.exe",
            "$env:LOCALAPPDATA\Programs\claude-desktop\Claude.exe",
            "$env:LOCALAPPDATA\Programs\Claude\Claude.exe"
        )
        $exe = $exePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($exe) { Start-Process $exe; Write-Host "  OK  Restarted" -ForegroundColor Green }
        else { Write-Host "  Please open Claude Desktop manually." -ForegroundColor Yellow }
    }
} else {
    Write-Host "  Open Claude Desktop to activate remind-me." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  All done! Try: `"Remind me to check email in 10 minutes`"" -ForegroundColor Cyan
Write-Host "  databa.io" -ForegroundColor DarkGray
Write-Host ""
if (-not $webInstall) { Read-Host "  Press Enter to close" }
