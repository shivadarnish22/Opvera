# Opvera - AI-Powered Learning Platform

Opvera is a comprehensive learning platform that connects students, mentors, and companies through AI-enhanced educational experiences. The platform features intelligent quiz generation, real-time chat capabilities, project management, and a gamified learning system with leaderboards.

## 🚀 Tech Stack

### Frontend
- **React 18** - Modern UI framework
- **Vite** - Fast build tool and dev server
- **Tailwind CSS** - Utility-first CSS framework
- **React Router** - Client-side routing
- **Recharts** - Data visualization
- **Lucide React** - Icon library
- **Axios** - HTTP client

### Backend & Database
- **Supabase** - Backend-as-a-Service
  - PostgreSQL database
  - Authentication & authorization
  - Real-time subscriptions
  - Row Level Security (RLS)
  - Storage buckets

### AI Integration
- **Google Gemini API** - AI-powered quiz generation and chat
- **Supabase Edge Functions** - Secure AI API calls (recommended for production)

## 🛠️ Local Development Setup

### Prerequisites
- Node.js 18+ 
- npm or yarn
- Supabase account
- Google AI Studio account (for Gemini API)

### 1. Install Dependencies

```bash
npm install
```

### 2. Environment Configuration

Copy the environment template and fill in your values:

```bash
cp env.example .env
```

Edit `.env` with your actual credentials:

```env
# Supabase Configuration
VITE_SUPABASE_URL=your_supabase_project_url_here
VITE_SUPABASE_ANON_KEY=your_supabase_anon_key_here

# Gemini API Key (consider moving to Edge Functions for production)
VITE_GEMINI_KEY=your_gemini_api_key_here
```

**Getting Supabase Credentials:**
1. Go to your Supabase project dashboard
2. Navigate to Settings > API
3. Copy the Project URL and anon/public key

**Getting Gemini API Key:**
1. Visit [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Create a new API key
3. Copy the key (keep it secure!)

### 3. Supabase Setup

#### Link to Supabase Project
```bash
# Install Supabase CLI (if not already installed)
npm install -g supabase

# Link to your project
supabase link --project-ref your-project-ref
```

#### Apply Database Migration
Run the complete database schema in your Supabase SQL Editor:

```sql
-- Copy and paste the entire contents of supabase.sql
-- This includes all tables, indices, triggers, and RLS policies
```

The migration includes:
- User management with role-based access
- Project and assignment tracking
- Quiz system with AI generation
- Real-time chat channels
- Leaderboard with points system
- Audit logging for admin monitoring

### 4. Storage Buckets Setup

Create the following storage buckets in your Supabase dashboard:

#### Documents Bucket
- **Name**: `documents`
- **Public**: `false` (private bucket)
- **File size limit**: `50MB`
- **Allowed MIME types**: `application/pdf,application/msword,application/vnd.openxmlformats-officedocument.wordprocessingml.document,image/jpeg,image/png`

#### Images Bucket
- **Name**: `images`
- **Public**: `true` (public bucket for logos)
- **File size limit**: `10MB`
- **Allowed MIME types**: `image/jpeg,image/png,image/gif,image/svg+xml`

#### Storage RLS Policies
Apply these policies in your Supabase SQL Editor:

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
      SELECT 1 FROM users 
      WHERE auth_uid = auth.uid() AND role = 'admin'
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

### 5. Start Development Server

```bash
npm run dev
```

The application will be available at `http://localhost:5173`

## 👤 Creating Default Admin User

After setting up the database, create a default admin user by running this SQL in your Supabase SQL Editor:

```sql
-- First, create the user in Supabase Auth (via dashboard or API)
-- Then insert the corresponding profile record:

INSERT INTO users (auth_uid, role, display_name, email, bio)
VALUES (
  'your-admin-auth-uid-here', -- Replace with actual UUID from auth.users
  'admin',
  'System Administrator',
  'admin@opvera.com',
  'Default system administrator account'
);

-- Grant admin permissions
UPDATE users 
SET role = 'admin' 
WHERE email = 'admin@opvera.com';
```

**Important:** Change the default admin credentials after first login!

## 🤖 AI Integration with Gemini

### Current Implementation
The platform uses Google Gemini API for:
- **Quiz Generation**: AI-powered quiz creation based on topics and difficulty
- **Chat Assistant**: Intelligent learning companion for students
- **Answer Grading**: Automated feedback and scoring

### Example API Calls

#### Generate Quiz
```javascript
import { generateQuiz } from './src/lib/geminiClient.js'

const quiz = await generateQuiz('JavaScript Fundamentals', 'intermediate', userId)
```

#### Chat with AI
```javascript
import { chatAI } from './src/lib/geminiClient.js'

const messages = [
  { role: 'user', content: 'Explain closures in JavaScript' }
]
const response = await chatAI(messages, { 
  role: 'student', 
  skills: ['JavaScript', 'React'] 
})
```

#### Grade Quiz Answers
```javascript
import { gradeQuizAnswers } from './src/lib/geminiClient.js'

const result = await gradeQuizAnswers(userAnswers, quizData)
```

### 🔒 Security Implementation

**AI calls are now routed via Supabase Edge Functions for enhanced security.**

The platform includes a secure Gemini proxy Edge Function that:
- ✅ Keeps API keys secure on the server
- ✅ Implements rate limiting and usage tracking
- ✅ Adds request validation and sanitization
- ✅ Monitors AI usage and costs
- ✅ Handles CORS and error responses

#### Edge Function Structure
```typescript
// supabase/functions/gemini-proxy/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

serve(async (req) => {
  const { prompt, temperature, topK, topP, maxOutputTokens } = await req.json()
  
  // Validate request
  // Call Gemini API with server-side key
  // Return response with proper error handling
  
  return new Response(JSON.stringify(response))
})
```

#### Client Usage
```javascript
// Client automatically uses Edge Function
const response = await callGemini(prompt, { temperature: 0.7 })
```

#### Deployment
See [EDGE_FUNCTION_DEPLOYMENT.md](./EDGE_FUNCTION_DEPLOYMENT.md) for detailed deployment instructions.

## 📁 Project Structure

```
src/
├── components/          # Reusable UI components
│   ├── Auth/           # Authentication components
│   ├── Chat/           # Chat and messaging
│   ├── Leaderboard/    # Leaderboard components
│   ├── Projects/       # Project management
│   ├── Quiz/           # Quiz system
│   └── UI/             # Generic UI components
├── contexts/           # React contexts
├── hooks/              # Custom React hooks
├── lib/                # Utility libraries
│   ├── api.js          # API client
│   ├── auth.js         # Authentication helpers
│   ├── geminiClient.js # AI integration
│   └── supabaseClient.js # Supabase client
├── pages/              # Page components
│   ├── Auth/           # Login/Register pages
│   ├── Dashboards/     # Role-specific dashboards
│   └── Landing.jsx     # Landing page
└── styles/             # Global styles
```

## 🚀 Deployment

### Environment Variables for Production
Set these in your hosting platform:
- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_ANON_KEY`
- `VITE_GEMINI_KEY` (or use Edge Functions)

### Build for Production
```bash
npm run build
```

### Hosting Platforms
- **Vercel**: Connect GitHub repo, set environment variables
- **Netlify**: Deploy from Git, configure environment variables
- **Supabase**: Use Supabase Hosting for full-stack deployment

## 🔧 Available Scripts

- `npm run dev` - Start development server
- `npm run build` - Build for production
- `npm run preview` - Preview production build
- `npm run lint` - Run ESLint

## 📚 Features

### For Students
- AI-generated quizzes tailored to skill level
- Project portfolio management
- Real-time chat with mentors and peers
- Gamified learning with points and leaderboards
- Assignment tracking and submission

### For Mentors
- Quiz creation and management
- Student progress monitoring
- Chat moderation and support
- Analytics dashboard
- Assignment verification

### For Companies
- Talent discovery and recruitment
- Student portfolio browsing
- Direct communication with top performers
- Analytics on student engagement

### For Admins
- User management and role assignment
- System monitoring and audit logs
- Content moderation
- Platform analytics

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License.

## 🆘 Support

For support and questions:
- Create an issue in the repository
- Check the documentation in `/docs`
- Review the Supabase setup guide

---

**Note**: Remember to keep your API keys secure and never commit them to version control. Use environment variables and consider Edge Functions for production deployments.