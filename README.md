# RecoverAI - Intelligent Post-Discharge Care Companion

A voice-first healthcare platform that proactively monitors elderly patients after surgery through AI-powered check-ins, symptom triage, and real-time alerts.

## The Problem
Post-surgical patients (especially elderly) often miss warning signs at home. Caregivers lack visibility. Doctors get no data between appointments.

## The Solution
RecoverAI provides 3 connected interfaces:

### Patient App (Flutter Mobile)
- **Voice Check-In**: Tap to speak, describe symptoms in natural language
- **AI Triage Engine**: On-device NLP classifies symptoms as GREEN/YELLOW/RED
- **BP Scanner**: Voice or manual blood pressure entry
- **Medication Tracker**: Tickable daily medication checklist with progress bar
- **Streak System**: Gamified daily check-in engagement
- **Offline Mode**: SQLite cache + SMS alerts when internet is unavailable

### Caregiver App (Flutter Mobile)
- **Real-time Alerts**: Supabase real-time subscription for instant RED alert notifications
- **Patient Dashboard**: 7-day check-in history, BP trends, medication status
- **Doctor Prescriptions**: View prescriptions written by the doctor
- **Emergency Call**: One-tap call to patient

### Doctor Dashboard (React Web)
- **3-Column Layout**: Patient list | Patient detail | Decision support panel
- **Risk-Sorted Patient List**: RED patients surface to top automatically
- **AI Clinical Insights**: Auto-generated trend analysis per patient
- **Prescription System**: Write and manage prescriptions (saved to Supabase)
- **Clinical Notes**: Categorized doctor notes (Observation, Follow-up, Concern, etc.)
- **Alert Management**: Acknowledge, filter (pending/resolved), view patient
- **Real-time Updates**: Dashboard auto-refreshes on new check-ins and alerts
- **Schedule Management**: Create and manage appointments

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Patient App | Flutter + Dart |
| Caregiver App | Flutter + Dart |
| Doctor Dashboard | React + Recharts |
| Database | Supabase (PostgreSQL) |
| Real-time | Supabase Realtime (WebSocket) |
| Voice Input | speech_to_text (Flutter) |
| Triage Engine | Rule-based NLP (on-device) |
| Offline Cache | SQLite + flutter_secure_storage |
| SMS Alerts | Twilio API + url_launcher fallback |
| BP Entry | Voice parsing + manual input |

## Architecture

```
Patient (Flutter)  -->  Supabase  <--  Doctor Dashboard (React)
       |                   |                    |
  Voice Check-in      PostgreSQL          Real-time Alerts
  BP Reading          Real-time            AI Insights
  Medications         WebSocket         Prescriptions
       |                   |                    |
  Triage Engine     check_ins table      3-Column Layout
  (on-device)       bp_readings         Charts + Notes
                    alerts
                    prescriptions
                    doctor_notes
                         |
Caregiver (Flutter) <----+
  Alert Dashboard
  Prescriptions View
```

## Database Tables (Supabase)

- `patients` - Patient profiles with streak_score
- `doctors` - Doctor profiles
- `caregivers` - Caregiver profiles
- `check_ins` - Voice check-in transcripts + triage status
- `bp_readings` - Blood pressure readings
- `alerts` - RED/YELLOW alerts with acknowledge status
- `medications` - Pharmacy medication schedules
- `prescriptions` - Doctor-written prescriptions
- `doctor_notes` - Clinical notes by doctors
- `appointments` - Scheduled appointments
- `med_verification_log` - Medication taken confirmations

## Setup

### Flutter App
```bash
cd flutter_app
flutter pub get
flutter run          # debug on connected device
flutter build apk    # release APK for Android
```

### React Dashboard
```bash
cd react_dashboard
npm install
npm start            # http://localhost:3000
```

### Supabase
Create a project at supabase.com, then update the credentials in:
- `flutter_app/lib/main.dart` (SUPABASE_URL, SUPABASE_ANON_KEY)
- `react_dashboard/.env` (REACT_APP_SUPABASE_URL, REACT_APP_SUPABASE_ANON_KEY)

## Demo Mode
The app includes a hidden Demo Mode for hackathon presentations:
- **Activate**: Tap patient name 5 times quickly on the Voice Check-In screen
- **Demo Voice**: Auto-fills a RED-trigger transcript after 3 seconds
- **Demo BP**: "Use Demo Reading (160/100)" button on BP screen
- **Reset Demo Data**: Resets all check-ins to clean state between demos

## Key Features

- **Safety First**: Triage engine NEVER suggests treatments or diagnoses. Only classifies for human review.
- **Offline Resilient**: Check-ins cached locally, SMS fallback for RED alerts
- **Real-time**: Doctor dashboard updates instantly when patients check in
- **Voice-First**: Designed for elderly patients who struggle with typing
- **AI Insights**: Auto-generated clinical summaries (BP trends, escalation risks, adherence patterns)

## Team
Built for hackathon demonstration of AI-assisted post-discharge care.

## License
MIT
