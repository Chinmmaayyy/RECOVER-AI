# RecoverAI — Complete Build Guide
### From Zero to Final App · Antigravity + Claude · No Other Tools Needed

---

> **Who this guide is for:**
> Anyone building RecoverAI from scratch using Antigravity (with Claude subscription).
> Every step is copy-paste ready. No prior setup knowledge required.

---

## 📋 TABLE OF CONTENTS

1. [Total Summary — What We're Building](#1-total-summary)
2. [Tools You Need](#2-tools-you-need)
3. [Before You Open Antigravity — One-Time Setup](#3-before-you-open-antigravity)
4. [CLAUDE.md — What It Is & Exact Content](#4-claudemd)
5. [PROJECT_SPEC.md — What It Is & Where It Goes](#5-project_specmd)
6. [All 10 Sessions — Copy-Paste Prompts](#6-all-10-sessions)
7. [Session Cheat Sheet — Quick Reference](#7-session-cheat-sheet)
8. [Common Errors & Fixes](#8-common-errors--fixes)
9. [Demo Day Checklist](#9-demo-day-checklist)

---

## 1. TOTAL SUMMARY

### What RecoverAI Is
A voice-first, AI-powered post-discharge care companion for hospital patients.
After surgery, a patient like Arthur (72 years old) gets a phone app.
Every morning, the app asks him how he feels. He speaks. The AI listens,
extracts symptoms, and decides if he is safe (Green), at risk (Yellow),
or in danger (Red). The right person gets alerted automatically.

### Three People Use This App

| Person | Device | What They Do |
|--------|--------|--------------|
| **Patient** (Arthur, 72) | Flutter Mobile App | Taps one big button and speaks how he feels |
| **Caregiver** (Elena, his daughter) | Flutter Mobile App | Gets SMS/alerts, monitors Arthur remotely |
| **Doctor** (Dr. Chen) | React Web Dashboard | Sees all patients sorted by risk level |

### The Full Tech Stack

| Layer | Tool | Cost |
|-------|------|------|
| Patient + Caregiver App | Flutter | Free |
| Doctor Dashboard | React + Tailwind | Free |
| Database + Auth + Real-time | Supabase | Free tier |
| On-device AI / NLP | Gemma-2B via MediaPipe | Free |
| Voice Capture | speech_to_text (Flutter) | Free |
| OCR (BP slip scanning) | Google ML Kit | Free |
| Push Notifications | Firebase Cloud Messaging | Free |
| SMS Alerts | Twilio Free Trial | Free (100 SMS) |
| Offline Storage | sqflite + flutter_secure_storage | Free |
| Build Environment | Antigravity (Claude) | Your subscription |

**Total infrastructure cost for demo: ₹0**

### What Gets Built (10 Steps)

```
Step 1  → Supabase database setup (7 tables)
Step 2  → Flutter project scaffold + folder structure
Step 3  → Voice check-in screen (the core feature)
Step 4  → Triage engine (Green / Yellow / Red logic)
Step 5  → OCR BP scanner screen
Step 6  → Offline safety net
Step 7  → Caregiver Flutter dashboard
Step 8  → React doctor web dashboard
Step 9  → SMS alerts + push notifications
Step 10 → Streak score + demo prep
```

---

## 2. TOOLS YOU NEED

### What You Actually Need (Just 3 Things)

```
1. Antigravity          → your AI builder (you already have this)
2. Supabase account     → supabase.com (free, takes 2 minutes to sign up)
3. A text editor        → VS Code, Notepad, or even Apple Notes
                          (just to store your CLAUDE.md and PROJECT_SPEC.md)
```

### What You Do NOT Need
```
✗ Cursor (you have Antigravity)
✗ v0.dev (Antigravity handles React too)
✗ GitHub Copilot (redundant)
✗ Any paid API keys for the demo
✗ Any server or hosting (Supabase handles backend)
```

---

## 3. BEFORE YOU OPEN ANTIGRAVITY

### Step A — Create Your Supabase Project (15 minutes, manual)

This is the only thing you do manually outside Antigravity.
Do this first because every session will need your Supabase URL and key.

1. Go to **supabase.com** → click **Start your project** → sign up free
2. Click **New Project** → name it `recoverai` → set a database password → click Create
3. Wait ~2 minutes for it to spin up
4. Go to **Settings → API** and copy these two values somewhere safe:

```
Project URL:   https://xxxxxxxxxxxx.supabase.co
Anon Key:      eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

5. Go to **SQL Editor** in Supabase → click **New Query** → paste and run this:

```sql
-- PATIENTS TABLE
create table patients (
  id uuid primary key default gen_random_uuid(),
  name text,
  age integer,
  phone text,
  surgery_type text,
  doctor_id uuid,
  caregiver_id uuid,
  next_appointment timestamp,
  recovery_template text,
  streak_score integer default 0,
  created_at timestamp default now()
);

-- CHECK-INS TABLE
create table check_ins (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid references patients(id),
  timestamp timestamp default now(),
  transcript text,
  symptom_json jsonb,
  triage_status text check (triage_status in ('green','yellow','red')),
  created_at timestamp default now()
);

-- BP READINGS TABLE
create table bp_readings (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid references patients(id),
  systolic integer,
  diastolic integer,
  photo_ref text,
  timestamp timestamp default now()
);

-- ALERTS TABLE
create table alerts (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid references patients(id),
  alert_type text,
  trigger_reason text,
  triage_status text,
  caregiver_acknowledged boolean default false,
  timestamp timestamp default now()
);

-- MEDICATIONS TABLE
create table medications (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid references patients(id),
  name text,
  schedule_time text
);

-- MED VERIFICATION LOG
create table med_verification_log (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid references patients(id),
  medication_id uuid references medications(id),
  verified_at timestamp,
  method text
);

-- APPOINTMENTS TABLE
create table appointments (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid references patients(id),
  doctor_id uuid,
  scheduled_at timestamp,
  pre_visit_note text,
  patient_question text
);

-- ENABLE ROW LEVEL SECURITY ON ALL TABLES
alter table patients enable row level security;
alter table check_ins enable row level security;
alter table bp_readings enable row level security;
alter table alerts enable row level security;
alter table medications enable row level security;
alter table med_verification_log enable row level security;
alter table appointments enable row level security;
```

6. Click **Run**. All 7 tables are created. ✅

### Step B — Seed Demo Data (for demo day)

Run this in the same SQL Editor:

```sql
-- Insert demo doctor
insert into patients (name, age, phone, surgery_type, streak_score)
values ('Arthur Kumar', 72, '+919800000000', 'Post-CABG (Heart Bypass)', 5);

-- Insert demo medications
insert into medications (patient_id, name, schedule_time)
select id, 'Aspirin 75mg', '8AM' from patients where name = 'Arthur Kumar';

insert into medications (patient_id, name, schedule_time)
select id, 'Metoprolol 25mg', '8AM' from patients where name = 'Arthur Kumar';

insert into medications (patient_id, name, schedule_time)
select id, 'Atorvastatin 40mg', '9PM' from patients where name = 'Arthur Kumar';

-- Insert 7 days of mock check-ins (mix of green and yellow)
insert into check_ins (patient_id, transcript, symptom_json, triage_status, timestamp)
select
  id,
  'I feel okay today, took all my medicines',
  '{"symptom": "none", "severity": "low", "mood": "good", "medications_taken": true}',
  'green',
  now() - interval '6 days'
from patients where name = 'Arthur Kumar';

insert into check_ins (patient_id, transcript, symptom_json, triage_status, timestamp)
select
  id,
  'Feeling a little tired this afternoon',
  '{"symptom": "tired", "severity": "low", "mood": "neutral", "medications_taken": true}',
  'yellow',
  now() - interval '3 days'
from patients where name = 'Arthur Kumar';
```

### Step C — Create Your Two Project Files

Open VS Code or any text editor. Create a folder called `recoverai-context`.
Inside it, create two files:

```
recoverai-context/
├── CLAUDE.md          ← rules for the AI (Section 4 below)
└── PROJECT_SPEC.md    ← your full project spec (Section 5 below)
```

Keep this folder open throughout the build. You'll copy-paste from it constantly.

---

## 4. CLAUDE.md

### What Is CLAUDE.md?

`CLAUDE.md` is a file you place at the root of your project.
When Claude (inside Antigravity) opens your project, it reads this file **first — automatically.**
It's a permanent briefing. You write the rules once. The AI follows them every session.

Think of it as: **"The AI reads this before touching a single line of your code."**

Without it: you re-explain the project every session.
With it: the AI already knows everything before you say a word.

### Where Does It Live?

```
recoverai/               ← your Flutter project root
├── CLAUDE.md            ← 👈 RIGHT HERE at the root
├── PROJECT_SPEC.md      ← 👈 AND THIS ONE TOO
├── lib/
│   ├── main.dart
│   ├── screens/
│   ├── services/
│   └── models/
├── pubspec.yaml
└── android/
```

### Exact Content — Copy This Entire Block

```md
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

---

## 5. PROJECT_SPEC.md

### What Is PROJECT_SPEC.md?

This is your full project specification — the detailed build guide.
It contains the database schema, all feature descriptions, triage logic,
dashboard layouts, and implementation steps.

Unlike CLAUDE.md (which is rules), PROJECT_SPEC.md is the **"what to build"** reference.

### Where Does It Live?

Same place as CLAUDE.md — root of your Flutter project:

```
recoverai/
├── CLAUDE.md         ← AI rules
├── PROJECT_SPEC.md   ← full spec  👈
├── lib/
└── pubspec.yaml
```

### What to Put In It

Paste the **entire content** of your RecoverAI_Build_Guide.md file
(the first MD file we created together) into PROJECT_SPEC.md.

That file already has:
- Complete database schema
- All 5 features described in detail
- Login architecture
- Triage engine logic
- Dashboard designs
- 10-step implementation plan

So: **PROJECT_SPEC.md = RecoverAI_Build_Guide.md content. Copy-paste it in.**

### How to Reference It in Antigravity

At the start of any session, paste this:

```
Read PROJECT_SPEC.md in the project root.
Use it as the source of truth for everything you build.
Now do: [your specific task for this session]
```

---

## 6. ALL 10 SESSIONS — COPY-PASTE PROMPTS

> **How to use these:**
> Open Antigravity → start a new session → paste the SETUP BLOCK first → then paste the SESSION PROMPT.
> That's it. One session = one feature built.

---

### 🔵 SETUP BLOCK — Paste This at the Start of EVERY Session

```
You are building RecoverAI, a Flutter + React + Supabase app.
Read CLAUDE.md in the project root before writing any code.
Follow all rules in CLAUDE.md exactly.
My Supabase URL is: [paste your URL here]
My Supabase Anon Key is: [paste your key here]
Always give me complete files, never partial code.
```

---

### SESSION 1 — Flutter Project Scaffold

**Goal:** Create the entire project structure, install all packages.

```
[Paste SETUP BLOCK first]

Now do Session 1:

Create a new Flutter project called recoverai.
Set up this exact folder structure inside lib/:
  screens/
    voice_checkin_screen.dart (empty for now)
    ocr_scanner_screen.dart (empty for now)
    medication_screen.dart (empty for now)
    streak_screen.dart (empty for now)
    caregiver_dashboard.dart (empty for now)
  services/
    triage_engine.dart (empty for now)
    supabase_service.dart (empty for now)
    offline_cache.dart (empty for now)
    sms_service.dart (empty for now)
  models/
    patient.dart
    checkin.dart
    alert.dart
  main.dart

Add these dependencies to pubspec.yaml:
  supabase_flutter: ^2.0.0
  speech_to_text: ^6.6.0
  camera: ^0.10.5
  google_mlkit_text_recognition: ^0.11.0
  sqflite: ^2.3.0
  flutter_secure_storage: ^9.0.0
  url_launcher: ^6.2.0
  firebase_messaging: ^14.7.0
  lottie: ^3.0.0
  permission_handler: ^11.0.0

Set up main.dart to:
1. Initialize Supabase with my URL and anon key
2. Initialize Firebase
3. Route to VoiceCheckinScreen as the home screen
4. Set app theme to white background with blue (#1565C0) primary color

Create patient.dart model with these fields:
id, name, age, phone, surgeryType, doctorId, caregiverId,
nextAppointment, recoveryTemplate, streakScore, createdAt
All fields nullable, include fromJson and toJson methods.

Create checkin.dart model with fields:
id, patientId, timestamp, transcript, symptomJson,
triageStatus, createdAt. Include fromJson and toJson.

Create alert.dart model with fields:
id, patientId, alertType, triggerReason, triageStatus,
caregiverAcknowledged, timestamp. Include fromJson and toJson.

Give me every file completely. No partial code.
```

---

### SESSION 2 — Supabase Service

**Goal:** All database functions in one service file.

```
[Paste SETUP BLOCK first]

Now do Session 2:

Build lib/services/supabase_service.dart

This file should have a SupabaseService class with these functions:

1. Future<Patient?> getPatient(String patientId)
   → fetch a single patient from patients table

2. Future<void> saveCheckin(String patientId, String transcript, Map symptomJson, String triageStatus)
   → insert a row into check_ins table

3. Future<List<CheckIn>> getRecentCheckins(String patientId, int limit)
   → fetch last N check-ins for a patient, ordered by timestamp desc

4. Future<void> saveBpReading(String patientId, int systolic, int diastolic)
   → insert into bp_readings table
   → if systolic > 150, also call saveAlert() with alertType: 'bp_threshold'

5. Future<void> saveAlert(String patientId, String alertType, String triggerReason, String triageStatus)
   → insert into alerts table

6. Stream<List<Map>> watchPatientAlerts(String patientId)
   → Supabase real-time subscription on alerts table filtered by patient_id
   → returns a Stream so the UI can listen and update automatically

7. Future<void> updateStreakScore(String patientId, int newScore)
   → update streak_score in patients table

Use the Supabase client initialized in main.dart.
Handle all errors with try/catch and print errors to console.
Add a comment above every function explaining what it does.
Give me the complete file.
```

---

### SESSION 3 — Triage Engine

**Goal:** The brain of the app — classifies symptoms as Green/Yellow/Red.

```
[Paste SETUP BLOCK first]

Now do Session 3:

Build lib/services/triage_engine.dart

Create a TriageEngine class with these exact rules:

RED KEYWORDS (must detect these in transcript):
chest tight, shortness of breath, can't breathe, severe pain,
dizzy, bleeding, fainted, chest heavy, puffy, breathless

YELLOW KEYWORDS:
mild pain, nausea, tired, slight fever, sore, uncomfortable,
a little pain, slight pain

RULES (in this exact priority order):
Rule 1: If systolic BP is provided and systolic > 150 → return 'red'
Rule 2: If any Red keyword found in transcript (case insensitive) → return 'red'
Rule 3: If recentHistory has 3 or more consecutive 'yellow' statuses → return 'red'
Rule 4: If any Yellow keyword found in transcript → return 'yellow'
Rule 5: Otherwise → return 'green'

Create this function:
String classifyTranscript(String transcript, {int? systolicBp, List<String> recentStatuses = const []})
  → returns 'green', 'yellow', or 'red'

Also create:
Map<String, dynamic> extractSymptomJson(String transcript)
  → looks for known keywords in transcript
  → returns {
       "symptom": detected symptom or "none",
       "severity": "high" if red keyword, "low" if yellow, "none" if green,
       "mood": "low" if negative words found, "good" otherwise,
       "medications_taken": true (default, can be updated later)
     }

Add this SAFETY COMMENT at the top of the file:
// SAFETY: This engine makes triage decisions only.
// It never suggests treatments, diagnoses, or medications.
// All output is routed to human caregivers and doctors.

Give me the complete file with full comments.
```

---

### SESSION 4 — Voice Check-In Screen

**Goal:** The main patient interface. The single most important screen.

```
[Paste SETUP BLOCK first]

Now do Session 4:

Build lib/screens/voice_checkin_screen.dart

This is the most important screen in the app.
Design for a 72-year-old user recovering from heart surgery.

LAYOUT:
- White full-screen background
- Top: Patient name in large bold text (e.g. "Good morning, Arthur 👋")
- Center: One GIANT circular button — minimum 180px diameter
  Text inside: "TAP TO SPEAK"
  Color: #1565C0 (blue) when idle, #D32F2F (red) when listening
  Add a subtle pulse animation when listening
- Below button: Live transcript text appears here as user speaks
  Use a rounded grey card, 16sp font, readable
- Bottom: Status pill appears after processing
  Green pill (#2E7D32) for green, Yellow (#F57F17) for yellow,
  Red (#C62828) for red — with matching icon and short message

BEHAVIOR:
1. When screen loads: play audio "Hello [patient name]! How are you feeling today?"
   Use Flutter TTS or pre-recorded audio file
2. When TAP TO SPEAK pressed: start speech_to_text, show pulse animation
3. As user speaks: show live transcript text updating in real time
4. When user stops: stop recording
5. Call TriageEngine.classifyTranscript() with the transcript
6. Call SupabaseService.saveCheckin() to store the result
7. Show the status pill with appropriate color and message:
   Green: "You're doing great today! ✅"
   Yellow: "Thanks for sharing. Elena has been notified. 💛"
   Red: "Please call your doctor now. Elena has been alerted. 🚨"
8. If status is RED: also call SmsService.sendRedAlert()

Also add at the bottom of the screen:
- Small camera icon button → navigates to OcrScannerScreen
- Small pill icon button → navigates to MedicationScreen
- Small star icon button → navigates to StreakScreen

Request microphone permission on first launch using permission_handler.

Give me the complete file with full comments on every function.
```

---

### SESSION 5 — OCR Scanner Screen

**Goal:** Patient photographs BP slip, app extracts reading automatically.

```
[Paste SETUP BLOCK first]

Now do Session 5:

Build lib/screens/ocr_scanner_screen.dart

LAYOUT:
- Dark background (camera view fills the screen)
- Center: white rectangle overlay (the bounding box — 280x160px)
  Label above it: "Place your BP slip inside the white box"
- Bottom bar: white rounded container with:
  - Circular capture button (white, 70px)
  - Status text below (shows extracted reading or instructions)
- Top left: back arrow to return to home

BEHAVIOR:
1. On screen load: play audio "Please place your blood pressure report
   inside the white box and tap the button"
2. Camera preview fills background behind the bounding box overlay
3. When capture button tapped:
   - Take photo using camera package
   - Run google_mlkit_text_recognition on the image
   - Apply regex r'(\d{2,3})\/(\d{2,3})' to find BP reading
   - Show extracted reading on screen: "Reading found: 162/100"
4. If reading found:
   - Call SupabaseService.saveBpReading(patientId, systolic, diastolic)
   - SupabaseService automatically handles Red Alert if systolic > 150
   - Show result: green card if safe, red card with "⚠️ High BP Detected. Dr. Chen has been notified." if systolic > 150
5. If no reading found:
   - Show: "Could not read the slip. Please try again in better lighting."
   - Offer a manual entry option: two text fields for systolic and diastolic

Request camera permission on first launch using permission_handler.

Give me the complete file with full comments.
```

---

### SESSION 6 — Offline Cache & Safety Net

**Goal:** App works even without internet. Offline Red Alert fires via SMS.

```
[Paste SETUP BLOCK first]

Now do Session 6:

Build lib/services/offline_cache.dart

Use sqflite for local SQLite database on the device.
Use flutter_secure_storage to encrypt sensitive data.

Create an OfflineCache class with these functions:

1. Future<void> initDb()
   → Create local SQLite database with tables:
     cached_patient (id, name, phone, caregiver_phone, surgeon_type, streak_score)
     cached_checkins (id, patient_id, transcript, triage_status, timestamp)
   → Called once on app startup

2. Future<void> cachePatient(Patient patient)
   → Save patient data locally
   → Encrypt phone and caregiver_phone using flutter_secure_storage
     before storing in SQLite

3. Future<Patient?> getCachedPatient()
   → Return the locally cached patient

4. Future<void> cacheCheckin(String transcript, String triageStatus)
   → Save check-in locally with current timestamp
   → Only keep last 7 check-ins (delete older ones)

5. Future<List<String>> getRecentLocalStatuses()
   → Return list of last 3 triage_status values from cached check-ins
   → Used by TriageEngine for escalation check when offline

6. Future<bool> isOnline()
   → Try a simple HTTP HEAD request to supabase URL
   → Return true if connected, false if not

7. Future<void> handleOfflineRedAlert(String transcript)
   → Called when triage returns 'red' AND isOnline() returns false
   → Get caregiver_phone from flutter_secure_storage
   → Use url_launcher to open pre-filled SMS:
     sms:[caregiver_phone]?body=URGENT: [patient name] has flagged a critical symptom. Please check on them immediately.
   → This bypasses internet and sends real SMS from the device

Give me the complete file with full comments.
```

---

### SESSION 7 — SMS Service + Caregiver Dashboard

**Goal:** Alerts system + the caregiver's view of their patient.

```
[Paste SETUP BLOCK first]

Now do Session 7, Part A: lib/services/sms_service.dart

Create SmsService class with:

1. Future<void> sendRedAlert(String patientName, String caregiverPhone, String triggerReason)
   → Make a POST request to Twilio API:
     URL: https://api.twilio.com/2010-04-01/Accounts/[ACCOUNT_SID]/Messages.json
     Body: To=[caregiverPhone], From=[twilio_number], Body=URGENT: [patientName] has flagged a critical symptom ([triggerReason]). Please check in immediately.
   → Use Basic Auth with Twilio Account SID and Auth Token
   → Handle errors gracefully — if Twilio fails, fall back to url_launcher SMS
   → Note: For demo, use Twilio free trial credentials

2. Future<void> sendYellowNudge(String patientName, String caregiverPhone)
   → Send a softer message:
     "[patientName] reported mild discomfort in their last check-in. Worth checking in when you get a chance."


Now Session 7, Part B: lib/screens/caregiver_dashboard.dart

This is the caregiver's main screen. Build it for Elena (Arthur's daughter).

LAYOUT:
Top card (full width, colored by status):
  - Green card: "Arthur is doing well ✅ — Last check-in 20 min ago"
  - Yellow card: "Arthur reported mild discomfort 💛 — 2 hours ago"
  - Red card (flashing): "⚠️ CRITICAL ALERT — Arthur needs attention NOW"
  Show last check-in time and date

Middle section:
  - "Last voice transcript" — show full text of most recent check-in in a grey card
  - "Today's medications" — list with green check / grey circle / red X per medication

Bottom section:
  - 7-day timeline: a horizontal scrollable list of colored dots (G/Y/R) for each day
  - Quick action buttons:
    📞 Call Arthur (url_launcher tel:)
    💬 Message Doctor
    📋 View Full History

BEHAVIOR:
- Use SupabaseService.watchPatientAlerts() stream to update the top card in real time
- When Red alert arrives via stream → top card flashes, device vibrates
- Pull-to-refresh to reload data manually

Give me all complete files.
```

---

### SESSION 8 — React Doctor Dashboard

**Goal:** The web-based doctor interface. Risk-sorted, real-time.

```
[Paste SETUP BLOCK first]

Now do Session 8:

Build a React doctor dashboard as a single HTML file using:
- React 18 (via CDN)
- Tailwind CSS (via CDN)
- Supabase JS client (via CDN)
- Recharts for graphs (via CDN)

My Supabase URL: [paste your URL]
My Supabase Anon Key: [paste your key]

LAYOUT:

Top stats bar (4 cards side by side):
  - Total Patients
  - 🔴 Red (critical)
  - 🟡 Yellow (at risk)
  - Overall Medication Adherence %

Patient list (sorted Red → Yellow → Green):
Each row shows:
  - Patient name + surgery type
  - Days since discharge
  - Colored status badge (Red/Yellow/Green)
  - Last BP reading (from bp_readings)
  - Last check-in time
  - Click to expand row

Expanded patient row shows:
  - 7-day bar chart of triage status per day (using Recharts)
  - Full voice transcript log (scrollable, timestamped)
  - BP reading history
  - Medication adherence %

Pre-Visit Summary card:
  - Appears for any patient whose next_appointment is within 24 hours
  - Shows: 7-day summary, avg BP, medication adherence, patient's question
  - Styled with a yellow border to stand out

BEHAVIOR:
- Supabase real-time subscription on check_ins and alerts tables
- When a new Red check-in arrives: that patient auto-jumps to top of list
  with a pulsing red border — no page refresh needed
- Sort order: Red always first, then Yellow, then Green
- Within same status: sort by most recent check-in

STYLE:
- Clean white background, dark sidebar
- Red: #EF4444, Yellow: #F59E0B, Green: #10B981
- Professional medical dashboard feel
- Works on desktop browser (Chrome)

Give me the complete single HTML file, fully working.
```

---

### SESSION 9 — Appointment Prep (Supabase Edge Function)

**Goal:** Auto-generate pre-visit summaries 24 hours before appointments.

```
[Paste SETUP BLOCK first]

Now do Session 9:

Create a Supabase Edge Function for appointment prep.

File: supabase/functions/appointment-prep/index.ts

This function runs on a cron schedule every day at 8 PM.

WHAT IT DOES:
1. Query appointments table for any appointments scheduled within the next 24 hours
2. For each patient with an upcoming appointment:
   a. Fetch their last 7 check-ins from check_ins table
   b. Fetch their last 5 BP readings from bp_readings table
   c. Fetch their medication adherence from med_verification_log
   d. Build a pre_visit_note string in this format:
      "7-day overview: [X] Green days, [Y] Yellow days, [Z] missed check-ins.
       Medication adherence: [%]. Average BP from scans: [avg]/[avg].
       Patient's question: [last patient_question from check-ins if any]"
   e. Update the appointments row with the generated pre_visit_note
3. Return a summary of how many summaries were generated

Also write the instructions in a comment at the top showing how to
deploy this Edge Function using the Supabase CLI and how to schedule
it as a cron job in Supabase Dashboard under Edge Functions → Schedule.

Give me the complete TypeScript file.
```

---

### SESSION 10 — Streak Score + Demo Polish

**Goal:** Gamification layer + full demo prep.

```
[Paste SETUP BLOCK first]

Now do Session 10:

Part A: Build lib/screens/streak_screen.dart

LAYOUT:
- White background
- Top: "Recovery Streak 🔥" title
- Center: Large circle showing streak number (e.g. "5 days")
- Below: Lottie animation of a growing plant
  (use a free Lottie file from lottiefiles.com — plant growth animation)
- Progress bar showing progress toward next milestone (7 days, 14 days, 30 days)
- List of last 7 days with colored dot per day (Green/Yellow/Red)
- Motivational message that changes based on streak:
  0-2 days: "Every day counts. Keep going! 💪"
  3-6 days: "You're building a great habit! 🌱"
  7-13 days: "One week strong! Arthur would be proud. 🌿"
  14+ days: "Incredible recovery! You're an inspiration. 🌳"

BEHAVIOR:
- Load streak_score from Supabase patients table
- Load last 7 check-ins to show the colored dot timeline
- Increment streak_score by 1 each time a full Green day is completed
  (call SupabaseService.updateStreakScore)


Part B: Demo hardening — update VoiceCheckinScreen

Add a DEMO MODE toggle that can be enabled with a secret tap
(tap the patient name 5 times quickly):
When DEMO MODE is on:
  - "TAP TO SPEAK" button accepts typed input instead of voice
  - After 3 seconds, auto-fills transcript with:
    "I feel a bit heavy in my chest today and my legs look a little puffy"
  - Runs triage normally → triggers RED status
  - Shows the full Red alert flow

This is for demo day when mic might fail on noisy hackathon floor.


Part C: Update main.dart

Add a simple login screen with two big buttons:
  [Patient App] → goes to VoiceCheckinScreen with Arthur's patient ID
  [Caregiver App] → goes to CaregiverDashboard
  [Doctor Dashboard] → opens the React dashboard URL in a webview

Give me all complete files.
```

---

## 7. SESSION CHEAT SHEET — QUICK REFERENCE

Print this or keep it open. One row per session.

| # | Session Name | Time | What Gets Built | Key Files |
|---|-------------|------|-----------------|-----------|
| 1 | Scaffold | 30 min | Project structure, pubspec, models | main.dart, models/ |
| 2 | Supabase Service | 30 min | All DB functions | supabase_service.dart |
| 3 | Triage Engine | 20 min | Green/Yellow/Red logic | triage_engine.dart |
| 4 | Voice Check-in | 45 min | Core patient screen | voice_checkin_screen.dart |
| 5 | OCR Scanner | 45 min | BP slip camera screen | ocr_scanner_screen.dart |
| 6 | Offline Cache | 30 min | Works without internet | offline_cache.dart |
| 7 | SMS + Caregiver | 45 min | Alerts + caregiver view | sms_service.dart, caregiver_dashboard.dart |
| 8 | React Dashboard | 45 min | Doctor web dashboard | dashboard.html |
| 9 | Edge Function | 20 min | Auto pre-visit summaries | appointment-prep/index.ts |
| 10 | Streak + Polish | 30 min | Gamification + demo mode | streak_screen.dart |

**Total estimated time: ~6 hours of focused sessions**

---

## 8. COMMON ERRORS & FIXES

### Flutter won't find Supabase package
```
Run: flutter pub get
If still failing, check pubspec.yaml indentation — YAML is space-sensitive
```

### speech_to_text not working on Android
```
Add to android/app/src/main/AndroidManifest.xml:
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
```

### Camera package not working on iOS
```
Add to ios/Runner/Info.plist:
<key>NSCameraUsageDescription</key>
<string>RecoverAI needs camera access to scan BP reports</string>
```

### Google ML Kit OCR returns empty string
```
Make sure the image is well-lit.
Add this to android/app/build.gradle:
dependencies {
  implementation 'com.google.mlkit:text-recognition:16.0.0'
}
```

### Supabase real-time not updating
```
Check that RLS is not blocking the subscription.
For demo, you can temporarily disable RLS on the alerts table:
  In Supabase → Authentication → Policies → disable RLS on alerts
```

### Antigravity gives partial code
```
Add to your prompt: "Give me the complete file. Never give partial code.
Start from the top of the file and go all the way to the end."
```

### Antigravity drifts from the spec
```
Paste this reminder:
"Read CLAUDE.md and PROJECT_SPEC.md again.
You are drifting from the spec. Follow the spec exactly."
```

---

## 9. DEMO DAY CHECKLIST

Run through this the night before demo day:

### Supabase
- [ ] Arthur's patient profile exists in patients table
- [ ] At least 7 days of mock check-ins seeded (mix of Green + Yellow)
- [ ] At least 2 BP readings in bp_readings table
- [ ] Real-time subscription tested — doctor dashboard updates without refresh

### Flutter App
- [ ] DEMO MODE works (tap name 5 times → enables typed input)
- [ ] Red Alert flow tested end-to-end
- [ ] OCR tested in actual demo room lighting
- [ ] Fallback hardcoded value ready if OCR fails
- [ ] App does NOT crash if internet is slow

### React Dashboard
- [ ] Doctor dashboard opens on laptop
- [ ] Arthur appears at top of list with Red badge
- [ ] 7-day chart renders correctly
- [ ] Pre-Visit Summary card shows up

### Physical Props for Demo
- [ ] Print: "Blood Pressure: 160/100" in large clear font on paper
- [ ] Pre-record audio: "Good morning Arthur! How are you feeling today?" (ElevenLabs free tier)
- [ ] Have a teammate's phone ready to receive the Twilio SMS

### Demo Script (60 second flow)
```
1. Open patient app → show Arthur's home screen
2. Tap TAP TO SPEAK (or use DEMO MODE on noisy floor)
3. Say / type: "I feel a bit heavy in my chest today"
4. Watch triage fire → screen turns RED
5. Switch to laptop → show doctor dashboard updating in real time
6. Show teammate's phone receiving Twilio SMS
7. Point out: "One voice sentence. Three people alerted. Zero manual work."
```

---

## FINAL NOTE FOR ANYONE READING THIS

This guide covers:

- ✅ What RecoverAI is and who uses it
- ✅ The full tech stack (all free tools)
- ✅ One-time Supabase setup with exact SQL
- ✅ What CLAUDE.md is, why it exists, and exact content to paste
- ✅ What PROJECT_SPEC.md is and what to put in it
- ✅ 10 complete Antigravity sessions, copy-paste ready
- ✅ Session cheat sheet with time estimates
- ✅ Common errors and how to fix them
- ✅ Demo day checklist and 60-second demo script

You do not need Cursor, v0, or any paid tools beyond Antigravity.
You do not need to write code from scratch — every session prompt tells the AI exactly what to build.
Your only job is to: run the sessions in order, review the output, and move to the next one.

---

*RecoverAI · Complete Build Guide · Antigravity + Claude · 0 → Final App*
