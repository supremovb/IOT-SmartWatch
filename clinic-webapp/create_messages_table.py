#!/usr/bin/env python3
"""Create messages table via Supabase Management API."""
import urllib.request
import urllib.error
import json

# Service role key (for project REST API)
sk = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNua3RqbmNoeXl0dGp2c2x2ZHByIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NTg3OTIzOSwiZXhwIjoyMDkxNDU1MjM5fQ.biMSwjREi9j0K91D4yi_bLzfSN2lsjfmKPY7HYiC370"
project_ref = "cnktjnchyyttjvslvdpr"

# The SQL to create messages table with RLS
sql = """
CREATE TABLE IF NOT EXISTS public.messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  receiver_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='messages' AND policyname='messages_select') THEN
    CREATE POLICY messages_select ON public.messages
      FOR SELECT TO authenticated
      USING (auth.uid() = sender_id OR auth.uid() = receiver_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='messages' AND policyname='messages_insert') THEN
    CREATE POLICY messages_insert ON public.messages
      FOR INSERT TO authenticated
      WITH CHECK (auth.uid() = sender_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='messages' AND policyname='messages_update') THEN
    CREATE POLICY messages_update ON public.messages
      FOR UPDATE TO authenticated
      USING (auth.uid() = receiver_id);
  END IF;
END $$;
"""

# Use Management API
mgmt_url = f"https://api.supabase.com/v1/projects/{project_ref}/database/query"
mgmt_headers = {
    "Authorization": f"Bearer {sk}",
    "Content-Type": "application/json",
}

body = json.dumps({"query": sql}).encode()
req = urllib.request.Request(mgmt_url, headers=mgmt_headers, method="POST")
req.data = body

try:
    with urllib.request.urlopen(req) as resp:
        print(f"SUCCESS {resp.status}: {resp.read().decode()[:500]}")
except urllib.error.HTTPError as e:
    err_body = e.read().decode()
    print(f"HTTP ERROR {e.code}: {err_body[:500]}")
    
    # Try alternative: pg_restr endpoint
    print("\nTrying alternative endpoint...")
    pg_url = f"https://{project_ref}.supabase.co/rest/v1/rpc/execute_sql"
    pg_headers = {
        "apikey": sk,
        "Authorization": f"Bearer {sk}",
        "Content-Type": "application/json",
    }
    req2 = urllib.request.Request(pg_url, headers=pg_headers, method="POST")
    req2.data = json.dumps({"sql": sql}).encode()
    try:
        with urllib.request.urlopen(req2) as r2:
            print(f"Alt SUCCESS: {r2.read().decode()[:300]}")
    except urllib.error.HTTPError as e2:
        print(f"Alt ERROR {e2.code}: {e2.read().decode()[:300]}")
