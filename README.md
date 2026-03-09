# cron-mcp

Schedule Windows desktop reminders directly from Claude Desktop.

**Zero dependencies.** Works on any Windows 10/11 machine with Claude Desktop installed — no Python, no Node.js, no installs.

## What it does

Adds three tools to Claude Desktop:
- **schedule_reminder** — set a one-time or recurring reminder
- **list_reminders** — see all scheduled reminders
- **cancel_reminder** — cancel one by ID

Reminders fire as Windows desktop notifications even when Claude Desktop is closed, backed by Windows Task Scheduler.

## Install (2 steps)

### 1. Download

Click **Code → Download ZIP** above, extract it anywhere (e.g. `C:\cron-mcp\`).

Or with git:
```
git clone https://github.com/alfredbot90/cron-mcp.git
```

### 2. Add to Claude Desktop

Open (or create) this file:
```
%APPDATA%\Claude\claude_desktop_config.json
```

Add the following — replace the path with wherever you extracted the folder:

```json
{
  "mcpServers": {
    "cron-mcp": {
      "command": "powershell.exe",
      "args": ["-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", "C:\\cron-mcp\\cron_mcp.ps1"]
    }
  }
}
```

If you already have other MCP servers, add `cron-mcp` alongside them inside the existing `mcpServers` block.

Restart Claude Desktop. Click the 🔨 tools icon to confirm the three tools appear.

## Usage

Just talk to Claude naturally:

> "Remind me to send the weekly status update at 4pm"

> "Set a reminder every weekday at 9am to check my email"

> "Remind me about the client call next Monday at 2pm"

> "In 30 minutes remind me to follow up with Jake"

> "What reminders do I have?"

> "Cancel reminder CRONMCP-A1B2C3D4"

## How it works

- Pure PowerShell — built into every Windows 10/11 machine
- Reminders are stored as Windows Task Scheduler tasks (prefixed `CRONMCP-`)
- Notifications fire via a tiny PowerShell balloon tip script written to `%APPDATA%\cron-mcp\` on first use
- Task Scheduler fires reminders even when Claude Desktop is closed

## Troubleshooting

**Tools don't appear in Claude Desktop?**
- Make sure the path in your config points to `cron_mcp.ps1`, not a folder
- Fully quit Claude Desktop (check system tray) and reopen it

**Notifications not showing?**
- Windows Settings → System → Notifications → make sure notifications are enabled
- Run `schtasks /query /fo list | findstr CRONMCP` in a terminal to confirm the task was created

**"Running scripts is disabled" error?**
- The `-ExecutionPolicy Bypass` flag in the config handles this — make sure it's included exactly as shown
