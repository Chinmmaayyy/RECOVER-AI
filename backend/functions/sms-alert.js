/**
 * Supabase Edge Function: SMS Alert via Twilio
 * Triggered when a Red Alert is created.
 *
 * Deploy: supabase functions deploy sms-alert
 * Trigger: Database webhook on alerts table INSERT where triage_status = 'red'
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const supabase = createClient(
  Deno.env.get('SUPABASE_URL'),
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
);

const TWILIO_ACCOUNT_SID = Deno.env.get('TWILIO_ACCOUNT_SID');
const TWILIO_AUTH_TOKEN = Deno.env.get('TWILIO_AUTH_TOKEN');
const TWILIO_PHONE = Deno.env.get('TWILIO_PHONE_NUMBER');

Deno.serve(async (req) => {
  try {
    const { record } = await req.json();

    if (!record || record.triage_status !== 'red') {
      return new Response(JSON.stringify({ skipped: true }), { status: 200 });
    }

    // Get patient and caregiver info
    const { data: patient } = await supabase
      .from('patients')
      .select('name, caregiver:caregivers(phone, name)')
      .eq('id', record.patient_id)
      .single();

    if (!patient?.caregiver?.phone) {
      return new Response(JSON.stringify({ error: 'No caregiver phone found' }), { status: 200 });
    }

    const message = `URGENT: ${patient.name}'s RecoverAI app has flagged a critical symptom: ${record.trigger_reason}. Please check in immediately.`;

    // Send SMS via Twilio
    const twilioUrl = `https://api.twilio.com/2010-04-01/Accounts/${TWILIO_ACCOUNT_SID}/Messages.json`;
    const authHeader = 'Basic ' + btoa(`${TWILIO_ACCOUNT_SID}:${TWILIO_AUTH_TOKEN}`);

    const response = await fetch(twilioUrl, {
      method: 'POST',
      headers: {
        'Authorization': authHeader,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        To: patient.caregiver.phone,
        From: TWILIO_PHONE,
        Body: message,
      }),
    });

    const result = await response.json();

    return new Response(JSON.stringify({ sent: true, sid: result.sid }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), { status: 500 });
  }
});
