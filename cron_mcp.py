"""
cron-mcp: Schedule Windows desktop reminders from Claude Desktop.
Requires: pip install mcp dateparser
"""

import subprocess
import uuid
import os
import sys
from pathlib import Path
from datetime import datetime

import dateparser
from mcp.server.fastmcp import FastMCP

# ── Config ────────────────────────────────────────────────────────────────────
TASK_PREFIX = "CRONMCP"
DATA_DIR = Path(os.environ.get("APPDATA", Path.home())) / "cron-mcp"
NOTIFY_SCRIPT = DATA_DIR / "notify.ps1"

NOTIFY_PS1 = """\
param([string]$Title = "Reminder", [string]$Message = "")
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$notify = New-Object System.Windows.Forms.NotifyIcon
$notify.Icon = [System.Drawing.SystemIcons]::Information
$notify.BalloonTipTitle = $Title
$notify.BalloonTipText = $Message
$notify.Visible = $true
$notify.ShowBalloonTip(10000)
Start-Sleep -Seconds 12
$notify.Dispose()
"""

def ensure_setup():
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    if not NOTIFY_SCRIPT.exists():
        NOTIFY_SCRIPT.write_text(NOTIFY_PS1)

def parse_date(text: str) -> datetime:
    dt = dateparser.parse(text, settings={"PREFER_DATES_FROM": "future", "RETURN_AS_TIMEZONE_AWARE": False})
    if not dt:
        raise ValueError(
            f'Could not understand "{text}". Try: "tomorrow 9am", "Monday 2pm", "in 30 minutes", "March 15 at 10am"'
        )
    return dt

def safe(s: str) -> str:
    """Strip characters that break schtasks arguments."""
    return s.replace('"', "'").replace("&", "and").replace("<", "").replace(">", "").replace("|", "")

def run(cmd: str):
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip())
    return result.stdout

# ── MCP Server ────────────────────────────────────────────────────────────────
mcp = FastMCP("cron-mcp")

@mcp.tool()
def schedule_reminder(
    message: str,
    datetime_str: str,
    recurrence: str = "once",
    title: str = "Reminder"
) -> str:
    """
    Schedule a Windows desktop reminder notification.

    Args:
        message: The reminder text to display.
        datetime_str: When to fire — natural language works: "tomorrow 9am",
                      "Monday 2pm", "in 30 minutes", "March 15 at 10am".
        recurrence: "once" (default), "daily", "weekly", or "weekdays" (Mon–Fri).
        title: Notification title (default: "Reminder").
    """
    ensure_setup()

    dt = parse_date(datetime_str)
    if dt < datetime.now():
        raise ValueError(f"That time is in the past ({dt.strftime('%c')}). Please give a future date/time.")

    task_id = f"{TASK_PREFIX}-{uuid.uuid4().hex[:8].upper()}"
    time_str = dt.strftime("%H:%M")
    date_str = dt.strftime("%m/%d/%Y")
    day_name = ["SUN","MON","TUE","WED","THU","FRI","SAT"][dt.weekday() % 7]  # weekday() is Mon=0

    ps_args = (
        f'-WindowStyle Hidden -NonInteractive -ExecutionPolicy Bypass '
        f'-File "{NOTIFY_SCRIPT}" -Title "{safe(title)}" -Message "{safe(message)}"'
    )
    tr = f'powershell.exe {ps_args}'

    recurrence = recurrence.lower()
    if recurrence == "daily":
        cmd = f'schtasks /create /tn "{task_id}" /tr "{tr}" /sc daily /st {time_str} /sd {date_str} /f'
    elif recurrence == "weekly":
        cmd = f'schtasks /create /tn "{task_id}" /tr "{tr}" /sc weekly /d {day_name} /st {time_str} /sd {date_str} /f'
    elif recurrence == "weekdays":
        cmd = f'schtasks /create /tn "{task_id}" /tr "{tr}" /sc weekly /d MON,TUE,WED,THU,FRI /st {time_str} /sd {date_str} /f'
    else:
        cmd = f'schtasks /create /tn "{task_id}" /tr "{tr}" /sc once /st {time_str} /sd {date_str} /f'

    run(cmd)

    label = {"once": "One-time", "daily": "Daily", "weekly": "Weekly", "weekdays": "Weekdays (Mon–Fri)"}.get(recurrence, recurrence)
    friendly = dt.strftime("%A, %B %-d at %-I:%M %p") if sys.platform != "win32" else dt.strftime("%A, %B %d at %I:%M %p")

    return "\n".join([
        "✅ Reminder scheduled!",
        f"ID:          {task_id}",
        f'Message:     "{message}"',
        f"When:        {friendly}",
        f"Recurrence:  {label}",
        "",
        f'To cancel: use cancel_reminder with id="{task_id}"',
    ])


@mcp.tool()
def list_reminders() -> str:
    """List all currently scheduled reminders with their IDs and next run times."""
    ensure_setup()
    try:
        output = run("schtasks /query /fo csv /v 2>nul")
    except Exception:
        return "No reminders found."

    lines = output.splitlines()
    if not lines:
        return "No reminders found."

    header = [c.strip('"') for c in lines[0].split('","')]
    name_i = next((i for i, c in enumerate(header) if "TaskName" in c), 0)
    next_i = next((i for i, c in enumerate(header) if "Next Run" in c), 1)
    stat_i = next((i for i, c in enumerate(header) if c == "Status"), 3)

    reminders = []
    for line in lines[1:]:
        if TASK_PREFIX not in line:
            continue
        parts = [p.strip('"') for p in line.split('","')]
        name = parts[name_i].split("\\")[-1] if len(parts) > name_i else ""
        if not name.startswith(TASK_PREFIX):
            continue
        next_run = parts[next_i] if len(parts) > next_i else "Unknown"
        status = parts[stat_i] if len(parts) > stat_i else "Unknown"
        reminders.append(f"📅 {name}\n   Next run: {next_run}\n   Status:   {status}")

    return "\n\n".join(reminders) if reminders else "No reminders currently scheduled."


@mcp.tool()
def cancel_reminder(id: str) -> str:
    """
    Cancel a scheduled reminder.

    Args:
        id: The reminder ID from list_reminders (e.g. "CRONMCP-A1B2C3D4").
    """
    task_name = id if id.startswith(TASK_PREFIX) else f"{TASK_PREFIX}-{id}"
    try:
        run(f'schtasks /delete /tn "{task_name}" /f')
        return f'✅ Reminder "{task_name}" has been cancelled.'
    except Exception:
        raise ValueError(f'Could not find reminder "{task_name}". Use list_reminders to check the ID.')


if __name__ == "__main__":
    mcp.run()
