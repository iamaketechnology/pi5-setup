// Smart Email Helper - Auto-detects configured email provider
// Usage: import { sendEmail } from "../_shared/email-helper.ts"

interface EmailOptions {
  to: string | string[];
  subject: string;
  html?: string;
  text?: string;
  from?: string;
  replyTo?: string;
}

interface EmailResult {
  success: boolean;
  id?: string;
  provider?: string;
  error?: string;
}

// Auto-detect which provider is configured
function detectProvider(): { provider: string; apiKey: string; fromEmail: string; domain?: string; region?: string } | null {
  // Check Resend
  const resendKey = Deno.env.get("RESEND_API_KEY");
  if (resendKey) {
    return {
      provider: "resend",
      apiKey: resendKey,
      fromEmail: Deno.env.get("RESEND_FROM_EMAIL") || "noreply@resend.dev",
      domain: Deno.env.get("RESEND_DOMAIN"),
    };
  }

  // Check SendGrid
  const sendgridKey = Deno.env.get("SENDGRID_API_KEY");
  if (sendgridKey) {
    return {
      provider: "sendgrid",
      apiKey: sendgridKey,
      fromEmail: Deno.env.get("SENDGRID_FROM_EMAIL") || "noreply@example.com",
      domain: Deno.env.get("SENDGRID_DOMAIN"),
    };
  }

  // Check Mailgun
  const mailgunKey = Deno.env.get("MAILGUN_API_KEY");
  if (mailgunKey) {
    return {
      provider: "mailgun",
      apiKey: mailgunKey,
      fromEmail: Deno.env.get("MAILGUN_FROM_EMAIL") || "noreply@example.com",
      domain: Deno.env.get("MAILGUN_DOMAIN"),
      region: Deno.env.get("MAILGUN_REGION") || "us",
    };
  }

  return null;
}

// Send email via Resend
async function sendViaResend(config: any, options: EmailOptions): Promise<EmailResult> {
  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${config.apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: options.from || config.fromEmail,
      to: Array.isArray(options.to) ? options.to : [options.to],
      subject: options.subject,
      html: options.html,
      text: options.text,
      reply_to: options.replyTo,
    }),
  });

  const data = await response.json();

  if (!response.ok) {
    return { success: false, error: `Resend API error: ${JSON.stringify(data)}` };
  }

  return { success: true, id: data.id, provider: "resend" };
}

// Send email via SendGrid
async function sendViaSendGrid(config: any, options: EmailOptions): Promise<EmailResult> {
  const recipients = Array.isArray(options.to) ? options.to : [options.to];

  const response = await fetch("https://api.sendgrid.com/v3/mail/send", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${config.apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      personalizations: [{
        to: recipients.map((email) => ({ email })),
      }],
      from: { email: options.from || config.fromEmail },
      reply_to: options.replyTo ? { email: options.replyTo } : undefined,
      subject: options.subject,
      content: [
        options.html
          ? { type: "text/html", value: options.html }
          : { type: "text/plain", value: options.text || "" },
      ],
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    return { success: false, error: `SendGrid API error: ${errorText}` };
  }

  return { success: true, provider: "sendgrid" };
}

// Send email via Mailgun
async function sendViaMailgun(config: any, options: EmailOptions): Promise<EmailResult> {
  const apiBase = config.region === "eu"
    ? "https://api.eu.mailgun.net/v3"
    : "https://api.mailgun.net/v3";

  const recipients = Array.isArray(options.to) ? options.to.join(",") : options.to;

  const formData = new FormData();
  formData.append("from", options.from || config.fromEmail);
  formData.append("to", recipients);
  formData.append("subject", options.subject);
  if (options.html) formData.append("html", options.html);
  if (options.text) formData.append("text", options.text);
  if (options.replyTo) formData.append("h:Reply-To", options.replyTo);

  const response = await fetch(`${apiBase}/${config.domain}/messages`, {
    method: "POST",
    headers: {
      "Authorization": `Basic ${btoa(`api:${config.apiKey}`)}`,
    },
    body: formData,
  });

  const data = await response.json();

  if (!response.ok) {
    return { success: false, error: `Mailgun API error: ${JSON.stringify(data)}` };
  }

  return { success: true, id: data.id, provider: "mailgun" };
}

// Main sendEmail function - auto-detects provider and sends
export async function sendEmail(options: EmailOptions): Promise<EmailResult> {
  // Validate required fields
  if (!options.to || !options.subject || (!options.html && !options.text)) {
    return { success: false, error: "Missing required fields: to, subject, and html or text" };
  }

  // Auto-detect provider
  const config = detectProvider();

  if (!config) {
    return {
      success: false,
      error: "No email provider configured. Please run email-provider-setup.sh",
    };
  }

  console.log(`Sending email via ${config.provider}...`);

  try {
    switch (config.provider) {
      case "resend":
        return await sendViaResend(config, options);
      case "sendgrid":
        return await sendViaSendGrid(config, options);
      case "mailgun":
        return await sendViaMailgun(config, options);
      default:
        return { success: false, error: `Unknown provider: ${config.provider}` };
    }
  } catch (error) {
    return { success: false, error: error.message };
  }
}

// Helper to get currently configured provider info
export function getProviderInfo(): { provider: string; fromEmail: string } | null {
  const config = detectProvider();
  if (!config) return null;

  return {
    provider: config.provider,
    fromEmail: config.fromEmail,
  };
}
