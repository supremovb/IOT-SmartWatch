-- ============================================================
-- Sensors Migration: Add AHT21 + ENS160 + MLX90614 columns
-- Run this in Supabase Dashboard → SQL Editor
-- ============================================================

ALTER TABLE public.patients
  ADD COLUMN IF NOT EXISTS humidity      DOUBLE PRECISION DEFAULT 0,
  ADD COLUMN IF NOT EXISTS eco2          INTEGER          DEFAULT 400,
  ADD COLUMN IF NOT EXISTS tvoc          INTEGER          DEFAULT 0,
  ADD COLUMN IF NOT EXISTS ambient_temp  DOUBLE PRECISION DEFAULT 0;

-- Update RLS: anonymous (ESP32) can push sensor data via PATCH
DROP POLICY IF EXISTS "Allow anon patch vitals" ON public.patients;
CREATE POLICY "Allow anon patch vitals" ON public.patients
  FOR UPDATE TO anon USING (true) WITH CHECK (true);
