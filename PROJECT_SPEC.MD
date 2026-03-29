# RecoverAI — Full App Build Guide

> **Intelligent Post-Discharge Care Companion**
> Voice-First · Proactive · Three-Role Architecture

---

## Table of Contents

1. [What We're Building](#1-what-were-building)
2. [Three Roles & Their Interfaces](#2-three-roles--their-interfaces)
3. [Complete Tech Stack](#3-complete-tech-stack)
4. [Database Schema](#4-database-schema)
5. [Feature Breakdown](#5-feature-breakdown)
6. [Login Architecture](#6-login-architecture)
7. [Triage Engine Logic](#7-triage-engine-logic)
8. [Data Flow — Core Loop](#8-data-flow--core-loop)
9. [Dashboard Designs](#9-dashboard-designs)
10. [Implementation Plan (48-Hour Sprint)](#10-implementation-plan-48-hour-sprint)
11. [Risks & Mitigations](#11-risks--mitigations)

---

## 1. What We're Building

RecoverAI is a **Voice-First, Proactive Digital Nurse** for the 30-day post-discharge window — the most dangerous period in a patient's recovery. It eliminates UI barriers by initiating natural voice conversations, cross-referencing symptom data with medication status, and escalating intelligently to the right person at the right time.

### Core Problem
- Patients discharged with complex medication schedules they cannot follow independently.
- Elderly users cannot navigate digital health portals (logins, menus, typing).
- Doctors are blind to at-home recovery — they only learn of problems at the ER.
- Caregivers face constant anxiety and burnout from manual check-in calls.

### Key Insight: Pull vs. Push
> All existing tools are **Pull** — they wait for the patient to act. Elderly patients recovering from surgery will NOT initiate. RecoverAI is a **Push** system: it proactively reaches out based on daily routine, like a real nurse would.

---

## 2. Three Roles & Their Interfaces

| Role | Interface | Core Need |
|------|-----------|-----------|
| **Patient** (e.g., Arthur, 72) | Flutter Mobile App | Zero friction; no navigation; speak naturally |
| **Caregiver** (e.g., Elena) | Flutter Mobile App | Actionable nudges; no alert fatigue; async video log |
| **Doctor** (e.g., Dr. Chen) | React Web Dashboard | See only at-risk patients; pre-built visit summaries |

---

## 3. Complete Tech Stack

### Frontend — Patient & Caregiver App

- **Flutter** (free, open-source)
  - Compiles natively for Android & iOS
  - Excellent local storage and accelerometer access
  - Big-Button UI easy to build for elderly users
  - Packages used:
    - `speech_to_text` — voice capture for check-ins
    - `flutter_camera` — BP slip OCR scanner
    - `google_mlkit_text_recognition` — on-device OCR (free, offline)
    - `sqflite` — local SQLite for offline caching
    - `flutter_secure_storage` — encrypt offline data
    - `url_launcher` — offline Red Alert SMS fallback
    - `lottie` — animated Recovery Pet visuals (bonus streak feature)
    - `firebase_messaging` — push notification receiver

### Frontend — Doctor & Admin Dashboard

- **React.js** (free)
  - Rapid development of complex dashboard views
  - Large component ecosystem (charts, tables, badges)
  - Libraries:
    - `@supabase/supabase-js` — real-time subscriptions
    - `recharts` or `chart.js` — 7-day symptom trend charts
    - `react-router-dom` — role-based routing (`?role=doctor`, `?role=caregiver`)

### Backend & Database

- **Supabase** (free tier — PostgreSQL)
  - Open-source Firebase alternative
  - Real-time sync via WebSocket subscriptions
  - 500MB free storage
  - Handles complex relational medical data
  - Row-Level Security (RLS) for data isolation per user
  - **Supabase Edge Functions** — scheduled cron jobs (Pre-Visit Summary, T-24hr detection)
  - **Supabase Storage** — private bucket for optional video logs (signed URL, 1-hour expiry)

### AI / NLP Layer

- **Gemma-2B via MediaPipe** (free, on-device)
  - Runs on-device: 100% private, zero latency, zero cost
  - No patient data leaves the phone
  - Fallback: regex-based rule engine (keyword matching)
  - Input: voice transcript string
  - Output: structured JSON `{symptom, severity, mood, medications_taken}`

### Voice Capture

- **Web Speech API** (free, browser-native)
  - Zero cost, no API key needed
  - Works on Chrome for web dashboard
  - Flutter equivalent: `speech_to_text` plugin
  - Fallback: **OpenAI Whisper free tier**

### OCR

- **Google ML Kit** (free, on-device)
  - Text recognition from camera frame
  - Works offline — no API key required
  - BP extraction regex: `(\d{2,3})\/(\d{2,3})`
  - Integrated via `google_mlkit_text_recognition` Flutter package

### Notifications

- **Firebase Cloud Messaging (FCM)** (free tier)
  - Push notifications for scheduled check-ins and alerts
  - 500K messages/month free

### SMS Fallback

- **Twilio Free Trial** — 100 free SMS for Red Alert messages
- **`url_launcher`** — zero-cost offline SMS trigger directly from device

### Scheduled Jobs

- **Supabase Edge Functions + cron** (free)
  - T-24 hour appointment detection
  - Auto-generate Pre-Visit Summary card
  - No paid server required

### Authentication

- **Supabase Auth** — handles patient PIN sessions, caregiver email/password
- **Google OAuth** — doctor login via institutional email (no separate password)

---

## 4. Database Schema

### `patients`
```sql
id              UUID PRIMARY KEY
name            TEXT
age             INTEGER
phone           TEXT
surgery_type    TEXT        -- e.g. "Post-CABG"
doctor_id       UUID        -- FK → doctors.id
caregiver_id    UUID        -- FK → caregivers.id
next_appointment TIMESTAMP
recovery_template TEXT
streak_score    INTEGER DEFAULT 0
created_at      TIMESTAMP
```

### `check_ins`
```sql
id              UUID PRIMARY KEY
patient_id      UUID        -- FK → patients.id
timestamp       TIMESTAMP
transcript      TEXT        -- full voice transcript
symptom_json    JSONB       -- {symptom, severity, mood, medications_taken}
triage_status   TEXT        -- "green" | "yellow" | "red"
created_at      TIMESTAMP
```

### `bp_readings`
```sql
id              UUID PRIMARY KEY
patient_id      UUID
systolic        INTEGER
diastolic       INTEGER
photo_ref       TEXT        -- Supabase Storage path
timestamp       TIMESTAMP
```

### `alerts`
```sql
id              UUID PRIMARY KEY
patient_id      UUID
alert_type      TEXT        -- "voice_keyword" | "bp_threshold" | "escalation"
trigger_reason  TEXT
triage_status   TEXT
caregiver_acknowledged BOOLEAN DEFAULT false
timestamp       TIMESTAMP
```

### `medications`
```sql
id              UUID PRIMARY KEY
patient_id      UUID
name            TEXT        -- e.g. "Aspirin 75mg"
schedule_time   TEXT        -- "8AM"
```

### `med_verification_log`
```sql
id              UUID PRIMARY KEY
patient_id      UUID
medication_id   UUID
verified_at     TIMESTAMP
method          TEXT        -- "ocr" | "manual"
```

### `appointments`
```sql
id              UUID PRIMARY KEY
patient_id      UUID
doctor_id       UUID
scheduled_at    TIMESTAMP
pre_visit_note  TEXT        -- auto-generated by Edge Function
patient_question TEXT
```

---

## 5. Feature Breakdown

### Feature A — Voice-First Proactive Check-Ins

- System initiates scheduled conversations at cultural timings for Indian users:
  - **9 AM** — post-breakfast
  - **1 PM** — post-lunch
  - **8 PM** — post-dinner
- Patient hears: *"Good morning Arthur! How are you feeling today? Any pain or discomfort?"*
- Patient speaks naturally — `speech_to_text` captures audio.
- NLP extracts structured JSON: `{symptom: "chest tight", severity: "high", mood: "low"}`.
- Triage Engine classifies into **Green / Yellow / Red** and triggers appropriate action.
- Full transcript + JSON stored in `check_ins` table.

### Feature B — Smart Report Scanner (OCR)

- Camera UI with a visible bounding box: *"Place the report inside the white square."*
- Audio cue auto-plays to guide elderly users.
- `google_mlkit_text_recognition` performs on-device OCR (free, offline).
- Regex `(\d{2,3})\/(\d{2,3})` extracts BP reading.
- BP data stored in `bp_readings` table.
- **Triage override:** If Systolic BP > 150 → auto-trigger Red Alert regardless of voice report.

### Feature C — Smart Triage Engine (Green / Yellow / Red)

| Level | Trigger Conditions | Automated Action |
|-------|--------------------|-----------------|
| **GREEN** | Reports fine, meds verified, no Red keywords | Log silently. Daily summary to doctor. |
| **YELLOW** | Mild recurring pain (3+ days) OR single missed medication | SMS nudge to caregiver. Re-ping after 10 min if ignored. |
| **RED** | Keywords: *chest tight, shortness of breath, severe bleeding* OR Systolic BP > 150 | Immediate push to top of Doctor Dashboard + urgent SMS to caregiver. |
| **ESCALATION** | Yellow symptom persists for 3 consecutive days | Auto-upgrade to Red. Doctor notified directly. |

### Feature D — Appointment Prep (Pre-Visit Summary)

- **T-24 hours:** Supabase Edge Function cron detects upcoming appointment.
- Morning check-in script changes: *"Good morning Arthur! You see Dr. Chen today at 10 AM. Is there anything specific you want me to note for him?"*
- NLP extracts patient's question.
- Edge Function auto-generates Pre-Visit Summary from `check_ins`, `bp_readings`, `med_verification_log`, and `appointments` tables.
- Doctor sees the last 7-day pain trend, verified med history, and patient's question — before the visit begins.
- **15 minutes saved per consultation.**

### Feature E — Offline Safety Net

- `sqflite` caches patient profile and last 7 check-ins locally on device.
- `flutter_secure_storage` encrypts local offline data.
- If network call fails → triage logic runs locally from cached rules.
- If Red keyword detected offline → `url_launcher` opens pre-filled SMS to caregiver emergency contact, bypassing internet entirely.

### Bonus Feature — Recovery Streak Score (Engagement)

- Gamification layer for long-term adherence.
- Hybrid metric: medication adherence + movement (pedometer/accelerometer) + mood report.
- Visual feedback: animated Recovery Pet or plant that grows with streaks and wilts with missed doses.
- `streak_score` integer field on `patients` table — incremented on each completed Green check-in.
- `lottie` Flutter package for animated visuals.
- Leverages the **Endowment Effect** — patients care for something they've nurtured more than a checklist.

---

## 6. Login Architecture

### Overview

Three distinct login flows sharing one backend database, with completely separate interfaces, permissions, and authentication methods.

| Role | Interface | Login Method | Account Creation | Access Scope |
|------|-----------|-------------|-----------------|-------------|
| **Patient** | Flutter App | 4-digit PIN or Biometric (Face ID / Fingerprint). No email required. | Nurse creates profile at discharge. Patient sets PIN on first launch. | Only their own health data, check-in history, medication reminders, streak score. |
| **Caregiver** | Flutter App | Email + Password. Invite link sent via SMS at discharge. | Nurse enters caregiver email at discharge. Caregiver activates via invite link. | Only their linked patient's data: transcripts, medication status, alert history, video logs. |
| **Doctor** | React Web Dashboard | Google OAuth (institutional email). No separate password. | Hospital admin registers doctor's email once. | All their assigned patients, sorted by risk. Cannot see other doctors' patients. |

### Patient Login — Frictionless by Design

- Nurse creates profile in Admin Console → enters patient phone number.
- System sends SMS: *"Your RecoverAI recovery app is ready. Download here: [link]."*
- Patient opens app → sees: *"Welcome Arthur! Please set a 4-digit PIN."*
- Every future login: PIN or biometric. App auto-loads patient profile.
- Session stays active for **24 hours**. Re-authentication only once per day.

### Caregiver Login — Standard Mobile App

- Nurse enters caregiver name, phone, and email at discharge.
- Caregiver receives SMS invite link → first launch pre-fills email → sets password.
- Account strictly locked to one patient ID via Supabase RLS.
- If doctor assigns new caregiver, old caregiver loses access automatically.

### Doctor Login — Institutional Web Dashboard

- Hospital admin registers doctor's hospital email once (one-time setup).
- Doctor visits web dashboard URL → clicks **"Sign in with Google."**
- Google OAuth handles authentication — no separate password to manage.
- On login, dashboard auto-loads all assigned patients sorted by risk.

### Security & Data Privacy

| Concern | How RecoverAI Handles It |
|---------|--------------------------|
| Patient data access | Row-Level Security (RLS) in Supabase — every query auto-filtered by `user_id`. Caregiver query only returns rows where `patient_id` matches their linked patient. |
| Voice data storage | Voice transcripts stored as text only. Audio recordings NOT stored by default. Avoids large storage costs and privacy concerns. |
| Video logs (optional) | Stored in Supabase Storage with private bucket. Caregivers access via signed URL expiring after 1 hour. |
| HTTPS everywhere | All API calls use HTTPS. Supabase enforces TLS on all connections. |
| Offline data | Local SQLite cache on patient's device stores last 7 check-ins. Encrypted using `flutter_secure_storage`. |

---

## 7. Triage Engine Logic

Write as a single `triage.js` or `triage.py` function.

```js
// triage.js
const RED_KEYWORDS = [
  'chest tight', 'shortness of breath', "can't breathe",
  'severe pain', 'dizzy', 'bleeding', 'fainted', 'chest heavy', 'puffy'
];

const YELLOW_KEYWORDS = [
  'mild pain', 'nausea', 'tired', 'slight fever', 'sore'
];

function triageCheck(symptomJson, recentHistory) {
  const { symptom, severity, systolic_bp } = symptomJson;

  // Rule 1: BP override — always Red if systolic > 150
  if (systolic_bp && systolic_bp > 150) return 'red';

  // Rule 2: Red keywords in symptom string
  if (RED_KEYWORDS.some(kw => symptom.toLowerCase().includes(kw))) return 'red';

  // Rule 3: Escalation — Yellow for 3+ consecutive check-ins → Red
  const recentYellows = recentHistory
    .slice(-3)
    .filter(c => c.triage_status === 'yellow');
  if (recentYellows.length >= 3) return 'red';

  // Rule 4: Yellow keywords
  if (YELLOW_KEYWORDS.some(kw => symptom.toLowerCase().includes(kw))) return 'yellow';

  return 'green';
}
```

### AI Guardrail — Safety-First Design

> The AI must **NEVER** act as a doctor. It only asks questions and extracts data. The system prompt explicitly prohibits diagnostic or prescriptive statements. All critical decisions are made by the **deterministic, rule-based Triage Engine** — not the LLM. This ensures clinical safety and regulatory compliance.

System prompt for the NLP layer:
```
You are a data collector only. Your job is to extract structured health data from patient speech.
Never suggest treatments, diagnoses, or medications.
Only ask how the patient feels. Never give medical advice.
Respond only with valid JSON: {symptom, severity, mood, medications_taken}.
```

---

## 8. Data Flow — Core Loop

```
1. Push Notification fires at cultural check-in time (9 AM / 1 PM / 8 PM)
       ↓
2. Patient taps "TAP TO SPEAK" → speech_to_text captures audio
       ↓
3. NLP Layer (Gemma-2B or regex fallback) → structured JSON
       {symptom: "chest tight", severity: "high", mood: "low"}
       ↓
4. Triage Engine evaluates JSON → assigns Green / Yellow / Red status
       ↓
5. Supabase stores: full transcript + JSON + status in check_ins table
       ↓
6. Supabase real-time subscription → Doctor Dashboard updates live (no refresh)
       ↓
7. If RED:
      → Patient jumps to top of Doctor's patient list with flashing Red badge
      → Twilio SMS fires to caregiver emergency contact
      → If offline: url_launcher triggers pre-filled device SMS
```

### OCR Data Sub-Flow

```
Patient / Caregiver photographs BP slip
       ↓
Flutter camera + bounding box UI
       ↓
Google ML Kit extracts text (on-device, offline)
       ↓
Regex (\d{2,3})\/(\d{2,3}) extracts systolic/diastolic
       ↓
POST to Supabase → bp_readings table
       ↓
If systolic > 150 → Red Alert fires (overrides all voice data)
```

---

## 9. Dashboard Designs

### 9.1 Patient App — Flutter (Mobile)

| Screen / Element | Purpose |
|-----------------|---------|
| **Home — TAP TO SPEAK** | Full-screen, one-tap voice check-in. Primary daily interaction. |
| **Status indicator** | Today's triage status as colored pill (Green / Yellow / Red) after check-in processes. |
| **Medication checklist** | Today's schedule from patient profile. Tick marks appear after OCR verification. |
| **Camera / Scanner button** | Opens BP scanner screen. Bounding box overlay + audio guidance. Auto-submits BP. |
| **Recovery Streak counter** | Progress bar showing consecutive Green days. Gamification layer. |
| **Next appointment card** | Date and time of next visit. Activates Appointment Prep mode T-24 hours. |

### 9.2 Caregiver Dashboard — Flutter (Mobile)

| Section | Purpose |
|---------|---------|
| **Current status card** | Prominent colored card with current triage status and last check-in time. |
| **Alert banner** | Appears only on Yellow/Red. Shows exact triggered phrase or BP reading. |
| **Last voice transcript** | Full text of most recent check-in so caregiver can read patient's exact words. |
| **Medication verification panel** | Green check (OCR verified), grey circle (pending), or red X (missed). |
| **7-day history timeline** | Scrollable chronological log of all alerts and check-ins over the past week. |
| **Quick actions row** | Tap-to-call patient, view video logs, message doctor — all in one tap. |

### 9.3 Doctor Dashboard — React (Web)

| Section | Purpose |
|---------|---------|
| **Summary stats bar** | 4 metric cards: total patients, Red count, Yellow count, overall medication adherence %. Full picture in 3 seconds. |
| **Risk-sorted patient list** | All patients sorted Red → Yellow → Green. Each row: name, surgery, days since discharge, status badge, last BP, last check-in time. |
| **Patient detail panel** | 7-day pain/symptom bar chart, full medication adherence breakdown, BP trend, complete voice transcript log with timestamps. |
| **Pre-Visit Summary card** | Appears T-24 hours before appointment. Auto-generated summary + patient's specific question. |
| **Red Alert log** | All Red Alerts, trigger cause, time, and caregiver acknowledgment status. |
| **Patient profile (admin)** | Update medications, surgery notes, appointment dates, link/unlink caregiver. |

---

## 10. Implementation Plan (48-Hour Sprint)

### Phase 1 — Foundation (Hours 1–6)

**Step 1 — Supabase Database Setup**
- Create Supabase project (free tier).
- Define tables: `patients`, `check_ins`, `alerts`, `medications`, `appointments`, `bp_readings`, `med_verification_log`.
- Enable Row-Level Security (RLS) on all tables.
- Pre-seed a demo patient profile (Arthur, post-CABG surgery, 7 days of historical check-ins).

**Step 2 — Triage Engine**
- Write `triage.js` function that accepts symptom JSON and returns `green | yellow | red`.
- Define Red keywords list, Yellow keywords list.
- Implement BP override rule: `if systolic_bp > 150 → return 'red'`.
- Implement escalation rule: 3 consecutive Yellow check-ins → upgrade to Red.
- Test with 5 mock JSON inputs covering each status.

---

### Phase 2 — Patient Interface (Hours 6–18)

**Step 3 — Voice Check-In Screen (Flutter)**
- Single-screen Flutter app: full-screen background, patient name at top, one giant **"TAP TO SPEAK"** button.
- On tap: `speech_to_text` plugin captures voice. Display transcript in real-time below button.
- On stop: POST transcript to Supabase triage endpoint. Show status (Green circle / Yellow triangle / Red alert icon).
- Play audio cue on screen load: *"Hello Arthur! How are you feeling today?"*

**Step 4 — OCR Smart Report Scanner (Flutter)**
- Secondary camera screen with `flutter_camera`. Overlay white rectangle (bounding box) using `Stack` widget.
- Integrate `google_mlkit_text_recognition`. On capture, extract text from bounding box region.
- Run regex `(\d{2,3})\/(\d{2,3})` to extract systolic/diastolic numbers.
- POST extracted numbers to triage endpoint. If systolic > 150 → Red Alert fires automatically.

---

### Phase 3 — Dashboard (Hours 12–24)

**Step 5 — Doctor / Caregiver Dashboard (React)**
- Single React dashboard with two views toggled by URL param (`?role=doctor` or `?role=caregiver`).
- **Doctor View:** Patient list sorted by `triage_status` (Red first). Each row: Name, Surgery Type, Last Check-In, Status badge, BP reading.
- **Caregiver View:** Single patient card. Last voice transcript. Medication verification status. Video log thumbnails.
- Use Supabase real-time subscriptions so dashboard updates live without page refresh.

**Step 6 — Appointment Prep Module**
- Add `next_appointment` column to `patients` table.
- Write Supabase Edge Function (cron): query patients where `next_appointment` is within 24 hours.
- Flag those patients: morning check-in script switches to appointment prep mode.
- Extract patient's question and display in Doctor Dashboard as **"Pre-Visit Note"** card.

---

### Phase 4 — Safety Net & Polish (Hours 24–36)

**Step 7 — Offline Fallback**
- `sqflite` for local SQLite caching of patient profile and last 7 check-ins.
- If network call fails, run triage logic locally from cached rules.
- If Red keyword detected offline: `url_launcher` opens pre-filled SMS to caregiver emergency contact.

**Step 8 — SMS Alerts**
- Twilio Free Trial (100 free SMS). Fire on RED status: *"URGENT: Arthur's recovery app has flagged a critical symptom. Please check in immediately."*
- Fallback: `url_launcher` for zero-cost, zero-signup offline SMS triggering.

**Step 9 — Recovery Streak Score (Bonus)**
- `streak_score` integer field on `patients` table. Increment on each Green check-in.
- Display in Patient App as a progress bar or animated emoji pet via `lottie` package.

---

### Phase 5 — Demo Prep (Hours 36–48)

**Step 10 — Live Demo Setup**
- Pre-load Arthur's profile with 7 days of historical check-in data (mix of Green/Yellow) to show trend graphs.
- Prepare a physical prop: write *"Blood Pressure: 160/100"* on a paper slip for OCR live demo.
- Pre-record a 30-second audio clip of voice check-in as a fallback if mic fails.
- Test OCR in actual demo room lighting conditions beforehand.

---

## 11. Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| OCR fails on demo paper due to lighting | Pre-write "Blood Pressure: 160/100" in large clear print. Test room lighting. Have hardcoded fallback that auto-reads the value for demo. |
| Voice recognition fails on noisy floor | Use pre-recorded audio file as input. Or type phrase directly. Show transcript extraction as proof of concept. |
| Alert fatigue from too many Yellow pings | Impose minimum 2-hour cooldown between repeated Yellow alerts for the same patient. Caregiver can snooze for 4 hours. |
| AI gives medical advice (safety risk) | Strict system prompt: *"You are a data collector only. Never suggest treatments, diagnoses, or medications."* |
| Internet goes down during demo | All critical flows (voice capture, triage, OCR) are on-device. Dashboard is the only component requiring internet. |

---

## What Makes RecoverAI Stand Out

- **Voice-First for elderly users** — eliminates the biggest adoption barrier.
- **Cultural routine timing** (9 AM / 1 PM / 8 PM, not hospital clocks) — dramatically increases response rates.
- **OCR + Voice cross-referencing** — objective BP data overrides subjective "I feel fine" reports.
- **Recurrence escalation** (Yellow → Red after 3 consecutive days) — a clinically intelligent insight most teams will miss.
- **Pre-Visit Summary** — saves the doctor 15 minutes per consultation, making hospital adoption realistic.
- **Entire stack runs on free tiers** — zero infrastructure cost for the demo.
- **Deterministic triage** (not a black-box LLM) — clinically safe and explainable to judges.

---

*RecoverAI — HC-01 | Full Build Reference | Free Stack Only | 48-Hour Feasible*
