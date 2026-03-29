# RecoverAI — Setup Guide

## Step 1: Create Supabase Project (Free)

1. Go to https://supabase.com → New Project
2. Copy your **Project URL** and **anon key** from Settings → API
3. Paste them into the `.env` files (see below)

## Step 2: Run Database Migrations

In the Supabase SQL Editor (https://supabase.com/dashboard → SQL Editor), run these files **in order**:

1. `backend/supabase/migrations/001_initial_schema.sql` — Creates all tables + RLS
2. `backend/supabase/migrations/002_seed_demo_data.sql` — Demo data (Arthur, Elena, Dr. Chen)
3. `backend/supabase/migrations/003_streak_function.sql` — Streak auto-management

## Step 3: Set Environment Variables

Replace placeholder values in all 3 `.env` files:

**react_dashboard/.env**
```
REACT_APP_SUPABASE_URL=https://YOUR-PROJECT.supabase.co
REACT_APP_SUPABASE_ANON_KEY=YOUR-ANON-KEY
```

**flutter_app/.env**
```
SUPABASE_URL=https://YOUR-PROJECT.supabase.co
SUPABASE_ANON_KEY=YOUR-ANON-KEY
```

**backend/.env** (only needed for SMS alerts)
```
SUPABASE_URL=https://YOUR-PROJECT.supabase.co
SUPABASE_SERVICE_ROLE_KEY=YOUR-SERVICE-ROLE-KEY
TWILIO_ACCOUNT_SID=your-twilio-sid
TWILIO_AUTH_TOKEN=your-twilio-auth-token
TWILIO_PHONE_NUMBER=+1234567890
```

## Step 4: Start React Dashboard

```bash
cd react_dashboard
npm install
npm start
```
Opens at http://localhost:3000

## Step 5: Start Flutter App

```bash
cd flutter_app
flutter pub get
flutter run
```

## Demo Logins

| Role | How to login |
|------|-------------|
| Patient | Any 4-digit PIN (demo mode) |
| Caregiver | Any email + password (demo mode) |
| Doctor | Click "Sign in with Google" (demo mode skips auth) |
