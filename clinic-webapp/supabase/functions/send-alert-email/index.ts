// supabase/functions/send-alert-email/index.ts
//
// Supabase Edge Function — sends critical-alert emails via Gmail SMTP.
//
// Required secrets (set via `supabase secrets set`):
//   GMAIL_USER          – your Gmail address (e.g. yourname@gmail.com)
//   GMAIL_APP_PASSWORD  – a Google App Password (NOT your regular password)
//
// How to generate a Google App Password:
//   1. Go to https://myaccount.google.com/apppasswords
//   2. Select app: "Mail", device: "Other (Dominican Smart Watch)"
//   3. Copy the 16-character password
//
// Deploy:
//   npm install -g supabase          (one-time)
//   supabase login                   (one-time, opens browser)
//   supabase link --project-ref cnktjnchyyttjvslvdpr
//   supabase functions deploy send-alert-email
//   supabase secrets set GMAIL_USER=you@gmail.com GMAIL_APP_PASSWORD=xxxx-xxxx-xxxx-xxxx

import { SMTPClient } from "https://deno.land/x/denomailer@1.6.0/mod.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const {
      to_email,
      patient_name,
      alert_title,
      alert_value,
      alert_severity,
      alert_time,
    } = await req.json();

    const gmailUser = Deno.env.get("GMAIL_USER");
    const gmailPass = Deno.env.get("GMAIL_APP_PASSWORD");

    if (!gmailUser || !gmailPass) {
      return new Response(
        JSON.stringify({
          success: false,
          error: "Gmail credentials not configured. Set GMAIL_USER and GMAIL_APP_PASSWORD secrets.",
        }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const client = new SMTPClient({
      connection: {
        hostname: "smtp.gmail.com",
        port: 465,
        tls: true,
        auth: {
          username: gmailUser,
          password: gmailPass,
        },
      },
    });

    const htmlBody = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <div style="background: #DC2626; color: white; padding: 20px; border-radius: 8px 8px 0 0;">
          <h1 style="margin: 0; font-size: 22px;">🚨 Critical Alert</h1>
          <p style="margin: 4px 0 0; opacity: 0.9;">Dominican Smart Watch — Health Monitoring</p>
        </div>
        <div style="background: #fff; border: 1px solid #e0e0e0; border-top: none; padding: 24px; border-radius: 0 0 8px 8px;">
          <table style="width: 100%; border-collapse: collapse; font-size: 14px;">
            <tr><td style="padding: 8px 0; color: #757575;">Patient</td><td style="padding: 8px 0; font-weight: bold;">${patient_name}</td></tr>
            <tr><td style="padding: 8px 0; color: #757575;">Alert</td><td style="padding: 8px 0; font-weight: bold;">${alert_title}</td></tr>
            <tr><td style="padding: 8px 0; color: #757575;">Value</td><td style="padding: 8px 0; font-weight: bold; color: #DC2626;">${alert_value}</td></tr>
            <tr><td style="padding: 8px 0; color: #757575;">Severity</td><td style="padding: 8px 0; font-weight: bold; color: #DC2626;">${alert_severity}</td></tr>
            <tr><td style="padding: 8px 0; color: #757575;">Time</td><td style="padding: 8px 0;">${alert_time}</td></tr>
          </table>
          <hr style="margin: 20px 0; border: none; border-top: 1px solid #eee;">
          <p style="font-size: 12px; color: #999; margin: 0;">
            This is an automated alert from the Dominican Smart Watch Health Monitoring System.
            Please review and take appropriate action.
          </p>
        </div>
      </div>
    `;

    await client.send({
      from: gmailUser,
      to: to_email,
      subject: `🚨 Critical Alert: ${alert_title} — ${patient_name}`,
      content: "auto",
      html: htmlBody,
    });

    await client.close();

    return new Response(
      JSON.stringify({ success: true }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Email send error:", error);
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
