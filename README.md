# remind-me

> Schedule Windows desktop reminders directly from Claude Desktop — in plain English.

<!-- DEMO: Replace this line with a GIF showing:
     1. Typing "remind me to call Jake in 30 minutes" in Claude Desktop
     2. The balloon notification popping up 30 min later
     Suggested tool: ScreenToGif (free) or ShareX -->
![Demo coming soon](https://placehold.co/800x400?text=Demo+GIF+coming+soon)

**Zero dependencies.** Works on any Windows 10/11 machine with Claude Desktop — no Python, no Node.js, no installs of any kind.

---

## What it does

Three tools appear inside Claude Desktop:

| Tool | What you say |
|------|-------------|
| `schedule_reminder` | "Remind me to follow up with Sarah at 3pm" |
| `list_reminders` | "What reminders do I have?" |
| `cancel_reminder` | "Cancel my 3pm reminder" |

Reminders fire as Windows desktop notifications even when Claude Desktop is closed, backed by Windows Task Scheduler.

---

## Install

### Option A — One-liner (recommended)

Open PowerShell and paste:

```powershell
irm https://raw.githubusercontent.com/alfredbot90/remind-me/main/install.ps1 | iex
```

Downloads and configures everything automatically. No files to manage.

### Option B — ZIP install

1. **[⬇️ Download ZIP](https://github.com/alfredbot90/remind-me/archive/refs/heads/main.zip)** and extract it anywhere
2. Double-click **`install.bat`**

Both options automatically merge into your existing Claude Desktop config without overwriting anything.

---

## Usage

Just talk to Claude:

```
Remind me to send the weekly update at 4pm
```
```
Set a reminder every weekday at 9am to check my inbox
```
```
Remind me about the client call next Monday at 2pm
```
```
In 30 minutes remind me to follow up with Jake
```
```
What reminders do I have?
```
```
Cancel reminder CRONMCP-A1B2C3D4
```

**Supported recurrence:** `once` · `daily` · `weekly` · `weekdays (Mon–Fri)`

---

## How it works

- **Pure PowerShell** — built into every Windows 10/11 machine, nothing to install
- Reminders are stored as **Windows Task Scheduler** tasks (prefixed `CRONMCP-`)
- A tiny balloon-tip notification script is written to `%APPDATA%\remind-me\` on first use
- Task Scheduler fires reminders even when Claude Desktop is closed

---

## Platform support

| Platform | Status |
|----------|--------|
| Windows 10/11 | ✅ Supported |
| macOS | 🔜 Coming soon (launchd + osascript) |
| Linux | 🔜 Coming soon (cron + notify-send) |

PRs welcome.

---

## Troubleshooting

**Tools don't appear in Claude Desktop?**
- Make sure the path in the config points to `cron_mcp.ps1`, not a folder
- Fully quit Claude Desktop (check the system tray) and reopen it

**Notifications not showing?**
- Windows Settings → System → Notifications → make sure notifications are on
- Run `schtasks /query /fo list | findstr CRONMCP` in a terminal to verify the task exists

**"Running scripts is disabled" error?**
- The `-ExecutionPolicy Bypass` flag in the config handles this — make sure it's included exactly as shown above

---

## License

MIT — free to use, modify, and distribute.

---

<p align="center">
  Built by <a href="https://databa.io">Databa</a> · 
  <a href="https://databa.io">databa.io</a>
</p>
