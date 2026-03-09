# cron-mcp

Schedule Windows desktop reminder notifications directly from Claude Desktop.

## What it does

Adds three tools to Claude Desktop:
- **schedule_reminder** — set a one-time or recurring reminder
- **list_reminders** — see all scheduled reminders
- **cancel_reminder** — cancel one by ID

Reminders fire as Windows desktop notifications (balloon tips), even when Claude Desktop is closed, because they're backed by Windows Task Scheduler.

## Install

### 1. Prerequisites
- [Node.js](https://nodejs.org/) v18 or later (check: `node --version`)
- [Claude Desktop](https://claude.ai/download)

### 2. Install dependencies

Open a terminal in this folder and run:
```
npm install
```

### 3. Add to Claude Desktop

Open your Claude Desktop config file:
```
%APPDATA%\Claude\claude_desktop_config.json
```

Add the following (replace `C:\path\to\cron-mcp` with the actual folder path):

```json
{
  "mcpServers": {
    "cron-mcp": {
      "command": "node",
      "args": ["C:\\path\\to\\cron-mcp\\src\\index.js"]
    }
  }
}
```

If you already have other MCP servers, add `cron-mcp` alongside them inside `mcpServers`.

### 4. Restart Claude Desktop

Fully quit and reopen Claude Desktop. You should see a 🔨 tools icon — click it to confirm `schedule_reminder`, `list_reminders`, and `cancel_reminder` appear.

## Usage examples

Just talk to Claude naturally:

> "Remind me to send the weekly update at 4pm today"

> "Set a reminder every weekday at 9am to check my inbox"

> "Remind me about the board call next Monday at 2pm"

> "What reminders do I have set?"

> "Cancel reminder CRONMCP-A1B2C3D4"

## How it works

- Reminders are stored as Windows Task Scheduler tasks (prefix: `CRONMCP-`)
- Each task runs a small PowerShell script that shows a desktop notification
- Task Scheduler fires them even if Claude Desktop is closed
- No internet connection required once installed

## Troubleshooting

**Notifications not appearing?**
- Make sure notifications are enabled for PowerShell in Windows Settings → System → Notifications
- Run `schtasks /query /tn "CRONMCP-*"` in a terminal to confirm tasks were created

**"node is not recognized" error?**
- Make sure Node.js is installed and in your PATH
- Try specifying the full path to node.exe in `claude_desktop_config.json`, e.g. `"command": "C:\\Program Files\\nodejs\\node.exe"`

**Config file doesn't exist?**
- Create it at `%APPDATA%\Claude\claude_desktop_config.json` with the content from step 3
