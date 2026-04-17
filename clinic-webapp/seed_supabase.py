#!/usr/bin/env python3
"""
Seed Supabase tables (patients, alerts, devices) with sample data.
Also ensures the tables exist with the correct schema and have
RLS policies + realtime enabled.

Run:  python seed_supabase.py
"""
import urllib.request
import urllib.error
import json

# ── Supabase credentials (service role key bypasses RLS) ────────────────────
SUPABASE_URL = "https://cnktjnchyyttjvslvdpr.supabase.co"
SERVICE_KEY = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9."
    "eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNua3RqbmNoeXl0dGp2c2x2ZHByIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NTg3OTIzOSwiZXhwIjoyMDkxNDU1MjM5fQ."
    "biMSwjREi9j0K91D4yi_bLzfSN2lsjfmKPY7HYiC370"
)

# ── SQL to create / fix tables ──────────────────────────────────────────────
SETUP_SQL = r"""
-- ═══════ PATIENTS ═══════
CREATE TABLE IF NOT EXISTS public.patients (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL DEFAULT '',
  age INTEGER DEFAULT 0,
  condition TEXT DEFAULT '',
  risk_level TEXT DEFAULT 'Medium',
  device_status TEXT DEFAULT 'Offline',
  last_sync TEXT DEFAULT 'N/A',
  device_id TEXT DEFAULT '',
  heart_rate INTEGER DEFAULT 75,
  spo2 INTEGER DEFAULT 97,
  temperature DOUBLE PRECISION DEFAULT 98.2,
  steps INTEGER DEFAULT 0,
  notes TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.patients ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='patients' AND policyname='patients_all') THEN
    CREATE POLICY patients_all ON public.patients FOR ALL TO authenticated USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='patients' AND policyname='patients_anon_read') THEN
    CREATE POLICY patients_anon_read ON public.patients FOR SELECT TO anon USING (true);
  END IF;
END $$;
ALTER TABLE public.patients REPLICA IDENTITY FULL;

-- ═══════ ALERTS ═══════
CREATE TABLE IF NOT EXISTS public.alerts (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL DEFAULT '',
  patient TEXT DEFAULT '',
  severity TEXT DEFAULT 'warning',
  status TEXT DEFAULT 'new',
  timestamp TEXT DEFAULT '',
  value TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.alerts ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='alerts' AND policyname='alerts_all') THEN
    CREATE POLICY alerts_all ON public.alerts FOR ALL TO authenticated USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='alerts' AND policyname='alerts_anon_read') THEN
    CREATE POLICY alerts_anon_read ON public.alerts FOR SELECT TO anon USING (true);
  END IF;
END $$;
ALTER TABLE public.alerts REPLICA IDENTITY FULL;

-- ═══════ DEVICES ═══════
CREATE TABLE IF NOT EXISTS public.devices (
  id TEXT PRIMARY KEY,
  patient_name TEXT DEFAULT '',
  status TEXT DEFAULT 'Offline',
  battery INTEGER DEFAULT 100,
  last_sync TEXT DEFAULT 'N/A',
  firmware TEXT DEFAULT 'v2.1.0',
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='devices' AND policyname='devices_all') THEN
    CREATE POLICY devices_all ON public.devices FOR ALL TO authenticated USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='devices' AND policyname='devices_anon_read') THEN
    CREATE POLICY devices_anon_read ON public.devices FOR SELECT TO anon USING (true);
  END IF;
END $$;
ALTER TABLE public.devices REPLICA IDENTITY FULL;

-- ═══════ Enable Realtime ═══════
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.patients;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.alerts;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.devices;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
"""

# ── Sample data ─────────────────────────────────────────────────────────────
PATIENTS = [
    {"id": "P001", "name": "Maria Garcia",    "age": 68, "condition": "Hypertension",   "risk_level": "Critical", "device_status": "Online",  "last_sync": "2 min ago",   "device_id": "DSW-001", "heart_rate": 128, "spo2": 94, "temperature": 98.8, "steps": 1200, "notes": "Monitor closely — BP spikes at night"},
    {"id": "P002", "name": "John Smith",      "age": 72, "condition": "Diabetes",       "risk_level": "High",     "device_status": "Online",  "last_sync": "5 min ago",   "device_id": "DSW-002", "heart_rate": 92,  "spo2": 96, "temperature": 98.4, "steps": 3400, "notes": "Insulin adjustment scheduled"},
    {"id": "P003", "name": "Sarah Chen",      "age": 65, "condition": "Cardiovascular", "risk_level": "High",     "device_status": "Online",  "last_sync": "1 min ago",   "device_id": "DSW-003", "heart_rate": 105, "spo2": 95, "temperature": 98.6, "steps": 2800, "notes": ""},
    {"id": "P004", "name": "Robert Johnson",  "age": 75, "condition": "COPD",           "risk_level": "Medium",   "device_status": "Offline", "last_sync": "2 hours ago", "device_id": "DSW-004", "heart_rate": 78,  "spo2": 93, "temperature": 99.1, "steps": 500,  "notes": "Oxygen therapy ongoing"},
    {"id": "P005", "name": "Emma Wilson",     "age": 70, "condition": "Heart Failure",  "risk_level": "Critical", "device_status": "Online",  "last_sync": "10 min ago",  "device_id": "DSW-005", "heart_rate": 112, "spo2": 92, "temperature": 99.4, "steps": 700,  "notes": "Scheduled for checkup next week"},
    {"id": "P006", "name": "James Rivera",    "age": 60, "condition": "Arrhythmia",     "risk_level": "High",     "device_status": "Online",  "last_sync": "3 min ago",   "device_id": "DSW-006", "heart_rate": 98,  "spo2": 96, "temperature": 98.5, "steps": 1800, "notes": ""},
    {"id": "P007", "name": "Linda Park",      "age": 78, "condition": "Asthma",         "risk_level": "Low",      "device_status": "Online",  "last_sync": "8 min ago",   "device_id": "DSW-007", "heart_rate": 72,  "spo2": 98, "temperature": 98.1, "steps": 4200, "notes": "Stable condition"},
]

ALERTS = [
    {"id": "ALR-001", "title": "High Heart Rate",           "patient": "Maria Garcia",    "severity": "critical", "status": "new",         "timestamp": "2 mins ago",  "value": "128 bpm"},
    {"id": "ALR-002", "title": "Low SpO2 Level",            "patient": "Emma Wilson",     "severity": "critical", "status": "new",         "timestamp": "15 mins ago", "value": "92%"},
    {"id": "ALR-003", "title": "Irregular Heart Pattern",   "patient": "Robert Johnson",  "severity": "critical", "status": "in-progress", "timestamp": "45 mins ago", "value": "Arrhythmia detected"},
    {"id": "ALR-004", "title": "Low Battery Alert",         "patient": "Robert Johnson",  "severity": "warning",  "status": "new",         "timestamp": "1 hr ago",    "value": "12%"},
    {"id": "ALR-005", "title": "High Temperature",          "patient": "Sarah Chen",      "severity": "warning",  "status": "resolved",    "timestamp": "3 hrs ago",   "value": "99.4°F"},
    {"id": "ALR-006", "title": "Elevated Blood Pressure",   "patient": "Maria Garcia",    "severity": "warning",  "status": "in-progress", "timestamp": "4 hrs ago",   "value": "155/95 mmHg"},
    {"id": "ALR-007", "title": "Missed Medication Window",  "patient": "John Smith",      "severity": "warning",  "status": "new",         "timestamp": "5 hrs ago",   "value": "Insulin dose overdue"},
    {"id": "ALR-008", "title": "Fall Detected",             "patient": "Emma Wilson",     "severity": "critical", "status": "escalated",   "timestamp": "6 hrs ago",   "value": "Sudden impact detected"},
]

DEVICES = [
    {"id": "DSW-001", "patient_name": "Maria Garcia",    "status": "Online",  "battery": 85, "last_sync": "2 min ago",   "firmware": "v2.1.0"},
    {"id": "DSW-002", "patient_name": "John Smith",      "status": "Online",  "battery": 60, "last_sync": "5 min ago",   "firmware": "v2.1.0"},
    {"id": "DSW-003", "patient_name": "Sarah Chen",      "status": "Online",  "battery": 45, "last_sync": "1 min ago",   "firmware": "v2.0.5"},
    {"id": "DSW-004", "patient_name": "Robert Johnson",  "status": "Offline", "battery": 12, "last_sync": "2 hours ago", "firmware": "v2.0.5"},
    {"id": "DSW-005", "patient_name": "Emma Wilson",     "status": "Online",  "battery": 92, "last_sync": "10 min ago",  "firmware": "v2.1.0"},
    {"id": "DSW-006", "patient_name": "James Rivera",    "status": "Online",  "battery": 78, "last_sync": "3 min ago",   "firmware": "v2.1.0"},
    {"id": "DSW-007", "patient_name": "Linda Park",      "status": "Online",  "battery": 55, "last_sync": "8 min ago",   "firmware": "v2.0.5"},
]


def run_sql(sql):
    """Execute SQL via the Supabase REST RPC endpoint."""
    url = f"{SUPABASE_URL}/rest/v1/rpc/"
    # Use the Management API to run raw SQL
    mgmt_url = f"https://api.supabase.com/v1/projects/cnktjnchyyttjvslvdpr/database/query"
    # Fallback: use the postgREST rpc if management API is unavailable
    # Actually, use the SQL endpoint through the management API
    req = urllib.request.Request(
        mgmt_url,
        data=json.dumps({"query": sql}).encode(),
        headers={
            "Authorization": f"Bearer {SERVICE_KEY}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        resp = urllib.request.urlopen(req)
        print(f"  ✓ SQL executed ({resp.status})")
        return True
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        print(f"  ✗ SQL error {e.code}: {body}")
        return False


def upsert(table, rows):
    """Insert rows via REST API (upsert = skip conflicts)."""
    url = f"{SUPABASE_URL}/rest/v1/{table}"
    req = urllib.request.Request(
        url,
        data=json.dumps(rows).encode(),
        headers={
            "apikey": SERVICE_KEY,
            "Authorization": f"Bearer {SERVICE_KEY}",
            "Content-Type": "application/json",
            "Prefer": "resolution=merge-duplicates,return=minimal",
        },
        method="POST",
    )
    try:
        urllib.request.urlopen(req)
        print(f"  ✓ {table}: {len(rows)} rows upserted")
        return True
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        print(f"  ✗ {table} upsert error {e.code}: {body}")
        return False


def main():
    print("═══ Dominican Smart Watch — Supabase Data Seeder ═══\n")

    print("1) Creating / verifying tables, RLS, realtime ...")
    run_sql(SETUP_SQL)

    print("\n2) Seeding patients ...")
    upsert("patients", PATIENTS)

    print("\n3) Seeding alerts ...")
    upsert("alerts", ALERTS)

    print("\n4) Seeding devices ...")
    upsert("devices", DEVICES)

    print("\n✅ Done! Refresh your app to see the data.\n")


if __name__ == "__main__":
    main()
