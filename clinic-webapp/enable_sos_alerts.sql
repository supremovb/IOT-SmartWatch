-- Run this in Supabase SQL Editor
-- Purpose: allow the ESP32 watch to insert SOS alerts into public.alerts

-- 1) Allow explicit SOS severity values as well as critical/warning
ALTER TABLE public.alerts DROP CONSTRAINT IF EXISTS alerts_severity_check;
ALTER TABLE public.alerts
ADD CONSTRAINT alerts_severity_check
CHECK (severity IN ('critical', 'warning', 'sos'));

-- 2) Permit anonymous inserts from the ESP32 using the anon key
DROP POLICY IF EXISTS "Alerts insertable by anon for SOS" ON public.alerts;
CREATE POLICY "Alerts insertable by anon for SOS"
ON public.alerts
FOR INSERT
TO anon
WITH CHECK (true);

-- 3) Optional: allow anon devices to read alerts too
DROP POLICY IF EXISTS "Alerts selectable by anon" ON public.alerts;
CREATE POLICY "Alerts selectable by anon"
ON public.alerts
FOR SELECT
TO anon
USING (true);

-- 4) Add a friendly automatic device name for watches
ALTER TABLE public.devices ADD COLUMN IF NOT EXISTS name TEXT DEFAULT 'ESP32 SmartWatch';
UPDATE public.devices SET name = COALESCE(NULLIF(name, ''), 'ESP32 SmartWatch');

-- 5) Allow the ESP32 to create/update its device heartbeat row
DROP POLICY IF EXISTS "Devices insertable by anon" ON public.devices;
CREATE POLICY "Devices insertable by anon"
ON public.devices
FOR INSERT
TO anon
WITH CHECK (true);

DROP POLICY IF EXISTS "Devices updatable by anon" ON public.devices;
CREATE POLICY "Devices updatable by anon"
ON public.devices
FOR UPDATE
TO anon
USING (true)
WITH CHECK (true);

DROP POLICY IF EXISTS "Devices selectable by anon" ON public.devices;
CREATE POLICY "Devices selectable by anon"
ON public.devices
FOR SELECT
TO anon
USING (true);

-- 5) Ensure patient health-sync columns exist for realtime watch updates
ALTER TABLE public.patients ADD COLUMN IF NOT EXISTS device_id TEXT DEFAULT '';
ALTER TABLE public.patients ADD COLUMN IF NOT EXISTS device_status TEXT DEFAULT 'Offline';
ALTER TABLE public.patients ADD COLUMN IF NOT EXISTS last_sync TEXT DEFAULT 'N/A';
ALTER TABLE public.patients ADD COLUMN IF NOT EXISTS heart_rate INTEGER DEFAULT 75;
ALTER TABLE public.patients ADD COLUMN IF NOT EXISTS spo2 INTEGER DEFAULT 97;
ALTER TABLE public.patients ADD COLUMN IF NOT EXISTS temperature DOUBLE PRECISION DEFAULT 98.2;
ALTER TABLE public.patients ADD COLUMN IF NOT EXISTS steps INTEGER DEFAULT 0;
ALTER TABLE public.patients ADD COLUMN IF NOT EXISTS notes TEXT DEFAULT '';

-- 6) Allow the ESP32 to update an already-linked patient by device_id
DROP POLICY IF EXISTS "Patients selectable by anon device" ON public.patients;
CREATE POLICY "Patients selectable by anon device"
ON public.patients
FOR SELECT
TO anon
USING (true);

DROP POLICY IF EXISTS "Patients updatable by anon device" ON public.patients;
CREATE POLICY "Patients updatable by anon device"
ON public.patients
FOR UPDATE
TO anon
USING (true)
WITH CHECK (true);
