# remind-me installer
# Merges the MCP server entry into Claude Desktop config without touching existing settings.

$ErrorActionPreference = "Stop"
$ScriptDir  = $PSScriptRoot
$McpScript  = Join-Path $ScriptDir "cron_mcp.ps1"
$ConfigPath = Join-Path $env:APPDATA "Claude\claude_desktop_config.json"

Write-Host ""
Write-Host "  remind-me -- Claude Desktop reminder installer"
Write-Host "  -----------------------------------------------"
Write-Host ""

# 1. Verify cron_mcp.ps1 is present in the same folder
if (-not (Test-Path $McpScript)) {
    Write-Host "  ERROR: cron_mcp.ps1 not found." -ForegroundColor Red
    Write-Host "  Make sure install.bat and cron_mcp.ps1 are in the same folder."
    Write-Host ""
    Read-Host "  Press Enter to exit"
    exit 1
}

# 2. Read or create claude_desktop_config.json
$config = [PSCustomObject]@{ mcpServers = [PSCustomObject]@{} }

if (Test-Path $ConfigPath) {
    try {
        $raw    = Get-Content $ConfigPath -Raw -Encoding UTF8
        $config = $raw | ConvertFrom-Json

        if (-not ($config | Get-Member -Name "mcpServers" -ErrorAction SilentlyContinue)) {
            $config | Add-Member -NotePropertyName "mcpServers" -NotePropertyValue ([PSCustomObject]@{})
        }
    } catch {
        Write-Host "  ERROR: Could not parse Claude Desktop config." -ForegroundColor Red
        Write-Host "  File: $ConfigPath"
        Write-Host "  $_"
        Write-Host ""
        Read-Host "  Press Enter to exit"
        exit 1
    }
} else {
    $configDir = Split-Path $ConfigPath
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }
}

# 3. Inject the remind-me MCP server entry
$entry = [PSCustomObject]@{
    command = "powershell.exe"
    args    = @(
        "-NoProfile",
        "-NonInteractive",
        "-ExecutionPolicy", "Bypass",
        "-File", $McpScript
    )
}
$config.mcpServers | Add-Member -NotePropertyName "remind-me" -NotePropertyValue $entry -Force

# 4. Write config back as UTF-8
$json = $config | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($ConfigPath, $json, [System.Text.Encoding]::UTF8)

Write-Host "  OK  remind-me added to Claude Desktop config" -ForegroundColor Green
Write-Host "      $ConfigPath" -ForegroundColor DarkGray
Write-Host ""

# 5. Offer to restart Claude Desktop if it is running
$claude = Get-Process -Name "Claude" -ErrorAction SilentlyContinue
if ($claude) {
    Write-Host "  Claude Desktop is running." -ForegroundColor Yellow
    $answer = Read-Host "  Restart it now to activate remind-me? (Y/n)"
    if ($answer -ne 'n' -and $answer -ne 'N') {
        $claude | Stop-Process -Force
        Start-Sleep -Seconds 2

        $exePaths = @(
            "$env:LOCALAPPDATA\AnthropicClaude\Claude.exe",
            "$env:LOCALAPPDATA\Programs\claude-desktop\Claude.exe",
            "$env:LOCALAPPDATA\Programs\Claude\Claude.exe"
        )
        $exe = $exePaths | Where-Object { Test-Path $_ } | Select-Object -First 1

        if ($exe) {
            Start-Process $exe
            Write-Host "  OK  Claude Desktop restarted" -ForegroundColor Green
        } else {
            Write-Host "  Please open Claude Desktop manually." -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "  Open Claude Desktop to activate remind-me." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  All done! Try asking Claude:" -ForegroundColor Cyan
Write-Host "  Remind me to check email in 10 minutes" -ForegroundColor White
Write-Host ""
Write-Host "  databa.io" -ForegroundColor DarkGray
Write-Host ""
Read-Host "  Press Enter to close"
