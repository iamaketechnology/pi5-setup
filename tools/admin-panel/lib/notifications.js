// =============================================================================
// PI5 Control Center - Notifications Module
// =============================================================================
// Send notifications via webhooks (Discord, Slack) and Telegram
// Version: 3.0.0
// =============================================================================

const axios = require('axios');

let config = null;

// =============================================================================
// Initialize Notifications
// =============================================================================

function initNotifications(appConfig) {
  config = appConfig.notifications || {};

  if (!config.enabled) {
    console.log('📢 Notifications disabled');
    return;
  }

  console.log('📢 Notifications enabled');

  // Validate webhooks
  const webhookCount = (config.webhooks || []).length;
  if (webhookCount > 0) {
    console.log(`  • ${webhookCount} webhook(s) configured`);
  }

  // Validate Telegram
  if (config.telegram?.enabled) {
    console.log(`  • Telegram bot configured`);
  }
}

// =============================================================================
// Send Notification
// =============================================================================

async function sendNotification(event, data) {
  if (!config || !config.enabled) return;

  // Send to all webhooks that match the event
  for (const webhook of config.webhooks || []) {
    if (webhook.events.includes(event) || webhook.events.includes('*')) {
      await sendWebhook(webhook, event, data).catch(err => {
        console.error(`Failed to send webhook to ${webhook.name}:`, err.message);
      });
    }
  }

  // Send to Telegram if enabled
  if (config.telegram?.enabled) {
    await sendTelegram(event, data).catch(err => {
      console.error('Failed to send Telegram notification:', err.message);
    });
  }
}

// =============================================================================
// Send Webhook (Discord/Slack format)
// =============================================================================

async function sendWebhook(webhook, event, data) {
  const payload = formatWebhookPayload(event, data);

  await axios.post(webhook.url, payload, {
    headers: { 'Content-Type': 'application/json' },
    timeout: 5000
  });

  console.log(`📢 Webhook sent to ${webhook.name}: ${event}`);
}

function formatWebhookPayload(event, data) {
  const colors = {
    'execution.success': 0x10b981, // green
    'execution.failed': 0xef4444,  // red
    'system.critical': 0xf59e0b,   // orange
    'task.scheduled': 0x3b82f6     // blue
  };

  const color = colors[event] || 0x6b7280;

  // Discord-compatible format
  return {
    embeds: [{
      title: getEventTitle(event),
      description: getEventDescription(event, data),
      color: color,
      fields: getEventFields(event, data),
      timestamp: new Date().toISOString(),
      footer: {
        text: 'PI5 Control Center'
      }
    }]
  };
}

function getEventTitle(event) {
  const titles = {
    'execution.success': '✅ Script Execution Successful',
    'execution.failed': '❌ Script Execution Failed',
    'system.critical': '⚠️ Critical System Alert',
    'task.scheduled': '📅 Task Scheduled'
  };

  return titles[event] || '📢 Notification';
}

function getEventDescription(event, data) {
  switch (event) {
    case 'execution.success':
      return `Script **${data.script}** executed successfully on **${data.pi}**`;

    case 'execution.failed':
      return `Script **${data.script}** failed on **${data.pi}**\n\`\`\`\n${data.error || 'Unknown error'}\n\`\`\``;

    case 'system.critical':
      return `Critical alert on **${data.pi}**: ${data.message}`;

    case 'task.scheduled':
      return `Task **${data.task}** scheduled: ${data.schedule}`;

    default:
      return JSON.stringify(data, null, 2);
  }
}

function getEventFields(event, data) {
  const fields = [];

  if (data.pi) {
    fields.push({ name: 'Pi', value: data.pi, inline: true });
  }

  if (data.duration) {
    fields.push({ name: 'Duration', value: `${(data.duration / 1000).toFixed(2)}s`, inline: true });
  }

  if (data.exitCode !== undefined) {
    fields.push({ name: 'Exit Code', value: String(data.exitCode), inline: true });
  }

  return fields;
}

// =============================================================================
// Send Telegram Notification
// =============================================================================

async function sendTelegram(event, data) {
  const botToken = config.telegram.botToken;
  const chatId = config.telegram.chatId;

  const message = formatTelegramMessage(event, data);

  await axios.post(`https://api.telegram.org/bot${botToken}/sendMessage`, {
    chat_id: chatId,
    text: message,
    parse_mode: 'Markdown'
  }, {
    timeout: 5000
  });

  console.log(`📢 Telegram sent: ${event}`);
}

function formatTelegramMessage(event, data) {
  const emoji = {
    'execution.success': '✅',
    'execution.failed': '❌',
    'system.critical': '⚠️',
    'task.scheduled': '📅'
  }[event] || '📢';

  let message = `${emoji} *${getEventTitle(event)}*\n\n`;
  message += getEventDescription(event, data);

  if (data.pi) {
    message += `\n\n📍 Pi: \`${data.pi}\``;
  }

  if (data.duration) {
    message += `\n⏱ Duration: ${(data.duration / 1000).toFixed(2)}s`;
  }

  return message;
}

// =============================================================================
// Test Notifications
// =============================================================================

async function testNotification() {
  await sendNotification('execution.success', {
    script: 'test-script.sh',
    pi: 'pi-test',
    duration: 5000,
    exitCode: 0
  });

  return { success: true, message: 'Test notification sent' };
}

// =============================================================================
// Export Functions
// =============================================================================

module.exports = {
  initNotifications,
  sendNotification,
  testNotification
};
