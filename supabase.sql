-- Supabase Migration: Opvera Database Schema
-- This file contains DDL for all required tables, indices, triggers, and RLS policies

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 1. Users table (extends Supabase Auth)
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    auth_uid TEXT UNIQUE NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('student', 'mentor', 'company', 'admin', 'banned')),
    display_name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    avatar_url TEXT,
    bio TEXT,
    skills JSONB DEFAULT '[]'::jsonb,
    socials JSONB DEFAULT '{}'::jsonb,
    banned BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Student profiles (extended student info)
CREATE TABLE student_profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    college TEXT,
    batch TEXT,
    cgpa DECIMAL(3,2),
    location TEXT,
    resume_url TEXT,
    linkedin TEXT,
    portfolio_url TEXT,
    extra JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Projects
CREATE TABLE projects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    files TEXT[], -- Array of storage paths
    github_url TEXT, -- GitHub repository URL
    tags TEXT[] DEFAULT '{}',
    points_awarded INTEGER DEFAULT 0,
    verified BOOLEAN DEFAULT FALSE,
    mentor_notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Assignments
CREATE TABLE assignments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    submission_url TEXT,
    points INTEGER DEFAULT 0,
    verified BOOLEAN DEFAULT FALSE,
    mentor_notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. Channels
CREATE TABLE channels (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('group', 'private', 'global', 'ai')),
    members JSONB DEFAULT '[]'::jsonb, -- Array of user IDs
    admins JSONB DEFAULT '[]'::jsonb, -- Array of user IDs
    metadata JSONB DEFAULT '{}'::jsonb, -- AI settings, course context, etc.
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 6. Messages
CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    channel_id UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb, -- AI flags, reactions, etc.
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 7. Quizzes
CREATE TABLE quizzes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    questions JSONB NOT NULL DEFAULT '[]'::jsonb, -- Array of {question, options, correctIndex, explanation}
    difficulty TEXT CHECK (difficulty IN ('beginner', 'intermediate', 'advanced')),
    topic TEXT,
    ai_generated BOOLEAN DEFAULT FALSE,
    metadata JSONB DEFAULT '{}'::jsonb, -- AI model info, generation timestamp, etc.
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 8. Quiz attempts
CREATE TABLE quiz_attempts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    quiz_id UUID NOT NULL REFERENCES quizzes(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    answers JSONB DEFAULT '[]'::jsonb, -- Array of user answers
    score INTEGER DEFAULT 0,
    max_score INTEGER DEFAULT 0,
    completed_at TIMESTAMP WITH TIME ZONE,
    metadata JSONB DEFAULT '{}'::jsonb, -- AI grading results, feedback, etc.
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 9. Leaderboard (materialized view for performance)
CREATE TABLE leaderboard (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    total_points INTEGER DEFAULT 0,
    breakdown JSONB DEFAULT '{}'::jsonb, -- {quizzes: X, assignments: Y, projects: Z, challenges: W}
    rank INTEGER,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 10. Audit logs (for admin monitoring)
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    actor_id UUID REFERENCES users(id) ON DELETE SET NULL,
    action TEXT NOT NULL,
    target_type TEXT NOT NULL,
    target_id UUID,
    details JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =============================================
-- INDICES FOR PERFORMANCE
-- =============================================

-- Users indices
CREATE INDEX idx_users_auth_uid ON users(auth_uid);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_created_at ON users(created_at);

-- Student profiles indices
CREATE INDEX idx_student_profiles_user_id ON student_profiles(user_id);
CREATE INDEX idx_student_profiles_college ON student_profiles(college);
CREATE INDEX idx_student_profiles_batch ON student_profiles(batch);

-- Projects indices
CREATE INDEX idx_projects_owner_id ON projects(owner_id);
CREATE INDEX idx_projects_verified ON projects(verified);
CREATE INDEX idx_projects_points_awarded ON projects(points_awarded);
CREATE INDEX idx_projects_created_at ON projects(created_at);
CREATE INDEX idx_projects_tags ON projects USING GIN(tags);

-- Assignments indices
CREATE INDEX idx_assignments_student_id ON assignments(student_id);
CREATE INDEX idx_assignments_verified ON assignments(verified);
CREATE INDEX idx_assignments_points ON assignments(points);
CREATE INDEX idx_assignments_created_at ON assignments(created_at);

-- Channels indices
CREATE INDEX idx_channels_type ON channels(type);
CREATE INDEX idx_channels_members ON channels USING GIN(members);
CREATE INDEX idx_channels_admins ON channels USING GIN(admins);
CREATE INDEX idx_channels_metadata ON channels USING GIN(metadata);

-- Messages indices
CREATE INDEX idx_messages_channel_id ON messages(channel_id);
CREATE INDEX idx_messages_sender_id ON messages(sender_id);
CREATE INDEX idx_messages_created_at ON messages(created_at);
CREATE INDEX idx_messages_metadata ON messages USING GIN(metadata);

-- Quizzes indices
CREATE INDEX idx_quizzes_created_by ON quizzes(created_by);
CREATE INDEX idx_quizzes_created_at ON quizzes(created_at);
CREATE INDEX idx_quizzes_questions ON quizzes USING GIN(questions);
CREATE INDEX idx_quizzes_difficulty ON quizzes(difficulty);
CREATE INDEX idx_quizzes_topic ON quizzes(topic);
CREATE INDEX idx_quizzes_ai_generated ON quizzes(ai_generated);
CREATE INDEX idx_quizzes_metadata ON quizzes USING GIN(metadata);

-- Quiz attempts indices
CREATE INDEX idx_quiz_attempts_quiz_id ON quiz_attempts(quiz_id);
CREATE INDEX idx_quiz_attempts_student_id ON quiz_attempts(student_id);
CREATE INDEX idx_quiz_attempts_score ON quiz_attempts(score);
CREATE INDEX idx_quiz_attempts_created_at ON quiz_attempts(created_at);
CREATE INDEX idx_quiz_attempts_completed_at ON quiz_attempts(completed_at);
CREATE INDEX idx_quiz_attempts_metadata ON quiz_attempts USING GIN(metadata);

-- Leaderboard indices
CREATE INDEX idx_leaderboard_total_points ON leaderboard(total_points DESC);
CREATE INDEX idx_leaderboard_rank ON leaderboard(rank);
CREATE INDEX idx_leaderboard_breakdown ON leaderboard USING GIN(breakdown);

-- Audit logs indices
CREATE INDEX idx_audit_logs_actor_id ON audit_logs(actor_id);
CREATE INDEX idx_audit_logs_action ON audit_logs(action);
CREATE INDEX idx_audit_logs_target_type ON audit_logs(target_type);
CREATE INDEX idx_audit_logs_target_id ON audit_logs(target_id);
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at);

-- =============================================
-- FUNCTIONS AND TRIGGERS
-- =============================================

-- Function to calculate quiz points (1 point per correct answer)
CREATE OR REPLACE FUNCTION calculate_quiz_points(student_id UUID)
RETURNS INTEGER AS $$
DECLARE
    total_points INTEGER := 0;
BEGIN
    SELECT COALESCE(SUM(
        CASE 
            WHEN qa.completed_at IS NOT NULL THEN
                (SELECT COUNT(*) FROM jsonb_array_elements(qa.answers) WITH ORDINALITY AS ans(answer, idx)
                 JOIN jsonb_array_elements(q.questions) WITH ORDINALITY AS ques(question, qidx)
                 ON ans.idx = ques.qidx
                 WHERE ans.answer = (ques.question->>'correctIndex')::integer)
            ELSE 0
        END
    ), 0)
    INTO total_points
    FROM quiz_attempts qa
    JOIN quizzes q ON qa.quiz_id = q.id
    WHERE qa.student_id = calculate_quiz_points.student_id;
    
    RETURN total_points;
END;
$$ LANGUAGE plpgsql;

-- Function to calculate assignment points (20 points per submission)
CREATE OR REPLACE FUNCTION calculate_assignment_points(student_id UUID)
RETURNS INTEGER AS $$
DECLARE
    total_points INTEGER := 0;
BEGIN
    SELECT COALESCE(COUNT(*) * 20, 0)
    INTO total_points
    FROM assignments
    WHERE student_id = calculate_assignment_points.student_id
    AND submission_url IS NOT NULL;
    
    RETURN total_points;
END;
$$ LANGUAGE plpgsql;

-- Function to calculate project points (100 points per verified project)
CREATE OR REPLACE FUNCTION calculate_project_points(student_id UUID)
RETURNS INTEGER AS $$
DECLARE
    total_points INTEGER := 0;
BEGIN
    SELECT COALESCE(COUNT(*) * 100, 0)
    INTO total_points
    FROM projects
    WHERE owner_id = calculate_project_points.student_id
    AND verified = true;
    
    RETURN total_points;
END;
$$ LANGUAGE plpgsql;

-- Function to calculate challenge points (80 points per verified challenge)
CREATE OR REPLACE FUNCTION calculate_challenge_points(student_id UUID)
RETURNS INTEGER AS $$
DECLARE
    total_points INTEGER := 0;
BEGIN
    -- For now, challenges are treated as projects with a specific tag
    -- This can be extended when challenges table is added
    SELECT COALESCE(COUNT(*) * 80, 0)
    INTO total_points
    FROM projects
    WHERE owner_id = calculate_challenge_points.student_id
    AND verified = true
    AND 'challenge' = ANY(tags);
    
    RETURN total_points;
END;
$$ LANGUAGE plpgsql;

-- Function to update leaderboard with new points system
CREATE OR REPLACE FUNCTION update_leaderboard()
RETURNS TRIGGER AS $$
DECLARE
    target_user_id UUID;
    quiz_points INTEGER;
    assignment_points INTEGER;
    project_points INTEGER;
    challenge_points INTEGER;
    total_points INTEGER;
BEGIN
    -- Determine which user to update
    target_user_id := COALESCE(NEW.student_id, NEW.owner_id, NEW.user_id);
    
    -- Calculate points for each category
    quiz_points := calculate_quiz_points(target_user_id);
    assignment_points := calculate_assignment_points(target_user_id);
    project_points := calculate_project_points(target_user_id);
    challenge_points := calculate_challenge_points(target_user_id);
    
    -- Calculate total points
    total_points := quiz_points + assignment_points + project_points + challenge_points;
    
    -- Update or insert leaderboard entry
    INSERT INTO leaderboard (user_id, total_points, breakdown, updated_at)
    VALUES (
        target_user_id,
        total_points,
        jsonb_build_object(
            'quizzes', quiz_points,
            'assignments', assignment_points,
            'projects', project_points,
            'challenges', challenge_points
        ),
        NOW()
    )
    ON CONFLICT (user_id) DO UPDATE SET
        total_points = EXCLUDED.total_points,
        breakdown = EXCLUDED.breakdown,
        updated_at = EXCLUDED.updated_at;

    -- Update ranks for all users
    WITH ranked_users AS (
        SELECT user_id, ROW_NUMBER() OVER (ORDER BY total_points DESC) as new_rank
        FROM leaderboard
    )
    UPDATE leaderboard
    SET rank = ranked_users.new_rank
    FROM ranked_users
    WHERE leaderboard.user_id = ranked_users.user_id;

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Function to manually update leaderboard for a specific user
CREATE OR REPLACE FUNCTION refresh_user_leaderboard(user_id UUID)
RETURNS VOID AS $$
DECLARE
    quiz_points INTEGER;
    assignment_points INTEGER;
    project_points INTEGER;
    challenge_points INTEGER;
    total_points INTEGER;
BEGIN
    -- Calculate points for each category
    quiz_points := calculate_quiz_points(user_id);
    assignment_points := calculate_assignment_points(user_id);
    project_points := calculate_project_points(user_id);
    challenge_points := calculate_challenge_points(user_id);
    
    -- Calculate total points
    total_points := quiz_points + assignment_points + project_points + challenge_points;
    
    -- Update or insert leaderboard entry
    INSERT INTO leaderboard (user_id, total_points, breakdown, updated_at)
    VALUES (
        user_id,
        total_points,
        jsonb_build_object(
            'quizzes', quiz_points,
            'assignments', assignment_points,
            'projects', project_points,
            'challenges', challenge_points
        ),
        NOW()
    )
    ON CONFLICT (user_id) DO UPDATE SET
        total_points = EXCLUDED.total_points,
        breakdown = EXCLUDED.breakdown,
        updated_at = EXCLUDED.updated_at;

    -- Update ranks for all users
    WITH ranked_users AS (
        SELECT user_id, ROW_NUMBER() OVER (ORDER BY total_points DESC) as new_rank
        FROM leaderboard
    )
    UPDATE leaderboard
    SET rank = ranked_users.new_rank
    FROM ranked_users
    WHERE leaderboard.user_id = ranked_users.user_id;
END;
$$ LANGUAGE plpgsql;

-- Function to refresh all leaderboard entries
CREATE OR REPLACE FUNCTION refresh_all_leaderboard()
RETURNS VOID AS $$
DECLARE
    user_record RECORD;
BEGIN
    -- Clear existing leaderboard
    DELETE FROM leaderboard;
    
    -- Recalculate for all users
    FOR user_record IN 
        SELECT id FROM users WHERE role = 'student'
    LOOP
        PERFORM refresh_user_leaderboard(user_record.id);
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for leaderboard updates
CREATE TRIGGER trigger_update_leaderboard_quiz_attempts
    AFTER INSERT OR UPDATE ON quiz_attempts
    FOR EACH ROW EXECUTE FUNCTION update_leaderboard();

CREATE TRIGGER trigger_update_leaderboard_assignments
    AFTER INSERT OR UPDATE ON assignments
    FOR EACH ROW EXECUTE FUNCTION update_leaderboard();

CREATE TRIGGER trigger_update_leaderboard_projects
    AFTER INSERT OR UPDATE ON projects
    FOR EACH ROW EXECUTE FUNCTION update_leaderboard();

-- Additional trigger for assignment submissions (when submission_url is added)
CREATE TRIGGER trigger_update_leaderboard_assignment_submission
    AFTER UPDATE ON assignments
    FOR EACH ROW 
    WHEN (OLD.submission_url IS NULL AND NEW.submission_url IS NOT NULL)
    EXECUTE FUNCTION update_leaderboard();

-- Triggers for updated_at timestamps
CREATE TRIGGER trigger_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_student_profiles_updated_at
    BEFORE UPDATE ON student_profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_projects_updated_at
    BEFORE UPDATE ON projects
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_assignments_updated_at
    BEFORE UPDATE ON assignments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_channels_updated_at
    BEFORE UPDATE ON channels
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_messages_updated_at
    BEFORE UPDATE ON messages
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_quizzes_updated_at
    BEFORE UPDATE ON quizzes
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_quiz_attempts_updated_at
    BEFORE UPDATE ON quiz_attempts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- =============================================

-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE channels ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE quizzes ENABLE ROW LEVEL SECURITY;
ALTER TABLE quiz_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE leaderboard ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- Users policies
CREATE POLICY "Users can view their own profile" ON users
    FOR SELECT USING (auth.uid() = auth_uid);

CREATE POLICY "Users can update their own profile" ON users
    FOR UPDATE USING (auth.uid() = auth_uid);

CREATE POLICY "Admins can view all users" ON users
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE auth_uid = auth.uid() AND role = 'admin'
        )
    );

-- Student profiles policies
CREATE POLICY "Users can view their own student profile" ON student_profiles
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = student_profiles.user_id AND auth_uid = auth.uid()
        )
    );

CREATE POLICY "Users can update their own student profile" ON student_profiles
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = student_profiles.user_id AND auth_uid = auth.uid()
        )
    );

CREATE POLICY "Users can insert their own student profile" ON student_profiles
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = student_profiles.user_id AND auth_uid = auth.uid()
        )
    );

-- Projects policies
CREATE POLICY "Users can view all verified projects" ON projects
    FOR SELECT USING (verified = true);

CREATE POLICY "Users can view their own projects" ON projects
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = projects.owner_id AND auth_uid = auth.uid()
        )
    );

CREATE POLICY "Users can create projects" ON projects
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = projects.owner_id AND auth_uid = auth.uid()
        )
    );

CREATE POLICY "Users can update their own projects" ON projects
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = projects.owner_id AND auth_uid = auth.uid()
        )
    );

-- Assignments policies
CREATE POLICY "Students can view their own assignments" ON assignments
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = assignments.student_id AND auth_uid = auth.uid()
        )
    );

CREATE POLICY "Mentors can view all assignments" ON assignments
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE auth_uid = auth.uid() AND role IN ('mentor', 'admin')
        )
    );

CREATE POLICY "Students can create assignments" ON assignments
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = assignments.student_id AND auth_uid = auth.uid()
        )
    );

-- Channels policies
CREATE POLICY "Users can view channels they're members of" ON channels
    FOR SELECT USING (
        auth.uid()::text = ANY(
            SELECT jsonb_array_elements_text(members)
        )
    );

CREATE POLICY "Admins can create channels" ON channels
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM users 
            WHERE auth_uid = auth.uid() AND role IN ('admin', 'mentor')
        )
    );

-- Messages policies
CREATE POLICY "Users can view messages in channels they're members of" ON messages
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM channels 
            WHERE id = messages.channel_id AND (
                auth.uid()::text = ANY(
                    SELECT jsonb_array_elements_text(members)
                )
            )
        )
    );

CREATE POLICY "Users can send messages to channels they're members of" ON messages
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM channels 
            WHERE id = messages.channel_id AND (
                auth.uid()::text = ANY(
                    SELECT jsonb_array_elements_text(members)
                )
            )
        ) AND sender_id = (
            SELECT id FROM users WHERE auth_uid = auth.uid()
        )
    );

-- Quizzes policies
CREATE POLICY "Users can view all quizzes" ON quizzes
    FOR SELECT USING (true);

CREATE POLICY "Mentors and admins can create quizzes" ON quizzes
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = quizzes.created_by AND auth_uid = auth.uid() AND role IN ('mentor', 'admin')
        )
    );

-- Quiz attempts policies
CREATE POLICY "Students can view their own quiz attempts" ON quiz_attempts
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = quiz_attempts.student_id AND auth_uid = auth.uid()
        )
    );

CREATE POLICY "Students can create quiz attempts" ON quiz_attempts
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = quiz_attempts.student_id AND auth_uid = auth.uid()
        )
    );

-- Leaderboard policies
CREATE POLICY "Users can view leaderboard" ON leaderboard
    FOR SELECT USING (true);

-- Prevent direct updates to leaderboard (only allow through functions/triggers)
CREATE POLICY "No direct leaderboard updates" ON leaderboard
    FOR UPDATE USING (false);

CREATE POLICY "No direct leaderboard inserts" ON leaderboard
    FOR INSERT WITH CHECK (false);

CREATE POLICY "No direct leaderboard deletes" ON leaderboard
    FOR DELETE USING (false);

-- Audit logs policies
CREATE POLICY "Admins can view audit logs" ON audit_logs
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE auth_uid = auth.uid() AND role = 'admin'
        )
    );

CREATE POLICY "System can insert audit logs" ON audit_logs
    FOR INSERT WITH CHECK (true);

-- =============================================
-- INITIAL DATA AND SETUP
-- =============================================

-- Create default channels
INSERT INTO channels (id, name, type, members, admins, metadata) VALUES
    (uuid_generate_v4(), 'General Discussion', 'global', '[]'::jsonb, '[]'::jsonb, '{}'::jsonb),
    (uuid_generate_v4(), 'Announcements', 'global', '[]'::jsonb, '[]'::jsonb, '{}'::jsonb),
    (uuid_generate_v4(), 'Help & Support', 'global', '[]'::jsonb, '[]'::jsonb, '{}'::jsonb),
    (uuid_generate_v4(), 'AI Assistant', 'ai', '[]'::jsonb, '[]'::jsonb, '{"ai_enabled": true, "description": "Chat with Opvera AI for learning support"}'::jsonb);

-- Create admin user (this should be done through Supabase Auth first)
-- INSERT INTO users (auth_uid, role, display_name, email) VALUES
--     ('admin-auth-uid', 'admin', 'System Administrator', 'admin@opvera.com');

-- =============================================
-- COMMENTS AND DOCUMENTATION
-- =============================================

COMMENT ON TABLE users IS 'Main users table extending Supabase Auth';
COMMENT ON TABLE student_profiles IS 'Extended profile information for students';
COMMENT ON TABLE projects IS 'Student projects and portfolios';
COMMENT ON TABLE assignments IS 'Student assignments and submissions';
COMMENT ON TABLE channels IS 'Chat channels (group, private, global)';
COMMENT ON TABLE messages IS 'Messages within channels';
COMMENT ON TABLE quizzes IS 'Quizzes created by mentors or AI';
COMMENT ON TABLE quiz_attempts IS 'Student attempts at quizzes';
COMMENT ON TABLE leaderboard IS 'Materialized leaderboard with rankings';
COMMENT ON TABLE audit_logs IS 'Audit trail for admin monitoring';

-- Note: For production deployment, consider:
-- 1. Setting up Supabase Edge Functions for complex leaderboard updates
-- 2. Implementing proper backup strategies
-- 3. Adding monitoring and alerting
-- 4. Setting up proper environment-specific configurations
-- 5. Implementing data retention policies
