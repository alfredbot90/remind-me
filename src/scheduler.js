import { execSync } from 'child_process';
import { randomUUID } from 'crypto';
import { existsSync, mkdirSync, writeFileSync } from 'fs';
import { join } from 'path';
import * as chrono from 'chrono-node';

const TASK_PREFIX = 'CRONMCP';
const DATA_DIR = join(process.env.APPDATA || '', 'cron-mcp');
const NOTIFY_SCRIPT = join(DATA_DIR, 'notify.ps1');

// Balloon tip notification — works on all Windows versions, no extra installs
const NOTIFY_PS1 = `
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
`.trim();

function ensureSetup() {
  if (!existsSync(DATA_DIR)) mkdirSync(DATA_DIR, { recursive: true });
  if (!existsSync(NOTIFY_SCRIPT)) writeFileSync(NOTIFY_SCRIPT, NOTIFY_PS1);
}

function parseDate(input) {
  const results = chrono.parse(input, new Date(), { forwardDate: true });
  if (!results || results.length === 0) {
    throw new Error(`Could not understand the date/time: "${input}". Try something like "tomorrow at 9am", "Monday 2pm", or "2026-03-10 14:30".`);
  }
  return results[0].start.date();
}

function pad(n) { return String(n).padStart(2, '0'); }

function toSchtasksTime(date) {
  return `${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

function toSchtasksDate(date) {
  return `${pad(date.getMonth() + 1)}/${pad(date.getDate())}/${date.getFullYear()}`;
}

function escapeForSchtasks(str) {
  // Escape quotes for the schtasks /tr argument
  return str.replace(/"/g, '\'').replace(/[&<>|]/g, '');
}

export async function scheduleReminder({ message, datetime, recurrence = 'once', title = 'Reminder' }) {
  ensureSetup();

  const date = parseDate(datetime);
  if (date < new Date()) {
    throw new Error(`That time is in the past: ${date.toLocaleString()}. Please specify a future date/time.`);
  }

  const id = `${TASK_PREFIX}-${randomUUID().slice(0, 8).toUpperCase()}`;
  const time = toSchtasksTime(date);
  const dateStr = toSchtasksDate(date);
  const safeTitle = escapeForSchtasks(title);
  const safeMessage = escapeForSchtasks(message);

  // Build the PowerShell command Task Scheduler will run
  const psArgs = `-WindowStyle Hidden -NonInteractive -ExecutionPolicy Bypass -File "${NOTIFY_SCRIPT}" -Title "${safeTitle}" -Message "${safeMessage}"`;
  const tr = `powershell.exe ${psArgs}`;

  const DAYS = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

  let cmd;
  switch (recurrence) {
    case 'daily':
      cmd = `schtasks /create /tn "${id}" /tr "${tr}" /sc daily /st ${time} /sd ${dateStr} /f`;
      break;
    case 'weekly':
      cmd = `schtasks /create /tn "${id}" /tr "${tr}" /sc weekly /d ${DAYS[date.getDay()]} /st ${time} /sd ${dateStr} /f`;
      break;
    case 'weekdays':
      cmd = `schtasks /create /tn "${id}" /tr "${tr}" /sc weekly /d MON,TUE,WED,THU,FRI /st ${time} /sd ${dateStr} /f`;
      break;
    default: // once
      cmd = `schtasks /create /tn "${id}" /tr "${tr}" /sc once /st ${time} /sd ${dateStr} /f`;
  }

  try {
    execSync(cmd, { stdio: 'pipe', shell: true });
  } catch (err) {
    throw new Error(`Failed to create task: ${err.stderr?.toString() || err.message}`);
  }

  const recurrenceLabel = recurrence === 'once' ? 'One-time' : recurrence.charAt(0).toUpperCase() + recurrence.slice(1);
  return [
    `✅ Reminder scheduled!`,
    `ID: ${id}`,
    `Message: "${message}"`,
    `When: ${date.toLocaleString('en-US', { weekday: 'long', month: 'long', day: 'numeric', year: 'numeric', hour: 'numeric', minute: '2-digit' })}`,
    `Recurrence: ${recurrenceLabel}`,
    ``,
    `To cancel: use cancel_reminder with ID "${id}"`
  ].join('\n');
}

export async function listReminders() {
  ensureSetup();

  let output;
  try {
    output = execSync(`schtasks /query /fo csv /v 2>nul`, { encoding: 'utf8', shell: true });
  } catch {
    return 'No reminders found.';
  }

  const lines = output.split('\n');
  const header = lines[0];
  const cols = header.split('","').map(c => c.replace(/^"|"$/g, '').trim());
  const taskNameIdx = cols.findIndex(c => c === 'TaskName');
  const nextRunIdx = cols.findIndex(c => c.includes('Next Run'));
  const statusIdx = cols.findIndex(c => c === 'Status');

  const reminders = lines
    .slice(1)
    .filter(l => l.includes(TASK_PREFIX))
    .map(line => {
      const parts = line.split('","').map(p => p.replace(/^"|"$/g, '').trim());
      const name = (parts[taskNameIdx] || '').split('\\').pop();
      const nextRun = parts[nextRunIdx] || 'Unknown';
      const status = parts[statusIdx] || 'Unknown';
      return { name, nextRun, status };
    })
    .filter(r => r.name.startsWith(TASK_PREFIX));

  if (reminders.length === 0) return 'No reminders currently scheduled.';

  return reminders
    .map(r => `📅 ${r.name}\n   Next run: ${r.nextRun}\n   Status: ${r.status}`)
    .join('\n\n');
}

export async function cancelReminder(id) {
  // Accept either full name or short ID
  const taskName = id.startsWith(TASK_PREFIX) ? id : `${TASK_PREFIX}-${id}`;
  try {
    execSync(`schtasks /delete /tn "${taskName}" /f`, { stdio: 'pipe', shell: true });
    return `✅ Reminder "${taskName}" has been cancelled.`;
  } catch (err) {
    throw new Error(`Could not cancel reminder "${taskName}". Make sure the ID is correct (use list_reminders to see all).`);
  }
}
