import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.REACT_APP_SUPABASE_URL || 'https://fqjriojizqnevfojirss.supabase.co';
const supabaseAnonKey = process.env.REACT_APP_SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZxanJpb2ppenFuZXZmb2ppcnNzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ3OTc4MTQsImV4cCI6MjA5MDM3MzgxNH0.6mg6oFQb0IQaU9x23ZJVxfZM0c8r0L9FZiVPvGw5E1A';

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

// ---- Doctor Dashboard Queries ----

export async function getDoctorPatients(doctorId) {
  const { data, error } = await supabase
    .from('patients')
    .select(`
      *,
      check_ins ( id, timestamp, transcript, symptom_json, triage_status ),
      bp_readings ( id, systolic, diastolic, timestamp ),
      alerts ( id, alert_type, trigger_reason, triage_status, caregiver_acknowledged, timestamp ),
      medications ( id, name, schedule_time )
    `)
    .eq('doctor_id', doctorId)
    .order('created_at');

  if (error) throw error;
  return data || [];
}

export async function getPatientCheckIns(patientId, limit = 7) {
  const { data, error } = await supabase
    .from('check_ins')
    .select()
    .eq('patient_id', patientId)
    .order('timestamp', { ascending: false })
    .limit(limit);

  if (error) throw error;
  return data || [];
}

export async function getPatientBPReadings(patientId, limit = 7) {
  const { data, error } = await supabase
    .from('bp_readings')
    .select()
    .eq('patient_id', patientId)
    .order('timestamp', { ascending: false })
    .limit(limit);

  if (error) throw error;
  return data || [];
}

export async function getRedAlerts(doctorId) {
  const { data, error } = await supabase
    .from('alerts')
    .select(`*, patient:patients(name, surgery_type)`)
    .eq('triage_status', 'red')
    .order('timestamp', { ascending: false });

  if (error) throw error;
  return data || [];
}

export async function getUpcomingAppointments(doctorId) {
  const { data, error } = await supabase
    .from('appointments')
    .select(`*, patient:patients(name, surgery_type)`)
    .eq('doctor_id', doctorId)
    .gte('scheduled_at', new Date().toISOString())
    .order('scheduled_at');

  if (error) throw error;
  return data || [];
}

// ---- Prescriptions ----

export async function getPatientPrescriptions(patientId) {
  const { data, error } = await supabase
    .from('prescriptions')
    .select()
    .eq('patient_id', patientId)
    .order('created_at', { ascending: false });

  if (error) {
    // Table may not exist yet — return empty
    console.warn('Prescriptions table not found, using empty:', error.message);
    return [];
  }
  return data || [];
}

export async function addPrescription({ patientId, doctorId, medication, dosage, frequency, duration, notes }) {
  const { data, error } = await supabase
    .from('prescriptions')
    .insert({
      patient_id: patientId,
      doctor_id: doctorId,
      medication,
      dosage,
      frequency,
      duration,
      notes,
    })
    .select()
    .single();

  if (error) throw error;
  return data;
}

// ---- Doctor Notes ----

export async function getDoctorNotes(patientId) {
  const { data, error } = await supabase
    .from('doctor_notes')
    .select()
    .eq('patient_id', patientId)
    .order('created_at', { ascending: false });

  if (error) {
    console.warn('Doctor notes table not found:', error.message);
    return [];
  }
  return data || [];
}

export async function addDoctorNote({ patientId, doctorId, note, noteType }) {
  const { data, error } = await supabase
    .from('doctor_notes')
    .insert({
      patient_id: patientId,
      doctor_id: doctorId,
      note,
      note_type: noteType,
    })
    .select()
    .single();

  if (error) throw error;
  return data;
}

// Real-time subscription for check-ins
export function subscribeToCheckIns(callback) {
  return supabase
    .channel('dashboard_check_ins')
    .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'check_ins' }, callback)
    .subscribe();
}

// Real-time subscription for alerts
export function subscribeToAlerts(callback) {
  return supabase
    .channel('dashboard_alerts')
    .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'alerts' }, callback)
    .subscribe();
}
