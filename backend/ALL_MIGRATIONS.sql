-- ============================================
-- RecoverAI: Run this ENTIRE file in Supabase SQL Editor
-- (Dashboard → SQL Editor → New Query → Paste → Run)
-- ============================================

-- MIGRATION 1: Schema
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

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
  pin_hash TEXT,
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

CREATE INDEX idx_check_ins_patient ON check_ins(patient_id, timestamp DESC);
CREATE INDEX idx_check_ins_triage ON check_ins(triage_status);
CREATE INDEX idx_alerts_patient ON alerts(patient_id, timestamp DESC);
CREATE INDEX idx_bp_readings_patient ON bp_readings(patient_id, timestamp DESC);
CREATE INDEX idx_appointments_scheduled ON appointments(scheduled_at);
CREATE INDEX idx_patients_doctor ON patients(doctor_id);

ALTER TABLE patients ENABLE ROW LEVEL SECURITY;
ALTER TABLE check_ins ENABLE ROW LEVEL SECURITY;
ALTER TABLE bp_readings ENABLE ROW LEVEL SECURITY;
ALTER TABLE alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE medications ENABLE ROW LEVEL SECURITY;
ALTER TABLE med_verification_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE appointments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "patients_own_data" ON patients FOR ALL USING (auth.uid() = auth_user_id);
CREATE POLICY "checkins_patient" ON check_ins FOR ALL USING (
  patient_id IN (SELECT id FROM patients WHERE auth_user_id = auth.uid())
  OR patient_id IN (SELECT id FROM patients WHERE doctor_id IN (SELECT id FROM doctors WHERE email = auth.jwt()->>'email'))
  OR patient_id IN (SELECT id FROM patients WHERE caregiver_id IN (SELECT id FROM caregivers WHERE auth_user_id = auth.uid()))
);
CREATE POLICY "bp_readings_access" ON bp_readings FOR ALL USING (
  patient_id IN (SELECT id FROM patients WHERE auth_user_id = auth.uid())
  OR patient_id IN (SELECT id FROM patients WHERE doctor_id IN (SELECT id FROM doctors WHERE email = auth.jwt()->>'email'))
  OR patient_id IN (SELECT id FROM patients WHERE caregiver_id IN (SELECT id FROM caregivers WHERE auth_user_id = auth.uid()))
);
CREATE POLICY "alerts_access" ON alerts FOR ALL USING (
  patient_id IN (SELECT id FROM patients WHERE auth_user_id = auth.uid())
  OR patient_id IN (SELECT id FROM patients WHERE doctor_id IN (SELECT id FROM doctors WHERE email = auth.jwt()->>'email'))
  OR patient_id IN (SELECT id FROM patients WHERE caregiver_id IN (SELECT id FROM caregivers WHERE auth_user_id = auth.uid()))
);
CREATE POLICY "medications_access" ON medications FOR ALL USING (
  patient_id IN (SELECT id FROM patients WHERE auth_user_id = auth.uid())
  OR patient_id IN (SELECT id FROM patients WHERE doctor_id IN (SELECT id FROM doctors WHERE email = auth.jwt()->>'email'))
  OR patient_id IN (SELECT id FROM patients WHERE caregiver_id IN (SELECT id FROM caregivers WHERE auth_user_id = auth.uid()))
);
CREATE POLICY "med_verification_access" ON med_verification_log FOR ALL USING (
  patient_id IN (SELECT id FROM patients WHERE auth_user_id = auth.uid())
  OR patient_id IN (SELECT id FROM patients WHERE doctor_id IN (SELECT id FROM doctors WHERE email = auth.jwt()->>'email'))
  OR patient_id IN (SELECT id FROM patients WHERE caregiver_id IN (SELECT id FROM caregivers WHERE auth_user_id = auth.uid()))
);
CREATE POLICY "appointments_access" ON appointments FOR ALL USING (
  patient_id IN (SELECT id FROM patients WHERE auth_user_id = auth.uid())
  OR doctor_id IN (SELECT id FROM doctors WHERE email = auth.jwt()->>'email')
  OR patient_id IN (SELECT id FROM patients WHERE caregiver_id IN (SELECT id FROM caregivers WHERE auth_user_id = auth.uid()))
);

-- MIGRATION 2: Seed Demo Data
INSERT INTO doctors (id, name, email, specialty) VALUES
  ('d1000000-0000-0000-0000-000000000aa1', 'Dr. Chen', 'dr.chen@hospital.com', 'Cardiothoracic Surgery');

INSERT INTO caregivers (id, name, email, phone) VALUES
  ('c1000000-0000-0000-0000-000000000bb1', 'Elena', 'elena@email.com', '+919876543210');

INSERT INTO patients (id, name, age, phone, surgery_type, doctor_id, caregiver_id, next_appointment, recovery_template, streak_score) VALUES
  ('a1000000-0000-0000-0000-000000000cc1', 'Arthur', 72, '+919876543211', 'Post-CABG',
   'd1000000-0000-0000-0000-000000000aa1', 'c1000000-0000-0000-0000-000000000bb1',
   NOW() + INTERVAL '2 days', 'cardiac_standard', 5);

INSERT INTO medications (patient_id, name, schedule_time) VALUES
  ('a1000000-0000-0000-0000-000000000cc1', 'Aspirin 75mg', '8AM'),
  ('a1000000-0000-0000-0000-000000000cc1', 'Metoprolol 25mg', '8AM'),
  ('a1000000-0000-0000-0000-000000000cc1', 'Atorvastatin 40mg', '8PM');

INSERT INTO check_ins (patient_id, timestamp, transcript, symptom_json, triage_status) VALUES
  ('a1000000-0000-0000-0000-000000000cc1', NOW() - INTERVAL '7 days',
   'I feel okay today, just a little tired from the walk.',
   '{"symptom": "tired", "severity": "low", "mood": "okay", "medications_taken": true}', 'green'),
  ('a1000000-0000-0000-0000-000000000cc1', NOW() - INTERVAL '6 days',
   'Good morning, feeling much better. Took all my medicines.',
   '{"symptom": "none", "severity": "none", "mood": "good", "medications_taken": true}', 'green'),
  ('a1000000-0000-0000-0000-000000000cc1', NOW() - INTERVAL '5 days',
   'I have some mild pain near the incision area.',
   '{"symptom": "mild pain", "severity": "medium", "mood": "okay", "medications_taken": true}', 'yellow'),
  ('a1000000-0000-0000-0000-000000000cc1', NOW() - INTERVAL '4 days',
   'The pain is still there, a bit sore around the chest.',
   '{"symptom": "sore", "severity": "medium", "mood": "low", "medications_taken": true}', 'yellow'),
  ('a1000000-0000-0000-0000-000000000cc1', NOW() - INTERVAL '3 days',
   'Feeling better today. Pain is reducing. Ate well.',
   '{"symptom": "mild pain", "severity": "low", "mood": "good", "medications_taken": true}', 'yellow'),
  ('a1000000-0000-0000-0000-000000000cc1', NOW() - INTERVAL '2 days',
   'I am doing well. Walked around the garden today.',
   '{"symptom": "none", "severity": "none", "mood": "good", "medications_taken": true}', 'green'),
  ('a1000000-0000-0000-0000-000000000cc1', NOW() - INTERVAL '1 day',
   'Feeling fine. Took aspirin and metoprolol in the morning.',
   '{"symptom": "none", "severity": "none", "mood": "good", "medications_taken": true}', 'green');

INSERT INTO bp_readings (patient_id, systolic, diastolic, timestamp) VALUES
  ('a1000000-0000-0000-0000-000000000cc1', 128, 82, NOW() - INTERVAL '7 days'),
  ('a1000000-0000-0000-0000-000000000cc1', 135, 88, NOW() - INTERVAL '5 days'),
  ('a1000000-0000-0000-0000-000000000cc1', 130, 85, NOW() - INTERVAL '3 days'),
  ('a1000000-0000-0000-0000-000000000cc1', 125, 80, NOW() - INTERVAL '1 day');

INSERT INTO appointments (patient_id, doctor_id, scheduled_at) VALUES
  ('a1000000-0000-0000-0000-000000000cc1', 'd1000000-0000-0000-0000-000000000aa1', NOW() + INTERVAL '2 days');

-- MIGRATION 3: Streak Functions
CREATE OR REPLACE FUNCTION increment_streak(patient_id_input UUID)
RETURNS void AS $$
BEGIN
  UPDATE patients SET streak_score = streak_score + 1 WHERE id = patient_id_input;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION reset_streak(patient_id_input UUID)
RETURNS void AS $$
BEGIN
  UPDATE patients SET streak_score = 0 WHERE id = patient_id_input;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION auto_manage_streak()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.triage_status = 'green' THEN
    PERFORM increment_streak(NEW.patient_id);
  ELSE
    PERFORM reset_streak(NEW.patient_id);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER checkin_streak_trigger
AFTER INSERT ON check_ins
FOR EACH ROW
EXECUTE FUNCTION auto_manage_streak();
