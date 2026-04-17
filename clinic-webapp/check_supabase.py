#!/usr/bin/env python3
"""Check if messages table exists and create it if not."""
import urllib.request
import urllib.error
import json

sk = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNua3RqbmNoeXl0dGp2c2x2ZHByIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NTg3OTIzOSwiZXhwIjoyMDkxNDU1MjM5fQ.biMSwjREi9j0K91D4yi_bLzfSN2lsjfmKPY7HYiC370"
base = "https://cnktjnchyyttjvslvdpr.supabase.co"

headers = {
    "apikey": sk,
    "Authorization": f"Bearer {sk}",
    "Content-Type": "application/json",
}

def make_request(url, method="GET", data=None):
    req = urllib.request.Request(url, headers=headers, method=method)
    if data:
        req.data = json.dumps(data).encode()
    try:
        with urllib.request.urlopen(req) as resp:
            return resp.status, resp.read().decode()
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()

# Check messages table
status, body = make_request(f"{base}/rest/v1/messages?limit=1")
print(f"Messages table check: {status} - {body[:200]}")

# Check avatars bucket
status2, body2 = make_request(f"{base}/storage/v1/bucket/avatars")
print(f"Avatars bucket check: {status2} - {body2[:200]}")
