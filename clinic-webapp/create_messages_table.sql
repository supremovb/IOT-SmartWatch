-- ============================================================
-- Messages Table (Enhanced) - Staff + Patient Messaging
-- Run this in Supabase Dashboard > SQL Editor
-- ============================================================

-- Create the messages table (if fresh install)
CREATE TABLE IF NOT EXISTS public.messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  receiver_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  receiver_patient_id TEXT,
  content TEXT NOT NULL DEFAULT '',
  message_type TEXT DEFAULT 'text',
  file_url TEXT,
  file_name TEXT,
  is_read BOOLEAN DEFAULT false,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Add columns if table already exists (safe for upgrades)
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS message_type TEXT DEFAULT 'text';
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS file_url TEXT;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS file_name TEXT;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS read_at TIMESTAMPTZ;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS receiver_patient_id TEXT;

-- Make receiver_id nullable (for patient messages)
ALTER TABLE public.messages ALTER COLUMN receiver_id DROP NOT NULL;

-- Set replica identity for realtime UPDATE events
ALTER TABLE public.messages REPLICA IDENTITY FULL;

-- Enable RLS
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- Drop policies if they already exist (idempotent)
DROP POLICY IF EXISTS "Messages: sender or receiver can view" ON public.messages;
DROP POLICY IF EXISTS "Messages: authenticated users can send" ON public.messages;
DROP POLICY IF EXISTS "Messages: receiver can update (mark read)" ON public.messages;
DROP POLICY IF EXISTS "Messages: participants can update" ON public.messages;

-- Recreate policies
CREATE POLICY "Messages: sender or receiver can view"
  ON public.messages FOR SELECT TO authenticated
  USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

CREATE POLICY "Messages: authenticated users can send"
  ON public.messages FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = sender_id);

CREATE POLICY "Messages: participants can update"
  ON public.messages FOR UPDATE TO authenticated
  USING (auth.uid() = receiver_id OR auth.uid() = sender_id);

-- Enable Realtime for the messages table
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
EXCEPTION WHEN duplicate_object THEN
  NULL;
END $$;

-- ============================================================
-- Storage bucket for chat files (images, videos, documents)
-- ============================================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('chat-files', 'chat-files', true)
ON CONFLICT (id) DO NOTHING;

-- Storage policies
DROP POLICY IF EXISTS "Chat files accessible by authenticated" ON storage.objects;
CREATE POLICY "Chat files accessible by authenticated"
  ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'chat-files');

DROP POLICY IF EXISTS "Authenticated can upload chat files" ON storage.objects;
CREATE POLICY "Authenticated can upload chat files"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'chat-files');

DROP POLICY IF EXISTS "Users can delete own chat files" ON storage.objects;
CREATE POLICY "Users can delete own chat files"
  ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'chat-files' AND (storage.foldername(name))[1] = auth.uid()::text);
