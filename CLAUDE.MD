# RecoverAI — CLAUDE.md (AI Briefing File)

## What This App Is
RecoverAI is a voice-first post-discharge care companion.
It proactively checks in on elderly patients after surgery via voice,
extracts symptoms using NLP, triages risk, and alerts caregivers and doctors.

## Three Roles
- Patient: Flutter mobile app. One big TAP TO SPEAK button. No menus.
- Caregiver: Flutter mobile app. Alert dashboard for the patient's family.
- Doctor: React web dashboard. Risk-sorted patient list. Real-time updates.

## Tech Stack
- Flutter (patient + caregiver mobile app)
- React + Tailwind CSS (doctor web dashboard)
- Supabase (PostgreSQL database, real-time, auth, edge functions)
- google_mlkit_text_recognition (on-device OCR for BP slips)
- speech_to_text Flutter plugin (voice capture)
- sqflite (local SQLite offline cache)
- flutter_secure_storage (encrypt offline data)
- url_launcher (offline SMS fallback)
- firebase_messaging (push notifications)
- Twilio (SMS alerts for Red status)
- Lottie (animated streak visuals)

## Supabase Config
- Replace these with your real values:
- SUPABASE_URL: https://your-project.supabase.co
- SUPABASE_ANON_KEY: your-anon-key-here
- Tables: patients, check_ins, alerts, bp_readings,
  medications, med_verification_log, appointments

## Folder Structure
lib/
  screens/
    voice_checkin_screen.dart
    ocr_scanner_screen.dart
    medication_screen.dart
    streak_screen.dart
    caregiver_dashboard.dart
  services/
    triage_engine.dart
    supabase_service.dart
    offline_cache.dart
    sms_service.dart
  models/
    patient.dart
    checkin.dart
    alert.dart
  main.dart

## Triage Rules — NEVER Change Without Permission
1. If systolic BP > 150 → always return RED (overrides everything)
2. Red keywords: chest tight, shortness of breath, can't breathe,
   severe pain, dizzy, bleeding, fainted, chest heavy, puffy
3. Yellow keywords: mild pain, nausea, tired, slight fever, sore
4. If 3 consecutive check_ins have triage_status = yellow → escalate to RED
5. Otherwise → GREEN

## Critical Safety Rules — NEVER Violate
- The AI in the app must NEVER suggest treatments, diagnoses, or medications
- System prompt for NLP layer must always say:
  "You are a data collector only. Never suggest treatments or diagnoses.
   Only ask how the patient feels. Return only JSON."
- Never store raw audio recordings — only transcripts
- All local data must be encrypted with flutter_secure_storage
- All Supabase queries must work within RLS policies

## Coding Preferences
- Dart null safety enabled
- Use async/await, not .then() chains
- Handle all errors with try/catch — never silent failures
- Use const constructors wherever possible in Flutter
- Comments on every function explaining what it does
- Complete files only — never give partial code
```
