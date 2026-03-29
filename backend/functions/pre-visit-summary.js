/**
 * Supabase Edge Function: Pre-Visit Summary Generator
 * Runs as a cron job — detects appointments within 24 hours
 * and auto-generates a summary from the patient's recent data.
 *
 * Deploy: supabase functions deploy pre-visit-summary
 * Schedule: every 1 hour via Supabase cron
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const supabase = createClient(
  Deno.env.get('SUPABASE_URL'),
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
);

Deno.serve(async () => {
  try {
    const now = new Date();
    const in24h = new Date(now.getTime() + 24 * 60 * 60 * 1000);

    // Find appointments within next 24 hours that don't have a pre-visit note yet
    const { data: appointments, error: aptError } = await supabase
      .from('appointments')
      .select('*, patient:patients(*)')
      .gte('scheduled_at', now.toISOString())
      .lte('scheduled_at', in24h.toISOString())
      .is('pre_visit_note', null);

    if (aptError) throw aptError;

    for (const apt of appointments || []) {
      const patientId = apt.patient_id;

      // Fetch last 7 days of check-ins
      const { data: checkIns } = await supabase
        .from('check_ins')
        .select()
        .eq('patient_id', patientId)
        .order('timestamp', { ascending: false })
        .limit(7);

      // Fetch last 7 days of BP readings
      const { data: bpReadings } = await supabase
        .from('bp_readings')
        .select()
        .eq('patient_id', patientId)
        .order('timestamp', { ascending: false })
        .limit(7);

      // Fetch medication verification
      const { data: medLogs } = await supabase
        .from('med_verification_log')
        .select('*, medication:medications(name)')
        .eq('patient_id', patientId)
        .order('verified_at', { ascending: false })
        .limit(21); // 7 days * 3 meds

      // Generate summary
      const summary = generateSummary(apt.patient, checkIns || [], bpReadings || [], medLogs || []);

      // Update appointment with pre-visit note
      await supabase
        .from('appointments')
        .update({ pre_visit_note: summary })
        .eq('id', apt.id);
    }

    return new Response(JSON.stringify({ processed: appointments?.length || 0 }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), { status: 500 });
  }
});

function generateSummary(patient, checkIns, bpReadings, medLogs) {
  const lines = [];
  lines.push(`Patient: ${patient.name}, ${patient.age}yo, ${patient.surgery_type}`);
  lines.push('');

  // Triage history
  const statusCounts = { green: 0, yellow: 0, red: 0 };
  checkIns.forEach(ci => {
    if (ci.triage_status) statusCounts[ci.triage_status]++;
  });
  lines.push(`7-Day Status: ${statusCounts.green} Green, ${statusCounts.yellow} Yellow, ${statusCounts.red} Red`);

  // Symptoms mentioned
  const symptoms = checkIns
    .map(ci => ci.symptom_json?.symptom)
    .filter(s => s && s !== 'none');
  if (symptoms.length > 0) {
    lines.push(`Reported symptoms: ${[...new Set(symptoms)].join(', ')}`);
  } else {
    lines.push('No symptoms reported in the last 7 days.');
  }

  // BP trend
  if (bpReadings.length > 0) {
    const latest = bpReadings[0];
    const avg = {
      systolic: Math.round(bpReadings.reduce((s, r) => s + r.systolic, 0) / bpReadings.length),
      diastolic: Math.round(bpReadings.reduce((s, r) => s + r.diastolic, 0) / bpReadings.length),
    };
    lines.push(`Latest BP: ${latest.systolic}/${latest.diastolic} | 7-day avg: ${avg.systolic}/${avg.diastolic}`);
  }

  // Medication adherence
  const totalExpected = checkIns.length * 3; // assume 3 meds/day
  const verified = medLogs.length;
  const adherencePercent = totalExpected > 0 ? Math.round((verified / totalExpected) * 100) : 0;
  lines.push(`Medication adherence: ${adherencePercent}% (${verified}/${totalExpected} doses verified)`);

  lines.push(`Streak score: ${patient.streak_score || 0} consecutive green days`);

  return lines.join('\n');
}
