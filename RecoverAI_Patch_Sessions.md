# RecoverAI — Fix & Patch Sessions
### For code already built by Antigravity. These prompts ADD logic to existing shells.

---

> **How to use this file:**
> You already have the UI shells built.
> Each session below PATCHES your existing code — it does not rebuild from scratch.
> Paste the SETUP BLOCK first, then the session prompt.
> Do them in order — each one depends on the previous.

---

## SETUP BLOCK — Paste This at the Start of EVERY Session

```
You are patching an existing RecoverAI Flutter + React project.
DO NOT rebuild from scratch.
DO NOT delete existing UI or styling.
ONLY add the missing logic to what already exists.
Read the existing files first before writing anything.
Always give me complete updated files — not diffs, not partial code.

My Supabase URL: [paste your URL here]
My Supabase Anon Key: [paste your key here]
```

---

## PATCH SESSION 1 — Wire Supabase to the Project

**What this fixes:** Nothing is connected to the database yet.

```
[Paste SETUP BLOCK first]

Look at my existing project files.
I need to wire Supabase into the project properly.

Do these things:

1. Check pubspec.yaml — if supabase_flutter is not there, add it:
   supabase_flutter: ^2.0.0

2. Check main.dart — if Supabase is not initialized, add this
   inside the main() function before runApp():

   await Supabase.initialize(
     url: 'YOUR_SUPABASE_URL',
     anonKey: 'YOUR_SUPABASE_ANON_KEY',
   );

   Add WidgetsFlutterBinding.ensureInitialized(); before it.
   Add the import: import 'package:supabase_flutter/supabase_flutter.dart';

3. Create a new file: lib/services/supabase_service.dart
   This file must have a SupabaseService class with these functions:

   a. Future<void> saveCheckin(String patientId, String transcript,
      Map symptomJson, String triageStatus)
      → insert into check_ins table

   b. Future<List<Map>> getRecentCheckins(String patientId)
      → fetch last 7 check-ins ordered by timestamp desc

   c. Future<void> saveBpReading(String patientId, int systolic, int diastolic)
      → insert into bp_readings table

   d. Future<void> saveAlert(String patientId, String alertType,
      String triggerReason, String triageStatus)
      → insert into alerts table

   e. Stream<List<Map>> watchAlerts(String patientId)
      → Supabase real-time subscription on alerts table
      → filtered by patient_id
      → returns Stream so UI can listen and auto-update

   f. Future<Map?> getPatient(String patientId)
      → fetch single patient row from patients table

   g. Future<void> updateStreak(String patientId, int score)
      → update streak_score in patients table

   Use this hardcoded demo patient ID for now (we will make it dynamic later):
   const String demoPatientId = 'arthur-demo-001';

4. In the Supabase SQL editor, run this to insert Arthur's demo profile:
   (Print these SQL instructions as a comment at the top of supabase_service.dart)

   insert into patients (id, name, age, phone, surgery_type, streak_score)
   values ('arthur-demo-001', 'Arthur Kumar', 72,
           '+919800000000', 'Post-CABG (Heart Bypass)', 5)
   on conflict (id) do nothing;

Give me the complete updated main.dart and the complete new supabase_service.dart.
```

---

## PATCH SESSION 2 — Add Triage Engine

**What this fixes:** The voice button captures speech but does nothing with it.

```
[Paste SETUP BLOCK first]

Look at my existing voice check-in screen.
The speech_to_text is capturing audio but the transcript is not being analyzed.
I need to add a triage engine.

Do these things:

1. Create a new file: lib/services/triage_engine.dart
   with this exact logic:

   RED KEYWORDS: chest tight, shortness of breath, can't breathe,
   severe pain, dizzy, bleeding, fainted, chest heavy, puffy, breathless

   YELLOW KEYWORDS: mild pain, nausea, tired, slight fever, sore,
   uncomfortable, a little pain, slight pain

   Rules in priority order:
   - If systolic > 150 → RED (only when BP is passed in)
   - If any Red keyword in transcript (case insensitive) → RED
   - If last 3 statuses from recentStatuses list are all 'yellow' → RED
   - If any Yellow keyword → YELLOW
   - Otherwise → GREEN

   Function 1:
   String classify(String transcript,
     {int? systolicBp, List<String> recentStatuses = const []})
   → returns 'green', 'yellow', or 'red'

   Function 2:
   Map<String, dynamic> extractSymptomJson(String transcript)
   → returns:
   {
     "symptom": first matched keyword or "none",
     "severity": "high" if red, "low" if yellow, "none" if green,
     "mood": "low" if transcript contains sad/pain/bad words, "good" otherwise,
     "medications_taken": true
   }

   Add this safety comment at the top:
   // SAFETY: This engine never suggests treatments or diagnoses.
   // It only classifies symptoms for human review.

2. Now find my existing voice check-in screen file.
   After the user stops speaking and we have a transcript:

   a. Import and call TriageEngine().classify(transcript)
   b. Import and call TriageEngine().extractSymptomJson(transcript)
   c. Import and call SupabaseService().saveCheckin(
        demoPatientId, transcript, symptomJson, triageStatus)
   d. Update the UI status indicator:
      - If 'green': show green colored card "You're doing great today! ✅"
      - If 'yellow': show yellow card "Thanks for sharing. Elena has been notified 💛"
      - If 'red': show red card "Please call your doctor now. Elena is being alerted 🚨"
   e. If status is 'red': call SupabaseService().saveAlert(
        demoPatientId, 'voice_keyword', transcript, 'red')

Do NOT touch any existing UI styling or layout.
Only add the logic after the transcript is captured.
Give me the complete triage_engine.dart and the complete updated voice check-in screen.
```

---

## PATCH SESSION 3 — Make Caregiver Dashboard Live

**What this fixes:** Caregiver screen shows fake/hardcoded data. Make it pull real data.

```
[Paste SETUP BLOCK first]

Look at my existing caregiver dashboard screen.
It currently shows static/hardcoded data.
I need it to show real data from Supabase and update in real time.

Do these things:

1. Find the caregiver dashboard file.
   Replace all hardcoded/static data with real Supabase calls:

   a. On screen load (initState):
      - Call SupabaseService().getPatient(demoPatientId)
      - Display real patient name, surgery type
      - Call SupabaseService().getRecentCheckins(demoPatientId)
      - Show the most recent transcript in the "Last voice transcript" section
      - Set the status card color based on the most recent check-in triage_status

   b. Add a real-time listener:
      - Call SupabaseService().watchAlerts(demoPatientId)
      - Listen to the stream with a StreamBuilder or StreamSubscription
      - When a new alert arrives:
        → Update the top status card to Red immediately
        → Show a flashing red border around the card
        → Show the trigger reason text inside the card

   c. For the 7-day timeline dots:
      - Load last 7 check-ins from Supabase
      - Show a colored dot per day:
        green dot for 'green', yellow for 'yellow', red for 'red'
        grey dot for days with no check-in

   d. For the medications section:
      - For now, show a hardcoded list of Arthur's 3 medications
        (Aspirin 75mg 8AM, Metoprolol 25mg 8AM, Atorvastatin 40mg 9PM)
      - Mark all as "pending" with grey circles
      - We will wire OCR verification in a later session

   e. Add a pull-to-refresh (RefreshIndicator widget) that reloads all data

2. Add a loading state — show a CircularProgressIndicator while data loads.
   Show an error message if Supabase call fails.

Do NOT change any existing colors, fonts, or layout structure.
Only replace static data with real data.
Give me the complete updated caregiver dashboard file.
```

---

## PATCH SESSION 4 — Make Doctor Website Live

**What this fixes:** The React doctor dashboard is static HTML. Connect it to Supabase.

```
[Paste SETUP BLOCK first]

Look at my existing doctor dashboard HTML file.
It is currently static — all data is hardcoded.
I need to connect it to Supabase and make it update in real time.

Do these things to the existing HTML file:

1. Add Supabase JS client in the <head>:
   <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>

2. Initialize Supabase at the top of the <script> section:
   const supabase = window.supabase.createClient('YOUR_URL', 'YOUR_KEY')

3. Replace all hardcoded patient data with a loadPatients() function:
   - Query patients table: select * from patients
   - For each patient, also query their most recent check-in:
     select triage_status, transcript, timestamp from check_ins
     where patient_id = [id] order by timestamp desc limit 1
   - Sort results: Red patients first, then Yellow, then Green
   - Render each patient row dynamically using innerHTML or DOM manipulation
   - Keep the same visual design — only replace the data source

4. Add real-time subscription:
   supabase
     .channel('alerts-channel')
     .on('postgres_changes',
       { event: 'INSERT', schema: 'public', table: 'alerts' },
       (payload) => {
         // When a new alert comes in:
         // Find the patient row in the DOM by patient_id
         // Move that row to the top of the list
         // Add a red pulsing border class to it
         // Update the status badge to Red
       }
     )
     .subscribe()

5. For the patient expand/detail view (when a row is clicked):
   - Load full check-in history for that patient
   - Load BP readings for that patient
   - Render the 7-day chart using the existing chart library already in the file
   - Show all voice transcripts in a scrollable list with timestamps

6. Add a loading spinner that shows while data is being fetched.
   Show "No patients found" if the query returns empty.

7. Add a manual refresh button (top right corner) that re-runs loadPatients().

Do NOT change any existing CSS, colors, layout, or visual design.
Only replace static data with live Supabase data.
Give me the complete updated HTML file.
```

---

## PATCH SESSION 5 — Add OCR to Patient App

**What this fixes:** The OCR scanner button exists but does nothing.

```
[Paste SETUP BLOCK first]

Look at my existing patient app.
There is a camera/scanner button but it does not actually scan anything.
I need to add real OCR functionality.

Do these things:

1. Check pubspec.yaml — add these if not present:
   camera: ^0.10.5
   google_mlkit_text_recognition: ^0.11.0
   permission_handler: ^11.0.0

2. Find the OCR screen file (or the camera button handler).
   Replace the placeholder with a real OCR screen.
   If there is no OCR screen file, create lib/screens/ocr_scanner_screen.dart

   The screen must:
   a. Show camera preview as full background
   b. Overlay a white rectangle in the center (280x160px) as a guide box
      Label above it: "Place your BP slip inside the box"
   c. Show a capture button at the bottom
   d. On capture:
      - Take photo
      - Run google_mlkit_text_recognition on the image
      - Search extracted text for BP pattern using regex: (\d{2,3})\/(\d{2,3})
      - If found: show "Reading found: [systolic]/[diastolic]" in a card
        Then call SupabaseService().saveBpReading(demoPatientId, systolic, diastolic)
        If systolic > 150: show red warning card "⚠️ High BP detected. Doctor has been notified."
        Also call SupabaseService().saveAlert(demoPatientId, 'bp_threshold',
          'Systolic BP: [value]', 'red')
      - If not found: show "Could not read slip. Try again in better lighting."
        Also show two text fields for manual entry of systolic and diastolic
        with a Submit button that calls saveBpReading manually

3. Add camera and storage permissions to AndroidManifest.xml:
   <uses-permission android:name="android.permission.CAMERA"/>

4. Navigate to OcrScannerScreen when the camera button is tapped
   in the voice check-in screen.

Do NOT change any existing voice check-in UI.
Give me all updated/new complete files.
```

---

## PATCH SESSION 6 — Add Offline Safety Net

**What this fixes:** App crashes or freezes when there is no internet.

```
[Paste SETUP BLOCK first]

Look at my existing Flutter project.
Currently if internet is lost, the app will crash or show errors.
I need to add an offline safety net.

Do these things:

1. Check pubspec.yaml — add if not present:
   sqflite: ^2.3.0
   flutter_secure_storage: ^9.0.0
   url_launcher: ^6.2.0
   connectivity_plus: ^5.0.0

2. Create lib/services/offline_cache.dart with:

   a. initDb() — creates local SQLite database with:
      Table cached_patient: id, name, caregiver_phone, surgery_type
      Table cached_checkins: id, transcript, triage_status, timestamp

   b. cachePatient(Map patient) — saves patient data locally
      Encrypts caregiver_phone using flutter_secure_storage

   c. cacheCheckin(String transcript, String status) — saves locally
      Keeps only last 7 entries (deletes older ones)

   d. getCachedStatuses() — returns list of last 3 triage statuses
      Used by triage engine when offline

   e. isOnline() — returns bool
      Uses connectivity_plus to check network status

   f. sendOfflineSmsAlert(String patientName) — emergency offline alert
      Gets caregiver_phone from flutter_secure_storage
      Uses url_launcher to open:
      sms:[phone]?body=URGENT: [patientName] has flagged a critical symptom. Please check immediately.

3. In the voice check-in screen, wrap the Supabase save call:
   - Call isOnline() before saving
   - If online: save to Supabase as normal (existing code)
   - If offline:
     → save to local cache using cacheCheckin()
     → if triage_status is 'red': call sendOfflineSmsAlert()
     → show a banner: "No internet — data saved locally. Will sync when reconnected."

4. In main.dart initState, call:
   - OfflineCache().initDb() to set up local database on app start
   - OfflineCache().cachePatient() with Arthur's demo data as fallback

Do NOT change any existing UI.
Give me the complete offline_cache.dart and updated voice check-in screen.
```

---

## PATCH SESSION 7 — Add Real SMS Alerts

**What this fixes:** Red alerts show on screen but no SMS is actually sent.

```
[Paste SETUP BLOCK first]

Look at my existing project.
When triage returns RED, nothing actually alerts the caregiver externally.
I need to add real Twilio SMS alerts.

Do these things:

1. Create lib/services/sms_service.dart with:

   a. sendRedAlert(String patientName, String caregiverPhone, String reason)
      → POST to Twilio REST API:
        URL: https://api.twilio.com/2010-04-01/Accounts/[ACCOUNT_SID]/Messages.json
        Method: POST
        Headers: Authorization: Basic [base64(accountSid:authToken)]
        Body (form-encoded):
          To=[caregiverPhone]
          From=[twilioNumber]
          Body=URGENT: [patientName] has flagged a critical symptom: [reason]. Please check in immediately.
      → If Twilio fails for any reason:
        fall back to url_launcher SMS:
        sms:[caregiverPhone]?body=URGENT: [patientName] needs your attention now.

   Use these demo values (replace with real Twilio free trial values):
   const accountSid = 'YOUR_TWILIO_ACCOUNT_SID';
   const authToken = 'YOUR_TWILIO_AUTH_TOKEN';
   const twilioNumber = 'YOUR_TWILIO_NUMBER';
   const demoCaregiverPhone = '+91YOUR_TEST_PHONE'; // your own phone for demo

2. In the voice check-in screen:
   Find where triage_status == 'red' is handled.
   Add this call there:
   SmsService().sendRedAlert('Arthur Kumar', demoCaregiverPhone, transcript)

3. In the caregiver dashboard:
   The real-time Supabase stream from Patch Session 3 already listens for alerts.
   Now also add a local push notification when a Red alert arrives:
   Use flutter_local_notifications package if available, otherwise just show
   a SnackBar with red background: "⚠️ New Red Alert for Arthur"

4. Add a comment block at the top of sms_service.dart:
   // TWILIO SETUP INSTRUCTIONS:
   // 1. Go to twilio.com → sign up free
   // 2. Get a free trial phone number
   // 3. Copy Account SID, Auth Token, and your Twilio number
   // 4. Paste them into the constants above
   // 5. Verify your personal phone number in Twilio console
   //    (free trial only sends to verified numbers)

Give me the complete sms_service.dart and updated voice check-in screen.
```

---

## PATCH SESSION 8 — Add Demo Mode

**What this fixes:** Voice recognition might fail on the noisy hackathon floor.

```
[Paste SETUP BLOCK first]

Look at my existing voice check-in screen.
I need to add a hidden Demo Mode for the hackathon presentation.

Do these things:

1. In the voice check-in screen, add a hidden Demo Mode toggle:
   - A secret tap gesture: if the patient name text at the top is tapped
     5 times quickly → Demo Mode activates
   - Show a small "DEMO" badge in the top right corner when active
   - In Demo Mode: the TAP TO SPEAK button still animates and shows the mic
     but instead of actually recording, after 3 seconds it auto-fills:
     "I feel a bit heavy in my chest today and my legs look a little puffy"
   - Then runs the full triage pipeline normally with that hardcoded transcript
   - This triggers RED status and shows the full alert flow
   - Tapping the name 5 times again deactivates Demo Mode

2. Add a Demo Data button visible only in Demo Mode (small grey button, bottom corner):
   "Reset Demo Data" — when tapped:
   - Deletes all check_ins for demoPatientId from Supabase
   - Re-inserts 7 days of fresh mock data (3 green, 1 yellow, 3 green)
   - Re-inserts 2 BP readings (normal values)
   - Shows "Demo data reset ✅"
   This lets you reset between judge presentations.

3. In the OCR scanner screen, add the same Demo Mode check:
   If Demo Mode is active, add a "Use Demo Reading" button:
   → Skips the camera entirely
   → Auto-processes "160/100" as the BP reading
   → Triggers the full Red Alert flow for the BP threshold demo

Do NOT change any existing UI styling.
Do NOT make Demo Mode visible during normal use.
Give me the complete updated voice check-in screen and OCR scanner screen.
```

---

## PATCH SESSION 9 — Add Streak Score Screen

**What this fixes:** The streak screen shows a static number. Make it real.

```
[Paste SETUP BLOCK first]

Look at my existing streak screen (or the streak counter on the home screen).
It currently shows a hardcoded number.
I need to make it pull real data and actually increment.

Do these things:

1. Find the streak screen or streak widget.
   Replace hardcoded streak number with:
   - On load: call SupabaseService().getPatient(demoPatientId)
   - Read streak_score from the patient row
   - Display that number

2. Add streak increment logic to the voice check-in screen:
   After a check-in is saved and triage_status == 'green':
   - Call SupabaseService().getPatient(demoPatientId)
   - Get current streak_score
   - Add 1 to it
   - Call SupabaseService().updateStreak(demoPatientId, newScore)

   If triage_status == 'red' or 'yellow':
   - Reset streak to 0
   - Call SupabaseService().updateStreak(demoPatientId, 0)

3. On the streak screen, below the number, show:
   - Last 7 days as colored dots (load from getRecentCheckins)
     Green dot, Yellow dot, Red dot, or Grey dot (no check-in that day)
   - A motivational message based on streak number:
     0-2: "Every day counts. Keep going! 💪"
     3-6: "You're building a great habit! 🌱"
     7-13: "One week strong! Arthur is proud. 🌿"
     14+: "Incredible recovery! 🌳"

4. If the streak screen has a Lottie animation placeholder:
   Replace with a working Lottie animation.
   Use this free Lottie URL for a plant growth animation:
   https://assets5.lottiefiles.com/packages/lf20_ysrn2iwp.json
   The animation should play faster when streak is higher.

Give me the complete updated streak screen and voice check-in screen.
```

---

## PATCH SESSION 10 — Final Wiring + Test Everything

**What this fixes:** Everything built separately — now connect all the pieces together.

```
[Paste SETUP BLOCK first]

Look at all my existing files.
I need to do a final wiring pass to make sure everything connects.

Check and fix each of these:

1. MAIN.DAT / APP ENTRY
   - Supabase is initialized before runApp() ✓
   - OfflineCache().initDb() is called on startup ✓
   - The login/role selection screen shows these 3 options:
     [Patient App] → VoiceCheckinScreen
     [Caregiver App] → CaregiverDashboard
     [Doctor Web] → opens doctor dashboard HTML in a WebView or external browser
   If not, fix main.dart to add this simple role selector screen.

2. NAVIGATION
   - VoiceCheckinScreen has bottom buttons to OCR scanner and Streak screen ✓
   - CaregiverDashboard has a back button ✓
   - All screens have a way to get back to the role selector ✓

3. DEMO PATIENT ID
   - Every screen that references demoPatientId is using the same value ✓
   - That value is 'arthur-demo-001' everywhere ✓
   If different IDs are used in different files, standardize them all.

4. ERROR HANDLING
   - Every Supabase call is wrapped in try/catch ✓
   - If a call fails, a readable error message shows on screen ✓
   - App does not crash if Supabase is slow ✓

5. LOADING STATES
   - All screens show a CircularProgressIndicator while loading data ✓
   - Loading indicator disappears after data loads ✓

6. DOCTOR DASHBOARD HTML
   - Open the HTML file and confirm it loads patient data from Supabase ✓
   - Confirm real-time subscription is active ✓
   - If not, re-apply Patch Session 4 fixes ✓

7. FINAL TEST FLOW (verify this works end to end):
   a. Open patient app → select Patient role
   b. Tap TAP TO SPEAK (or use Demo Mode)
   c. Speak/type: "I feel heavy in my chest"
   d. App shows RED status
   e. Open doctor dashboard HTML in browser
   f. Arthur should appear at top with Red badge — without refreshing
   g. Open caregiver dashboard → should show Red alert card
   h. Twilio SMS should arrive on test phone

Fix whatever is broken to make this flow work completely.
Give me all files that need updating.
```

---

## QUICK REFERENCE — What Each Session Fixes

| Session | Fixes | Time |
|---------|-------|------|
| Patch 1 | Nothing saves to database | 20 min |
| Patch 2 | Voice button does nothing after recording | 20 min |
| Patch 3 | Caregiver screen shows fake data | 25 min |
| Patch 4 | Doctor website is static | 30 min |
| Patch 5 | OCR button does nothing | 30 min |
| Patch 6 | App crashes without internet | 20 min |
| Patch 7 | No SMS actually sent on Red | 20 min |
| Patch 8 | Voice fails on noisy demo floor | 15 min |
| Patch 9 | Streak shows hardcoded number | 15 min |
| Patch 10 | Everything works separately but not together | 30 min |

**Total: ~3.5 hours to go from shells → fully working app**

---

*RecoverAI · Patch Sessions · Fix existing Antigravity build · 0 rewrites needed*
