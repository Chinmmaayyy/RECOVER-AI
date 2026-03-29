-- ============================================
-- RecoverAI: Additional Patients & Caregivers
-- Run in Supabase SQL Editor
-- ============================================

-- More Caregivers
INSERT INTO caregivers (id, name, email, phone) VALUES
  ('c2000000-0000-0000-0000-000000000bb2', 'Priya Sharma', 'priya.sharma@gmail.com', '+919812345678'),
  ('c3000000-0000-0000-0000-000000000bb3', 'Rahul Verma', 'rahul.verma@gmail.com', '+919823456789'),
  ('c4000000-0000-0000-0000-000000000bb4', 'Anita Desai', 'anita.desai@gmail.com', '+919834567890'),
  ('c5000000-0000-0000-0000-000000000bb5', 'Vikram Patel', 'vikram.patel@gmail.com', '+919845678901');

-- Patient 2: Meera — Post knee replacement, Yellow status (recurring mild pain)
INSERT INTO patients (id, name, age, phone, surgery_type, doctor_id, caregiver_id, next_appointment, recovery_template, streak_score) VALUES
  ('a2000000-0000-0000-0000-000000000cc2', 'Meera Iyer', 68, '+919901234567', 'Post-Knee Replacement',
   'd1000000-0000-0000-0000-000000000aa1', 'c2000000-0000-0000-0000-000000000bb2',
   NOW() + INTERVAL '5 days', 'orthopedic_standard', 2);

INSERT INTO medications (patient_id, name, schedule_time) VALUES
  ('a2000000-0000-0000-0000-000000000cc2', 'Paracetamol 500mg', '8AM'),
  ('a2000000-0000-0000-0000-000000000cc2', 'Clopidogrel 75mg', '8AM'),
  ('a2000000-0000-0000-0000-000000000cc2', 'Calcium + Vitamin D', '8PM');

INSERT INTO check_ins (patient_id, timestamp, transcript, symptom_json, triage_status) VALUES
  ('a2000000-0000-0000-0000-000000000cc2', NOW() - INTERVAL '7 days',
   'I am doing fine. The knee is stiff but manageable.',
   '{"symptom": "none", "severity": "none", "mood": "okay", "medications_taken": true}', 'green'),
  ('a2000000-0000-0000-0000-000000000cc2', NOW() - INTERVAL '6 days',
   'Mild pain in the knee when I try to bend it.',
   '{"symptom": "mild pain", "severity": "medium", "mood": "okay", "medications_taken": true}', 'yellow'),
  ('a2000000-0000-0000-0000-000000000cc2', NOW() - INTERVAL '5 days',
   'Pain is still there. Took my medicines on time.',
   '{"symptom": "mild pain", "severity": "medium", "mood": "low", "medications_taken": true}', 'yellow'),
  ('a2000000-0000-0000-0000-000000000cc2', NOW() - INTERVAL '4 days',
   'Feeling sore around the knee. Could not sleep well.',
   '{"symptom": "sore", "severity": "medium", "mood": "low", "medications_taken": true}', 'yellow'),
  ('a2000000-0000-0000-0000-000000000cc2', NOW() - INTERVAL '3 days',
   'Better today. Did some physiotherapy exercises.',
   '{"symptom": "mild discomfort", "severity": "low", "mood": "good", "medications_taken": true}', 'yellow'),
  ('a2000000-0000-0000-0000-000000000cc2', NOW() - INTERVAL '2 days',
   'Knee feels better. I forgot to take my evening calcium tablet.',
   '{"symptom": "none", "severity": "none", "mood": "okay", "medications_taken": false}', 'yellow'),
  ('a2000000-0000-0000-0000-000000000cc2', NOW() - INTERVAL '1 day',
   'Mild pain returned today. Took all medicines.',
   '{"symptom": "mild pain", "severity": "medium", "mood": "low", "medications_taken": true}', 'yellow');

INSERT INTO bp_readings (patient_id, systolic, diastolic, timestamp) VALUES
  ('a2000000-0000-0000-0000-000000000cc2', 138, 85, NOW() - INTERVAL '6 days'),
  ('a2000000-0000-0000-0000-000000000cc2', 142, 88, NOW() - INTERVAL '4 days'),
  ('a2000000-0000-0000-0000-000000000cc2', 136, 84, NOW() - INTERVAL '2 days'),
  ('a2000000-0000-0000-0000-000000000cc2', 140, 86, NOW() - INTERVAL '1 day');

INSERT INTO appointments (patient_id, doctor_id, scheduled_at) VALUES
  ('a2000000-0000-0000-0000-000000000cc2', 'd1000000-0000-0000-0000-000000000aa1', NOW() + INTERVAL '5 days');

-- Patient 3: Rajesh — Post-CABG, RED status (chest tightness + high BP)
INSERT INTO patients (id, name, age, phone, surgery_type, doctor_id, caregiver_id, next_appointment, recovery_template, streak_score) VALUES
  ('a3000000-0000-0000-0000-000000000cc3', 'Rajesh Kumar', 65, '+919912345678', 'Post-CABG',
   'd1000000-0000-0000-0000-000000000aa1', 'c3000000-0000-0000-0000-000000000bb3',
   NOW() + INTERVAL '1 day', 'cardiac_standard', 0);

INSERT INTO medications (patient_id, name, schedule_time) VALUES
  ('a3000000-0000-0000-0000-000000000cc3', 'Aspirin 150mg', '8AM'),
  ('a3000000-0000-0000-0000-000000000cc3', 'Atenolol 50mg', '8AM'),
  ('a3000000-0000-0000-0000-000000000cc3', 'Rosuvastatin 20mg', '8PM'),
  ('a3000000-0000-0000-0000-000000000cc3', 'Ramipril 5mg', '8AM');

INSERT INTO check_ins (patient_id, timestamp, transcript, symptom_json, triage_status) VALUES
  ('a3000000-0000-0000-0000-000000000cc3', NOW() - INTERVAL '7 days',
   'Feeling okay. A little tired but nothing serious.',
   '{"symptom": "tired", "severity": "low", "mood": "okay", "medications_taken": true}', 'green'),
  ('a3000000-0000-0000-0000-000000000cc3', NOW() - INTERVAL '6 days',
   'Good day. Walked in the park for 10 minutes.',
   '{"symptom": "none", "severity": "none", "mood": "good", "medications_taken": true}', 'green'),
  ('a3000000-0000-0000-0000-000000000cc3', NOW() - INTERVAL '5 days',
   'I felt a bit dizzy after climbing stairs today.',
   '{"symptom": "dizzy", "severity": "high", "mood": "low", "medications_taken": true}', 'red'),
  ('a3000000-0000-0000-0000-000000000cc3', NOW() - INTERVAL '4 days',
   'Feeling better. No dizziness. Took all medicines.',
   '{"symptom": "none", "severity": "none", "mood": "okay", "medications_taken": true}', 'green'),
  ('a3000000-0000-0000-0000-000000000cc3', NOW() - INTERVAL '3 days',
   'Some nausea in the morning. Did not eat much.',
   '{"symptom": "nausea", "severity": "medium", "mood": "low", "medications_taken": true}', 'yellow'),
  ('a3000000-0000-0000-0000-000000000cc3', NOW() - INTERVAL '2 days',
   'I missed my morning medicines. Feeling a bit weak.',
   '{"symptom": "tired", "severity": "low", "mood": "low", "medications_taken": false}', 'yellow'),
  ('a3000000-0000-0000-0000-000000000cc3', NOW() - INTERVAL '1 day',
   'My chest feels tight and I am short of breath. Very uncomfortable.',
   '{"symptom": "chest tight", "severity": "high", "mood": "distressed", "medications_taken": true}', 'red');

INSERT INTO bp_readings (patient_id, systolic, diastolic, timestamp) VALUES
  ('a3000000-0000-0000-0000-000000000cc3', 132, 84, NOW() - INTERVAL '7 days'),
  ('a3000000-0000-0000-0000-000000000cc3', 145, 92, NOW() - INTERVAL '5 days'),
  ('a3000000-0000-0000-0000-000000000cc3', 138, 86, NOW() - INTERVAL '3 days'),
  ('a3000000-0000-0000-0000-000000000cc3', 162, 98, NOW() - INTERVAL '1 day');

INSERT INTO alerts (patient_id, alert_type, trigger_reason, triage_status, caregiver_acknowledged, timestamp) VALUES
  ('a3000000-0000-0000-0000-000000000cc3', 'voice_keyword', 'Red keyword detected: "dizzy"', 'red', true, NOW() - INTERVAL '5 days'),
  ('a3000000-0000-0000-0000-000000000cc3', 'voice_keyword', 'Red keyword detected: "chest tight"', 'red', false, NOW() - INTERVAL '1 day'),
  ('a3000000-0000-0000-0000-000000000cc3', 'bp_threshold', 'Systolic BP 162 > 150', 'red', false, NOW() - INTERVAL '1 day');

INSERT INTO appointments (patient_id, doctor_id, scheduled_at, pre_visit_note) VALUES
  ('a3000000-0000-0000-0000-000000000cc3', 'd1000000-0000-0000-0000-000000000aa1', NOW() + INTERVAL '1 day',
   'Patient: Rajesh Kumar, 65yo, Post-CABG
7-Day Status: 2 Green, 2 Yellow, 2 Red
Reported symptoms: dizzy, nausea, tired, chest tight
Latest BP: 162/98 | 7-day avg: 144/90
Medication adherence: 83% (5/6 doses verified)
Streak score: 0 consecutive green days

CRITICAL: Chest tightness + BP 162/98 reported yesterday. Urgent review recommended.');

-- Patient 4: Sunita — Post hip replacement, stable Green
INSERT INTO patients (id, name, age, phone, surgery_type, doctor_id, caregiver_id, next_appointment, recovery_template, streak_score) VALUES
  ('a4000000-0000-0000-0000-000000000cc4', 'Sunita Devi', 70, '+919923456789', 'Post-Hip Replacement',
   'd1000000-0000-0000-0000-000000000aa1', 'c4000000-0000-0000-0000-000000000bb4',
   NOW() + INTERVAL '10 days', 'orthopedic_standard', 7);

INSERT INTO medications (patient_id, name, schedule_time) VALUES
  ('a4000000-0000-0000-0000-000000000cc4', 'Paracetamol 650mg', '8AM'),
  ('a4000000-0000-0000-0000-000000000cc4', 'Iron Supplement', '1PM'),
  ('a4000000-0000-0000-0000-000000000cc4', 'Calcium 500mg', '8PM');

INSERT INTO check_ins (patient_id, timestamp, transcript, symptom_json, triage_status) VALUES
  ('a4000000-0000-0000-0000-000000000cc4', NOW() - INTERVAL '7 days',
   'I am feeling good. Did my exercises today.',
   '{"symptom": "none", "severity": "none", "mood": "good", "medications_taken": true}', 'green'),
  ('a4000000-0000-0000-0000-000000000cc4', NOW() - INTERVAL '6 days',
   'Everything is fine. My daughter helped me walk today.',
   '{"symptom": "none", "severity": "none", "mood": "good", "medications_taken": true}', 'green'),
  ('a4000000-0000-0000-0000-000000000cc4', NOW() - INTERVAL '5 days',
   'Good morning. Feeling strong today. Took all tablets.',
   '{"symptom": "none", "severity": "none", "mood": "good", "medications_taken": true}', 'green'),
  ('a4000000-0000-0000-0000-000000000cc4', NOW() - INTERVAL '4 days',
   'Very well. I cooked lunch by myself today.',
   '{"symptom": "none", "severity": "none", "mood": "good", "medications_taken": true}', 'green'),
  ('a4000000-0000-0000-0000-000000000cc4', NOW() - INTERVAL '3 days',
   'Feeling great. Walked to the temple and back.',
   '{"symptom": "none", "severity": "none", "mood": "good", "medications_taken": true}', 'green'),
  ('a4000000-0000-0000-0000-000000000cc4', NOW() - INTERVAL '2 days',
   'All good. Took my medicines. Feeling happy today.',
   '{"symptom": "none", "severity": "none", "mood": "good", "medications_taken": true}', 'green'),
  ('a4000000-0000-0000-0000-000000000cc4', NOW() - INTERVAL '1 day',
   'I am fine. Did my physiotherapy. Feeling better every day.',
   '{"symptom": "none", "severity": "none", "mood": "good", "medications_taken": true}', 'green');

INSERT INTO bp_readings (patient_id, systolic, diastolic, timestamp) VALUES
  ('a4000000-0000-0000-0000-000000000cc4', 122, 78, NOW() - INTERVAL '7 days'),
  ('a4000000-0000-0000-0000-000000000cc4', 118, 76, NOW() - INTERVAL '5 days'),
  ('a4000000-0000-0000-0000-000000000cc4', 120, 78, NOW() - INTERVAL '3 days'),
  ('a4000000-0000-0000-0000-000000000cc4', 119, 75, NOW() - INTERVAL '1 day');

-- Patient 5: Farhan — Post appendectomy, recent Yellow (nausea + missed meds)
INSERT INTO patients (id, name, age, phone, surgery_type, doctor_id, caregiver_id, next_appointment, recovery_template, streak_score) VALUES
  ('a5000000-0000-0000-0000-000000000cc5', 'Farhan Sheikh', 45, '+919934567890', 'Post-Appendectomy',
   'd1000000-0000-0000-0000-000000000aa1', 'c5000000-0000-0000-0000-000000000bb5',
   NOW() + INTERVAL '3 days', 'general_surgery', 3);

INSERT INTO medications (patient_id, name, schedule_time) VALUES
  ('a5000000-0000-0000-0000-000000000cc5', 'Amoxicillin 500mg', '8AM'),
  ('a5000000-0000-0000-0000-000000000cc5', 'Amoxicillin 500mg', '8PM'),
  ('a5000000-0000-0000-0000-000000000cc5', 'Pantoprazole 40mg', '8AM');

INSERT INTO check_ins (patient_id, timestamp, transcript, symptom_json, triage_status) VALUES
  ('a5000000-0000-0000-0000-000000000cc5', NOW() - INTERVAL '7 days',
   'The incision area is a bit sore but okay overall.',
   '{"symptom": "sore", "severity": "low", "mood": "okay", "medications_taken": true}', 'yellow'),
  ('a5000000-0000-0000-0000-000000000cc5', NOW() - INTERVAL '6 days',
   'Feeling much better. Ate solid food for the first time.',
   '{"symptom": "none", "severity": "none", "mood": "good", "medications_taken": true}', 'green'),
  ('a5000000-0000-0000-0000-000000000cc5', NOW() - INTERVAL '5 days',
   'All good. Walked around the house a few times.',
   '{"symptom": "none", "severity": "none", "mood": "good", "medications_taken": true}', 'green'),
  ('a5000000-0000-0000-0000-000000000cc5', NOW() - INTERVAL '4 days',
   'Good morning. Recovery is going well. No pain.',
   '{"symptom": "none", "severity": "none", "mood": "good", "medications_taken": true}', 'green'),
  ('a5000000-0000-0000-0000-000000000cc5', NOW() - INTERVAL '3 days',
   'Slight nausea after taking antibiotic on empty stomach.',
   '{"symptom": "nausea", "severity": "medium", "mood": "okay", "medications_taken": true}', 'yellow'),
  ('a5000000-0000-0000-0000-000000000cc5', NOW() - INTERVAL '2 days',
   'I forgot to take my evening antibiotic yesterday.',
   '{"symptom": "none", "severity": "none", "mood": "okay", "medications_taken": false}', 'yellow'),
  ('a5000000-0000-0000-0000-000000000cc5', NOW() - INTERVAL '1 day',
   'Feeling good today. Took all my medicines on time.',
   '{"symptom": "none", "severity": "none", "mood": "good", "medications_taken": true}', 'green');

INSERT INTO bp_readings (patient_id, systolic, diastolic, timestamp) VALUES
  ('a5000000-0000-0000-0000-000000000cc5', 124, 80, NOW() - INTERVAL '6 days'),
  ('a5000000-0000-0000-0000-000000000cc5', 120, 78, NOW() - INTERVAL '3 days'),
  ('a5000000-0000-0000-0000-000000000cc5', 122, 79, NOW() - INTERVAL '1 day');

INSERT INTO appointments (patient_id, doctor_id, scheduled_at) VALUES
  ('a5000000-0000-0000-0000-000000000cc5', 'd1000000-0000-0000-0000-000000000aa1', NOW() + INTERVAL '3 days');

INSERT INTO alerts (patient_id, alert_type, trigger_reason, triage_status, caregiver_acknowledged, timestamp) VALUES
  ('a5000000-0000-0000-0000-000000000cc5', 'voice_keyword', 'Yellow keyword detected: "nausea"', 'yellow', true, NOW() - INTERVAL '3 days');
