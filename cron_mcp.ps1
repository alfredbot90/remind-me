# cron_mcp.ps1 -- MCP server for Windows reminders
# No dependencies. Requires only Windows 10/11 + Claude Desktop.
# https://github.com/alfredbot90/remind-me

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
$OutputEncoding           = [System.Text.Encoding]::UTF8
# NOTE: No global $ErrorActionPreference = "Stop" -- transient errors must not crash the server loop

# -- Config -------------------------------------------------------------------
$TASK_PREFIX   = "CRONMCP"
$DATA_DIR      = Join-Path $env:APPDATA "remind-me"
$NOTIFY_SCRIPT = Join-Path $DATA_DIR "notify.ps1"

# -- Setup: write notification helper on first run ----------------------------
function Ensure-Setup {
    if (-not (Test-Path $DATA_DIR)) {
        New-Item -ItemType Directory -Path $DATA_DIR -Force | Out-Null
    }
    if (-not (Test-Path $NOTIFY_SCRIPT)) {
        @'
param([string]$Title = "Reminder", [string]$Message = "")
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$n = New-Object System.Windows.Forms.NotifyIcon
$n.Icon = [System.Drawing.SystemIcons]::Information
$n.BalloonTipTitle = $Title
$n.BalloonTipText  = $Message
$n.Visible = $true
$n.ShowBalloonTip(10000)
Start-Sleep -Seconds 12
$n.Dispose()
'@ | Set-Content $NOTIFY_SCRIPT -Encoding UTF8
    }
}

# -- Natural-language date parser ---------------------------------------------
function Parse-Time($s) {
    $s = $s.Trim()
    if ($s -match '^(\d{1,2}):(\d{2})\s*(am|pm)?$') {
        $h = [int]$Matches[1]; $m = [int]$Matches[2]; $ap = $Matches[3]
        if ($ap -eq 'pm' -and $h -ne 12) { $h += 12 }
        elseif ($ap -eq 'am' -and $h -eq 12) { $h = 0 }
        return [pscustomobject]@{ h = $h; m = $m }
    }
    if ($s -match '^(\d{1,2})\s*(am|pm)$') {
        $h = [int]$Matches[1]; $ap = $Matches[2]
        if ($ap -eq 'pm' -and $h -ne 12) { $h += 12 }
        elseif ($ap -eq 'am' -and $h -eq 12) { $h = 0 }
        return [pscustomobject]@{ h = $h; m = 0 }
    }
    return $null
}

function Parse-NLDate($text) {
    $now = Get-Date
    $t   = ($text.Trim().ToLower() -replace '\s+', ' ')

    if ($t -match '^in\s+(\d+)\s+(min(?:utes?)?|hrs?|hours?)$') {
        $n = [int]$Matches[1]
        if ($Matches[2] -match '^min') { return $now.AddMinutes($n) }
        else                           { return $now.AddHours($n)   }
    }
    if ($t -match '^today\s+(?:at\s+)?(.+)$') {
        $pt = Parse-Time $Matches[1]
        if ($pt) { return $now.Date.AddHours($pt.h).AddMinutes($pt.m) }
    }
    if ($t -match '^tomorrow\s+(?:at\s+)?(.+)$') {
        $pt = Parse-Time $Matches[1]
        if ($pt) { return $now.Date.AddDays(1).AddHours($pt.h).AddMinutes($pt.m) }
    }
    $dow = @{ sunday=0; monday=1; tuesday=2; wednesday=3; thursday=4; friday=5; saturday=6 }
    foreach ($day in $dow.Keys) {
        if ($t -match "^(?:next\s+)?$day\s+(?:at\s+)?(.+)$") {
            $pt = Parse-Time $Matches[1]
            if ($pt) {
                $diff = ($dow[$day] - [int]$now.DayOfWeek + 7) % 7
                if ($diff -eq 0) { $diff = 7 }
                return $now.Date.AddDays($diff).AddHours($pt.h).AddMinutes($pt.m)
            }
        }
    }
    try { return [datetime]::Parse($text) } catch {}
    return $null
}

# -- Tool implementations -----------------------------------------------------
function Invoke-ScheduleReminder($toolArgs) {
    Ensure-Setup
    $message     = $toolArgs.message
    $datetimeStr = $toolArgs.datetime_str
    $recurrence  = if ($toolArgs.recurrence) { $toolArgs.recurrence.ToLower() } else { "once" }
    $title       = if ($toolArgs.title)      { $toolArgs.title }               else { "Reminder" }

    $dt = Parse-NLDate $datetimeStr
    if (-not $dt) {
        throw "Could not understand `"$datetimeStr`". Try: `"tomorrow 9am`", `"Monday 2pm`", `"in 30 minutes`""
    }
    if ($dt -lt (Get-Date)) {
        throw "That time is in the past ($($dt.ToString('g'))). Please give a future time."
    }

    $taskId  = "$TASK_PREFIX-$([guid]::NewGuid().ToString('N').Substring(0,8).ToUpper())"
    $timeStr = $dt.ToString("HH:mm")
    $dateStr = $dt.ToString("MM/dd/yyyy")
    $dayAbbr = @("SUN","MON","TUE","WED","THU","FRI","SAT")[[int]$dt.DayOfWeek]

    $safeTitle = $title   -replace '"', "'"
    $safeMsg   = $message -replace '"', "'"
    $tr = "powershell.exe -WindowStyle Hidden -NonInteractive -ExecutionPolicy Bypass -File `"$NOTIFY_SCRIPT`" -Title `"$safeTitle`" -Message `"$safeMsg`""

    $cmd = switch ($recurrence) {
        "daily"    { "schtasks /create /tn `"$taskId`" /tr `"$tr`" /sc daily /st $timeStr /sd $dateStr /f" }
        "weekly"   { "schtasks /create /tn `"$taskId`" /tr `"$tr`" /sc weekly /d $dayAbbr /st $timeStr /sd $dateStr /f" }
        "weekdays" { "schtasks /create /tn `"$taskId`" /tr `"$tr`" /sc weekly /d MON,TUE,WED,THU,FRI /st $timeStr /sd $dateStr /f" }
        default    { "schtasks /create /tn `"$taskId`" /tr `"$tr`" /sc once /st $timeStr /sd $dateStr /f" }
    }

    $out = cmd /c $cmd 2>&1
    if ($LASTEXITCODE -ne 0) { throw "schtasks failed: $out" }

    $labels   = @{ once="One-time"; daily="Daily"; weekly="Weekly"; weekdays="Weekdays (Mon-Fri)" }
    $friendly = $dt.ToString("dddd, MMMM d 'at' h:mm tt")

    return @"
Reminder scheduled!
ID:          $taskId
Message:     "$message"
When:        $friendly
Recurrence:  $($labels[$recurrence])

To cancel: cancel_reminder id="$taskId"
"@
}

function Invoke-ListReminders {
    $raw = cmd /c "schtasks /query /fo csv /v 2>nul"
    if (-not $raw) { return "No reminders currently scheduled." }

    $lines = $raw -split "`n"
    $header = (($lines | Select-Object -First 1) -replace '"','') -split ','
    $ni = 0; $ti = 1; $si = 3
    for ($i = 0; $i -lt $header.Count; $i++) {
        if ($header[$i] -match 'TaskName')  { $ni = $i }
        if ($header[$i] -match 'Next Run')  { $ti = $i }
        if ($header[$i] -eq 'Status')       { $si = $i }
    }

    $out = $lines | Where-Object { $_ -match $TASK_PREFIX } | ForEach-Object {
        $cols    = ($_ -replace '"','') -split ','
        $name    = ($cols[$ni] -replace '.*\\', '').Trim()
        $nextRun = if ($cols.Count -gt $ti) { $cols[$ti].Trim() } else { "Unknown" }
        $status  = if ($cols.Count -gt $si) { $cols[$si].Trim() } else { "Unknown" }
        "- $name | Next: $nextRun | $status"
    }
    if (-not $out) { return "No reminders currently scheduled." }
    return ($out -join "`n")
}

function Invoke-CancelReminder($toolArgs) {
    $name = if ($toolArgs.id -match "^$TASK_PREFIX") { $toolArgs.id } else { "$TASK_PREFIX-$($toolArgs.id)" }
    $out  = cmd /c "schtasks /delete /tn `"$name`" /f 2>&1"
    if ($LASTEXITCODE -ne 0) {
        throw "Could not find `"$name`". Use list_reminders to check the exact ID."
    }
    return "Reminder `"$name`" cancelled."
}

# -- MCP protocol helpers -----------------------------------------------------
function Send-Response($id, $result) {
    $r = @{ jsonrpc = "2.0"; id = $id; result = $result }
    [Console]::WriteLine(($r | ConvertTo-Json -Depth 20 -Compress))
    [Console]::Out.Flush()
}

function Send-Error($id, $code, $msg) {
    $r = @{ jsonrpc = "2.0"; id = $id; error = @{ code = $code; message = $msg } }
    [Console]::WriteLine(($r | ConvertTo-Json -Depth 10 -Compress))
    [Console]::Out.Flush()
}

# -- Tool manifest ------------------------------------------------------------
$TOOLS = @(
    @{
        name        = "schedule_reminder"
        description = "Schedule a Windows desktop reminder. Natural language dates: 'tomorrow 9am', 'Monday 2pm', 'in 30 minutes', 'in 2 hours'."
        inputSchema = @{
            type       = "object"
            properties = @{
                message      = @{ type = "string"; description = "Reminder text" }
                datetime_str = @{ type = "string"; description = "When: 'tomorrow 9am', 'Monday 2pm', 'in 30 minutes'" }
                recurrence   = @{ type = "string"; enum = @("once","daily","weekly","weekdays"); description = "Repeat (default: once)" }
                title        = @{ type = "string"; description = "Notification title (default: Reminder)" }
            }
            required = @("message","datetime_str")
        }
    },
    @{
        name        = "list_reminders"
        description = "List all scheduled reminders with IDs and next run times."
        inputSchema = @{ type = "object"; properties = @{} }
    },
    @{
        name        = "cancel_reminder"
        description = "Cancel a reminder by its ID (from list_reminders)."
        inputSchema = @{
            type       = "object"
            properties = @{ id = @{ type = "string"; description = "Reminder ID e.g. CRONMCP-A1B2C3D4" } }
            required   = @("id")
        }
    }
)

# -- Main loop ----------------------------------------------------------------
while ($true) {
    $line = [Console]::ReadLine()
    if ($null -eq $line) { break }
    $line = $line.Trim()
    if ($line -eq '') { continue }

    try {
        $msg    = $line | ConvertFrom-Json
        $method = $msg.method
        $id     = $msg.id

        switch ($method) {
            "initialize" {
                Send-Response $id @{
                    protocolVersion = "2024-11-05"
                    capabilities    = @{ tools = @{} }
                    serverInfo      = @{ name = "remind-me"; version = "1.0.0" }
                }
            }
            "notifications/initialized" { <# no response needed #> }
            "ping"       { Send-Response $id @{} }
            "tools/list" { Send-Response $id @{ tools = $TOOLS } }
            "tools/call" {
                $toolName = $msg.params.name
                $toolArgs = $msg.params.arguments   # renamed from $args -- $args is a reserved PS variable
                try {
                    $text = switch ($toolName) {
                        "schedule_reminder" { Invoke-ScheduleReminder $toolArgs }
                        "list_reminders"    { Invoke-ListReminders             }
                        "cancel_reminder"   { Invoke-CancelReminder  $toolArgs }
                        default             { throw "Unknown tool: $toolName"  }
                    }
                    Send-Response $id @{ content = @(@{ type = "text"; text = $text }) }
                } catch {
                    # Tool errors are returned as MCP error content, not fatal
                    Send-Response $id @{
                        content = @(@{ type = "text"; text = "Error: $_" })
                        isError = $true
                    }
                }
            }
            default {
                # Unknown method -- send error but keep loop alive
                if ($id) { Send-Error $id -32601 "Method not found: $method" }
            }
        }
    } catch {
        # Parse/protocol error -- log to stderr, never crash
        [Console]::Error.WriteLine("cron_mcp error: $_")
        [Console]::Error.Flush()
    }
}
