-- RecoverAI Database Schema
-- Run this in Supabase SQL Editor

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- TABLES
-- ============================================

CREATE TABLE doctors (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  specialty TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE caregivers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  phone TEXT,
  auth_user_id UUID UNIQUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE patients (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  age INTEGER,
  phone TEXT,
  pin_hash TEXT, -- hashed 4-digit PIN
  surgery_type TEXT,
  doctor_id UUID REFERENCES doctors(id),
  caregiver_id UUID REFERENCES caregivers(id),
  next_appointment TIMESTAMPTZ,
  recovery_template TEXT,
  streak_score INTEGER DEFAULT 0,
  auth_user_id UUID UNIQUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE check_ins (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  patient_id UUID NOT NULL REFERENCES patients(id),
  timestamp TIMESTAMPTZ DEFAULT NOW(),
  transcript TEXT,
  symptom_json JSONB,
  triage_status TEXT CHECK (triage_status IN ('green', 'yellow', 'red')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE bp_readings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  patient_id UUID NOT NULL REFERENCES patients(id),
  systolic INTEGER NOT NULL,
  diastolic INTEGER NOT NULL,
  photo_ref TEXT,
  timestamp TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE alerts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  patient_id UUID NOT NULL REFERENCES patients(id),
  alert_type TEXT CHECK (alert_type IN ('voice_keyword', 'bp_threshold', 'escalation')),
  trigger_reason TEXT,
  triage_status TEXT CHECK (triage_status IN ('yellow', 'red')),
  caregiver_acknowledged BOOLEAN DEFAULT false,
  timestamp TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE medications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  patient_id UUID NOT NULL REFERENCES patients(id),
  name TEXT NOT NULL,
  schedule_time TEXT NOT NULL
);

CREATE TABLE med_verification_log (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  patient_id UUID NOT NULL REFERENCES patients(id),
  medication_id UUID REFERENCES medications(id),
  verified_at TIMESTAMPTZ DEFAULT NOW(),
  method TEXT CHECK (method IN ('ocr', 'manual'))
);

CREATE TABLE appointments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  patient_id UUID NOT NULL REFERENCES patients(id),
  doctor_id UUID NOT NULL REFERENCES doctors(id),
  scheduled_at TIMESTAMPTZ NOT NULL,
  pre_visit_note TEXT,
  patient_question TEXT
);

-- ============================================
-- INDEXES
-- ============================================

CREATE INDEX idx_check_ins_patient ON check_ins(patient_id, timestamp DESC);
CREATE INDEX idx_check_ins_triage ON check_ins(triage_status);
CREATE INDEX idx_alerts_patient ON alerts(patient_id, timestamp DESC);
CREATE INDEX idx_bp_readings_patient ON bp_readings(patient_id, timestamp DESC);
CREATE INDEX idx_appointments_scheduled ON appointments(scheduled_at);
CREATE INDEX idx_patients_doctor ON patients(doctor_id);

-- ============================================
-- ROW LEVEL SECURITY
-- ============================================

ALTER TABLE patients ENABLE ROW LEVEL SECURITY;
ALTER TABLE check_ins ENABLE ROW LEVEL SECURITY;
ALTER TABLE bp_readings ENABLE ROW LEVEL SECURITY;
ALTER TABLE alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE medications ENABLE ROW LEVEL SECURITY;
ALTER TABLE med_verification_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE appointments ENABLE ROW LEVEL SECURITY;

-- Patients can only see their own data
CREATE POLICY "patients_own_data" ON patients
  FOR ALL USING (auth.uid() = auth_user_id);

-- Check-ins: patient sees own, doctor sees assigned patients
CREATE POLICY "checkins_patient" ON check_ins
  FOR ALL USING (
    patient_id IN (SELECT id FROM patients WHERE auth_user_id = auth.uid())
    OR
    patient_id IN (SELECT id FROM patients WHERE doctor_id IN (SELECT id FROM doctors WHERE email = auth.jwt()->>'email'))
    OR
    patient_id IN (SELECT id FROM patients WHERE caregiver_id IN (SELECT id FROM caregivers WHERE auth_user_id = auth.uid()))
  );

-- BP readings: same access pattern
CREATE POLICY "bp_readings_access" ON bp_readings
  FOR ALL USING (
    patient_id IN (SELECT id FROM patients WHERE auth_user_id = auth.uid())
    OR
    patient_id IN (SELECT id FROM patients WHERE doctor_id IN (SELECT id FROM doctors WHERE email = auth.jwt()->>'email'))
    OR
    patient_id IN (SELECT id FROM patients WHERE caregiver_id IN (SELECT id FROM caregivers WHERE auth_user_id = auth.uid()))
  );

-- Alerts: same access pattern
CREATE POLICY "alerts_access" ON alerts
  FOR ALL USING (
    patient_id IN (SELECT id FROM patients WHERE auth_user_id = auth.uid())
    OR
    patient_id IN (SELECT id FROM patients WHERE doctor_id IN (SELECT id FROM doctors WHERE email = auth.jwt()->>'email'))
    OR
    patient_id IN (SELECT id FROM patients WHERE caregiver_id IN (SELECT id FROM caregivers WHERE auth_user_id = auth.uid()))
  );

-- Medications: same access pattern
CREATE POLICY "medications_access" ON medications
  FOR ALL USING (
    patient_id IN (SELECT id FROM patients WHERE auth_user_id = auth.uid())
    OR
    patient_id IN (SELECT id FROM patients WHERE doctor_id IN (SELECT id FROM doctors WHERE email = auth.jwt()->>'email'))
    OR
    patient_id IN (SELECT id FROM patients WHERE caregiver_id IN (SELECT id FROM caregivers WHERE auth_user_id = auth.uid()))
  );

-- Med verification log: same access pattern
CREATE POLICY "med_verification_access" ON med_verification_log
  FOR ALL USING (
    patient_id IN (SELECT id FROM patients WHERE auth_user_id = auth.uid())
    OR
    patient_id IN (SELECT id FROM patients WHERE doctor_id IN (SELECT id FROM doctors WHERE email = auth.jwt()->>'email'))
    OR
    patient_id IN (SELECT id FROM patients WHERE caregiver_id IN (SELECT id FROM caregivers WHERE auth_user_id = auth.uid()))
  );

-- Appointments: same access pattern
CREATE POLICY "appointments_access" ON appointments
  FOR ALL USING (
    patient_id IN (SELECT id FROM patients WHERE auth_user_id = auth.uid())
    OR
    doctor_id IN (SELECT id FROM doctors WHERE email = auth.jwt()->>'email')
    OR
    patient_id IN (SELECT id FROM patients WHERE caregiver_id IN (SELECT id FROM caregivers WHERE auth_user_id = auth.uid()))
  );
