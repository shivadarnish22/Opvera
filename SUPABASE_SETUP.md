# Supabase Setup Instructions

## 1. Enable Auth and Configure Sign-up

In your Supabase dashboard:

1. Go to **Authentication** → **Settings**
2. Enable **Enable email confirmations** (optional)
3. Enable **Enable email change confirmations** (optional)
4. Set **Site URL** to your frontend URL (e.g., `http://localhost:5173`)
5. Add **Redirect URLs** for your auth callbacks

## 2. Database Schema Setup

Run the following SQL in your Supabase SQL Editor:

```sql
-- Enable RLS on all tables
ALTER TABLE auth.users ENABLE ROW LEVEL SECURITY;

-- Create profiles table (extends auth.users)
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  username TEXT UNIQUE NOT NULL,
  email TEXT UNIQUE NOT NULL,
  avatar_url TEXT,
  role TEXT NOT NULL DEFAULT 'student' CHECK (role IN ('student', 'mentor', 'admin', 'company')),
  level TEXT DEFAULT 'beginner' CHECK (level IN ('beginner', 'intermediate', 'advanced')),
  total_score INTEGER DEFAULT 0,
  verified BOOLEAN DEFAULT false,
  -- Student fields
  college TEXT,
  batch TEXT,
  cgpa DECIMAL(3,2),
  skills TEXT[],
  resume_url TEXT,
  -- Mentor fields
  domain_expertise TEXT[],
  bio TEXT,
  linkedin TEXT,
  availability TEXT,
  verification_docs JSONB,
  -- Company fields
  company_name TEXT,
  company_size TEXT,
  description TEXT,
  contact_person TEXT,
  contact_title TEXT,
  website TEXT,
  logo_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create projects table
CREATE TABLE IF NOT EXISTS public.projects (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'completed', 'archived')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create tasks table
CREATE TABLE IF NOT EXISTS public.tasks (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  project_id UUID REFERENCES public.projects(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'completed')),
  priority TEXT DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high')),
  due_date TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create quizzes table
CREATE TABLE IF NOT EXISTS public.quizzes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  topic TEXT NOT NULL,
  difficulty TEXT DEFAULT 'beginner' CHECK (difficulty IN ('beginner', 'intermediate', 'advanced')),
  questions JSONB NOT NULL,
  created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create quiz_attempts table
CREATE TABLE IF NOT EXISTS public.quiz_attempts (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  quiz_id UUID REFERENCES public.quizzes(id) ON DELETE CASCADE NOT NULL,
  score INTEGER DEFAULT 0,
  answers JSONB,
  completed_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create chats table
CREATE TABLE IF NOT EXISTS public.chats (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title TEXT NOT NULL,
  type TEXT DEFAULT 'direct' CHECK (type IN ('direct', 'group', 'mentor_group')),
  created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create chat_participants table
CREATE TABLE IF NOT EXISTS public.chat_participants (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  chat_id UUID REFERENCES public.chats(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  role TEXT DEFAULT 'member' CHECK (role IN ('member', 'admin', 'mentor')),
  joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(chat_id, user_id)
);

-- Create messages table
CREATE TABLE IF NOT EXISTS public.messages (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  chat_id UUID REFERENCES public.chats(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  content TEXT NOT NULL,
  message_type TEXT DEFAULT 'text' CHECK (message_type IN ('text', 'image', 'file', 'system')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create audit_logs table for verification tracking
CREATE TABLE IF NOT EXISTS public.audit_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  action TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id UUID NOT NULL,
  details JSONB,
  user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  admin_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  admin_notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  reviewed_at TIMESTAMP WITH TIME ZONE
);

-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quizzes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quiz_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);
CREATE INDEX IF NOT EXISTS idx_profiles_total_score ON public.profiles(total_score DESC);
CREATE INDEX IF NOT EXISTS idx_projects_user_id ON public.projects(user_id);
CREATE INDEX IF NOT EXISTS idx_tasks_project_id ON public.tasks(project_id);
CREATE INDEX IF NOT EXISTS idx_quiz_attempts_user_id ON public.quiz_attempts(user_id);
CREATE INDEX IF NOT EXISTS idx_quiz_attempts_quiz_id ON public.quiz_attempts(quiz_id);
CREATE INDEX IF NOT EXISTS idx_chat_participants_chat_id ON public.chat_participants(chat_id);
CREATE INDEX IF NOT EXISTS idx_chat_participants_user_id ON public.chat_participants(user_id);
CREATE INDEX IF NOT EXISTS idx_messages_chat_id ON public.messages(chat_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON public.messages(created_at);
```

## 3. Row Level Security (RLS) Policies

```sql
-- PROFILES TABLE POLICIES
-- Allow authenticated users to insert their own profile
CREATE POLICY "Users can insert their own profile" ON public.profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

-- Allow public read access to limited profile fields
CREATE POLICY "Public can read profile basic info" ON public.profiles
  FOR SELECT USING (true);

-- Allow users to update their own profile
CREATE POLICY "Users can update their own profile" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);

-- Allow admins to update any profile
CREATE POLICY "Admins can update any profile" ON public.profiles
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Allow admins to delete profiles
CREATE POLICY "Admins can delete profiles" ON public.profiles
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- PROJECTS TABLE POLICIES
-- Allow public read access to projects
CREATE POLICY "Public can read projects" ON public.projects
  FOR SELECT USING (true);

-- Allow authenticated students to insert projects
CREATE POLICY "Students can insert projects" ON public.projects
  FOR INSERT WITH CHECK (
    auth.uid() = user_id AND 
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role = 'student'
    )
  );

-- Allow project owners to update their projects
CREATE POLICY "Project owners can update projects" ON public.projects
  FOR UPDATE USING (auth.uid() = user_id);

-- Allow mentors and admins to update any project
CREATE POLICY "Mentors and admins can update projects" ON public.projects
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role IN ('mentor', 'admin')
    )
  );

-- Allow admins to delete projects
CREATE POLICY "Admins can delete projects" ON public.projects
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- TASKS TABLE POLICIES
-- Allow public read access to tasks
CREATE POLICY "Public can read tasks" ON public.tasks
  FOR SELECT USING (true);

-- Allow project owners to insert tasks
CREATE POLICY "Project owners can insert tasks" ON public.tasks
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.projects 
      WHERE id = project_id AND user_id = auth.uid()
    )
  );

-- Allow project owners to update tasks
CREATE POLICY "Project owners can update tasks" ON public.tasks
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.projects 
      WHERE id = project_id AND user_id = auth.uid()
    )
  );

-- Allow mentors and admins to update any task
CREATE POLICY "Mentors and admins can update tasks" ON public.tasks
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role IN ('mentor', 'admin')
    )
  );

-- Allow admins to delete tasks
CREATE POLICY "Admins can delete tasks" ON public.tasks
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- QUIZZES TABLE POLICIES
-- Allow public read access to quizzes
CREATE POLICY "Public can read quizzes" ON public.quizzes
  FOR SELECT USING (true);

-- Allow authenticated users to insert quizzes
CREATE POLICY "Authenticated users can insert quizzes" ON public.quizzes
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- Allow quiz creators to update their quizzes
CREATE POLICY "Quiz creators can update quizzes" ON public.quizzes
  FOR UPDATE USING (auth.uid() = created_by);

-- Allow admins to update any quiz
CREATE POLICY "Admins can update quizzes" ON public.quizzes
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Allow admins to delete quizzes
CREATE POLICY "Admins can delete quizzes" ON public.quizzes
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- QUIZ_ATTEMPTS TABLE POLICIES
-- Allow users to read their own attempts
CREATE POLICY "Users can read their own attempts" ON public.quiz_attempts
  FOR SELECT USING (auth.uid() = user_id);

-- Allow users to insert their own attempts
CREATE POLICY "Users can insert their own attempts" ON public.quiz_attempts
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Allow users to update their own attempts
CREATE POLICY "Users can update their own attempts" ON public.quiz_attempts
  FOR UPDATE USING (auth.uid() = user_id);

-- Allow admins to read all attempts
CREATE POLICY "Admins can read all attempts" ON public.quiz_attempts
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- CHATS TABLE POLICIES
-- Allow chat participants to read chats
CREATE POLICY "Chat participants can read chats" ON public.chats
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.chat_participants 
      WHERE chat_id = id AND user_id = auth.uid()
    )
  );

-- Allow authenticated users to create chats
CREATE POLICY "Authenticated users can create chats" ON public.chats
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- Allow chat admins to update chats
CREATE POLICY "Chat admins can update chats" ON public.chats
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.chat_participants 
      WHERE chat_id = id AND user_id = auth.uid() AND role IN ('admin', 'mentor')
    )
  );

-- Allow admins to read all chats
CREATE POLICY "Admins can read all chats" ON public.chats
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- CHAT_PARTICIPANTS TABLE POLICIES
-- Allow chat participants to read participants
CREATE POLICY "Chat participants can read participants" ON public.chat_participants
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.chat_participants cp2
      WHERE cp2.chat_id = chat_id AND cp2.user_id = auth.uid()
    )
  );

-- Allow chat admins to insert participants
CREATE POLICY "Chat admins can insert participants" ON public.chat_participants
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.chat_participants 
      WHERE chat_id = chat_id AND user_id = auth.uid() AND role IN ('admin', 'mentor')
    )
  );

-- Allow users to join chats (self-insert)
CREATE POLICY "Users can join chats" ON public.chat_participants
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Allow chat admins to update participants
CREATE POLICY "Chat admins can update participants" ON public.chat_participants
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.chat_participants 
      WHERE chat_id = chat_id AND user_id = auth.uid() AND role IN ('admin', 'mentor')
    )
  );

-- Allow admins to read all participants
CREATE POLICY "Admins can read all participants" ON public.chat_participants
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- MESSAGES TABLE POLICIES
-- Allow chat participants to read messages
CREATE POLICY "Chat participants can read messages" ON public.messages
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.chat_participants 
      WHERE chat_id = chat_id AND user_id = auth.uid()
    )
  );

-- Allow chat participants to insert messages
CREATE POLICY "Chat participants can insert messages" ON public.messages
  FOR INSERT WITH CHECK (
    auth.uid() = user_id AND
    EXISTS (
      SELECT 1 FROM public.chat_participants 
      WHERE chat_id = chat_id AND user_id = auth.uid()
    )
  );

-- Allow admins to read all messages
CREATE POLICY "Admins can read all messages" ON public.messages
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Allow mentors to read messages in groups they moderate
CREATE POLICY "Mentors can read group messages" ON public.messages
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.chat_participants cp
      JOIN public.chats c ON c.id = cp.chat_id
      WHERE cp.chat_id = chat_id 
        AND cp.user_id = auth.uid() 
        AND cp.role = 'mentor'
        AND c.type = 'mentor_group'
    )
  );

-- AUDIT_LOGS TABLE POLICIES
-- Allow users to read their own audit logs
CREATE POLICY "Users can read their own audit logs" ON public.audit_logs
  FOR SELECT USING (auth.uid() = user_id);

-- Allow admins to read all audit logs
CREATE POLICY "Admins can read all audit logs" ON public.audit_logs
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Allow system to insert audit logs
CREATE POLICY "System can insert audit logs" ON public.audit_logs
  FOR INSERT WITH CHECK (true);

-- Allow admins to update audit log status
CREATE POLICY "Admins can update audit logs" ON public.audit_logs
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );
```

## 4. Create Default Admin User

```sql
-- Insert default admin user (change credentials after first login!)
INSERT INTO public.profiles (id, username, email, role, level, total_score)
VALUES (
  '00000000-0000-0000-0000-000000000000', -- Replace with actual UUID from auth.users
  'admin',
  'admin@opvera.com',
  'admin',
  'advanced',
  0
) ON CONFLICT (id) DO NOTHING;
```

## 5. Functions and Triggers

```sql
-- Function to automatically create profile on user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, username, email, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'username', NEW.email),
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'role', 'student')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to create profile on user signup
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add updated_at triggers to relevant tables
CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_projects_updated_at BEFORE UPDATE ON public.projects
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_tasks_updated_at BEFORE UPDATE ON public.tasks
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_quizzes_updated_at BEFORE UPDATE ON public.quizzes
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_chats_updated_at BEFORE UPDATE ON public.chats
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
```

## 6. Storage Buckets Setup

In your Supabase dashboard:

1. Go to **Storage** → **Buckets**
2. Create the following buckets:

### Documents Bucket
- **Name**: `documents`
- **Public**: `false` (private bucket)
- **File size limit**: `50MB`
- **Allowed MIME types**: `application/pdf,application/msword,application/vnd.openxmlformats-officedocument.wordprocessingml.document,image/jpeg,image/png`

### Images Bucket
- **Name**: `images`
- **Public**: `true` (public bucket for logos)
- **File size limit**: `10MB`
- **Allowed MIME types**: `image/jpeg,image/png,image/gif,image/svg+xml`

### Storage Policies

```sql
-- Documents bucket policies
CREATE POLICY "Users can upload documents" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'documents' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Users can read their own documents" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'documents' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Admins can read all documents" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'documents' AND
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Images bucket policies
CREATE POLICY "Users can upload images" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'images' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Public can read images" ON storage.objects
  FOR SELECT USING (bucket_id = 'images');
```

## 7. Grant Permissions

```sql
-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO anon, authenticated;
```

## Next Steps

1. Run all SQL commands in your Supabase SQL Editor
2. Test the policies by creating test users with different roles
3. Update the default admin credentials in production
4. Configure your frontend to handle role-based authentication
