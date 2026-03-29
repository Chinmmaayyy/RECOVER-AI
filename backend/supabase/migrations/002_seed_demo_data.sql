-- Seed data for demo: Arthur (patient), Elena (caregiver), Dr. Chen (doctor)

-- Doctor
INSERT INTO doctors (id, name, email, specialty) VALUES
  ('d1000000-0000-0000-0000-000000000aa1', 'Dr. Chen', 'dr.chen@hospital.com', 'Cardiothoracic Surgery');

-- Caregiver
INSERT INTO caregivers (id, name, email, phone) VALUES
  ('c1000000-0000-0000-0000-000000000bb1', 'Elena', 'elena@email.com', '+919876543210');

-- Patient
INSERT INTO patients (id, name, age, phone, surgery_type, doctor_id, caregiver_id, next_appointment, recovery_template, streak_score) VALUES
  ('a1000000-0000-0000-0000-000000000cc1', 'Arthur', 72, '+919876543211', 'Post-CABG',
   'd1000000-0000-0000-0000-000000000aa1', 'c1000000-0000-0000-0000-000000000bb1',
   NOW() + INTERVAL '2 days', 'cardiac_standard', 5);

-- Medications
INSERT INTO medications (patient_id, name, schedule_time) VALUES
  ('a1000000-0000-0000-0000-000000000cc1', 'Aspirin 75mg', '8AM'),
  ('a1000000-0000-0000-0000-000000000cc1', 'Metoprolol 25mg', '8AM'),
  ('a1000000-0000-0000-0000-000000000cc1', 'Atorvastatin 40mg', '8PM');

-- 7 days of historical check-ins
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

-- BP readings
INSERT INTO bp_readings (patient_id, systolic, diastolic, timestamp) VALUES
  ('a1000000-0000-0000-0000-000000000cc1', 128, 82, NOW() - INTERVAL '7 days'),
  ('a1000000-0000-0000-0000-000000000cc1', 135, 88, NOW() - INTERVAL '5 days'),
  ('a1000000-0000-0000-0000-000000000cc1', 130, 85, NOW() - INTERVAL '3 days'),
  ('a1000000-0000-0000-0000-000000000cc1', 125, 80, NOW() - INTERVAL '1 day');

-- Appointment
INSERT INTO appointments (patient_id, doctor_id, scheduled_at) VALUES
  ('a1000000-0000-0000-0000-000000000cc1', 'd1000000-0000-0000-0000-000000000aa1', NOW() + INTERVAL '2 days');
