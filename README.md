# cron-mcp

Schedule Windows desktop reminder notifications directly from Claude Desktop.

## What it does

Adds three tools to Claude Desktop:
- **schedule_reminder** — set a one-time or recurring reminder
- **list_reminders** — see all scheduled reminders  
- **cancel_reminder** — cancel one by ID

Reminders fire as Windows desktop notifications even when Claude Desktop is closed, backed by Windows Task Scheduler.

## Requirements

- Windows 10 or 11
- Python 3.8+ (check: open a terminal and run `python --version`)
- [Claude Desktop](https://claude.ai/download)

## Install

### 1. Download this repo

```
git clone https://github.com/alfredbot90/cron-mcp.git
cd cron-mcp
```

Or just download the ZIP from GitHub and extract it.

### 2. Install Python dependencies

```
pip install mcp dateparser
```

### 3. Add to Claude Desktop

Open your Claude Desktop config file:
```
%APPDATA%\Claude\claude_desktop_config.json
```

Add the following (replace the path with wherever you put this folder):

```json
{
  "mcpServers": {
    "cron-mcp": {
      "command": "python",
      "args": ["C:\\path\\to\\cron-mcp\\cron_mcp.py"]
    }
  }
}
```

If `python` isn't recognized, use the full path, e.g. `C:\\Python313\\python.exe`.

If you already have other MCP servers configured, just add `cron-mcp` inside the existing `mcpServers` block.

### 4. Restart Claude Desktop

Fully quit and reopen Claude Desktop. Click the 🔨 tools icon to confirm the three tools appear.

## Usage

Just talk to Claude naturally:

> "Remind me to send the weekly update at 4pm today"

> "Set a reminder every weekday at 9am to check my inbox"

> "Remind me about the board call next Monday at 2pm"

> "What reminders do I have set?"

> "Cancel reminder CRONMCP-A1B2C3D4"

## How it works

- Reminders are stored as Windows Task Scheduler tasks (prefix: `CRONMCP-`)
- Each task runs a small PowerShell script that shows a desktop balloon notification
- Task Scheduler fires them even when Claude Desktop is closed
- No internet connection required after install

## Troubleshooting

**Notifications not appearing?**
- Check Windows Settings → System → Notifications → make sure notifications are on
- Run `schtasks /query /fo list | findstr CRONMCP` in a terminal to confirm tasks exist

**"python is not recognized"?**
- Use the full path to python.exe in `claude_desktop_config.json`
- Find it by running `where python` in a terminal

**`pip install` fails?**
- Try `python -m pip install mcp dateparser`
