import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { CallToolRequestSchema, ListToolsRequestSchema } from '@modelcontextprotocol/sdk/types.js';
import { scheduleReminder, listReminders, cancelReminder } from './scheduler.js';

const server = new Server(
  { name: 'cron-mcp', version: '1.0.0' },
  { capabilities: { tools: {} } }
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: 'schedule_reminder',
      description: 'Schedule a Windows desktop reminder notification. Supports one-time and recurring reminders. Natural language dates work: "tomorrow at 9am", "Monday 2pm", "next Friday at 3:30pm".',
      inputSchema: {
        type: 'object',
        properties: {
          message: {
            type: 'string',
            description: 'The reminder message to display in the notification'
          },
          datetime: {
            type: 'string',
            description: 'When to show the reminder. Natural language supported: "tomorrow 9am", "Monday 2pm", "in 30 minutes", "March 15 at 10am", "2026-03-10 14:30"'
          },
          recurrence: {
            type: 'string',
            enum: ['once', 'daily', 'weekly', 'weekdays'],
            description: 'How often to repeat. "once" (default), "daily", "weekly" (same day each week), "weekdays" (Mon-Fri)'
          },
          title: {
            type: 'string',
            description: 'Optional title for the notification popup (default: "Reminder")'
          }
        },
        required: ['message', 'datetime']
      }
    },
    {
      name: 'list_reminders',
      description: 'List all currently scheduled reminders with their IDs, next run time, and status.',
      inputSchema: {
        type: 'object',
        properties: {}
      }
    },
    {
      name: 'cancel_reminder',
      description: 'Cancel a scheduled reminder by its ID. Get the ID from list_reminders.',
      inputSchema: {
        type: 'object',
        properties: {
          id: {
            type: 'string',
            description: 'The reminder ID (e.g. "CRONMCP-A1B2C3D4") from list_reminders'
          }
        },
        required: ['id']
      }
    }
  ]
}));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    let result;
    if (name === 'schedule_reminder') {
      result = await scheduleReminder(args);
    } else if (name === 'list_reminders') {
      result = await listReminders();
    } else if (name === 'cancel_reminder') {
      result = await cancelReminder(args.id);
    } else {
      throw new Error(`Unknown tool: ${name}`);
    }
    return { content: [{ type: 'text', text: result }] };
  } catch (err) {
    return {
      content: [{ type: 'text', text: `❌ Error: ${err.message}` }],
      isError: true
    };
  }
});

const transport = new StdioServerTransport();
await server.connect(transport);
