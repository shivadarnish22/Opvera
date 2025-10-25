# AI Features Documentation

This document describes the AI features integrated into Opvera using Google's Gemini API.

## Features Overview

### 1. Student AI Chat
- **Location**: `src/lib/geminiClient.js` - `chatAI()` function
- **API**: `src/lib/api.js` - `chatApi.sendAIMessage()`
- **UI**: `src/components/Chat/ChatWindow.jsx`

**How it works:**
- Students can chat with AI in channels marked as AI-enabled
- AI responses include user role, skills, course context, and project context
- Messages are stored with metadata indicating AI responses
- Supports conversation history for context-aware responses

**Usage:**
```javascript
// Send AI message
const { userMessage, aiMessage } = await chatApi.sendAIMessage(
  channelId,
  userId,
  messageContent,
  {
    role: 'student',
    skills: ['React', 'JavaScript'],
    course: 'Web Development',
    project: 'Portfolio Website'
  }
);
```

### 2. Quiz Generation
- **Location**: `src/lib/geminiClient.js` - `generateQuiz()` function
- **API**: `src/lib/api.js` - `quizApi.generateQuiz()`
- **UI**: `src/components/Quiz/QuizGenerator.jsx`

**How it works:**
- Generates 5 multiple-choice questions based on topic and difficulty
- Validates JSON response structure
- Stores quiz in database with AI metadata
- Supports beginner, intermediate, and advanced difficulty levels

**Usage:**
```javascript
// Generate quiz
const quiz = await quizApi.generateQuiz(
  'React Hooks',           // topic
  'intermediate',          // difficulty
  userId                   // student ID
);
```

### 3. AI-Powered Grading
- **Location**: `src/lib/geminiClient.js` - `gradeQuizAnswers()` function
- **API**: `src/lib/api.js` - `quizAttemptApi.submitQuizWithGrading()`
- **UI**: `src/components/Quiz/QuizResults.jsx`

**How it works:**
- Provides detailed feedback on each question
- Identifies strengths and improvement areas
- Gives encouraging and constructive feedback
- Falls back to basic scoring if AI grading fails

**Usage:**
```javascript
// Submit quiz with AI grading
const result = await quizAttemptApi.submitQuizWithGrading(
  quizId,
  studentId,
  userAnswers
);

// Result includes:
// - attempt: quiz attempt record
// - aiGrading: detailed AI feedback
// - basicScore: fallback score
// - correctAnswers: number of correct answers
// - totalQuestions: total questions
```

## Database Schema Updates

### Quizzes Table
```sql
ALTER TABLE quizzes ADD COLUMN description TEXT;
ALTER TABLE quizzes ADD COLUMN difficulty TEXT CHECK (difficulty IN ('beginner', 'intermediate', 'advanced'));
ALTER TABLE quizzes ADD COLUMN topic TEXT;
ALTER TABLE quizzes ADD COLUMN ai_generated BOOLEAN DEFAULT FALSE;
ALTER TABLE quizzes ADD COLUMN metadata JSONB DEFAULT '{}'::jsonb;
```

### Quiz Attempts Table
```sql
ALTER TABLE quiz_attempts ADD COLUMN completed_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE quiz_attempts ADD COLUMN metadata JSONB DEFAULT '{}'::jsonb;
```

### Channels Table
```sql
ALTER TABLE channels ADD COLUMN metadata JSONB DEFAULT '{}'::jsonb;
-- Update type constraint to include 'ai'
ALTER TABLE channels DROP CONSTRAINT channels_type_check;
ALTER TABLE channels ADD CONSTRAINT channels_type_check CHECK (type IN ('group', 'private', 'global', 'ai'));
```

### Messages Table
- Uses existing `metadata` field to store AI flags and context

## Environment Setup

Add to your `.env` file:
```env
VITE_GEMINI_KEY=your_gemini_api_key_here
```

## Error Handling

The implementation includes robust error handling:
- Rate limiting (1 second between requests)
- Retry logic with exponential backoff (3 attempts)
- JSON validation for AI responses
- Fallback mechanisms for failed AI operations
- Safety settings for content filtering

## Rate Limiting

- 1 second delay between API calls
- Maximum 3 retry attempts
- Exponential backoff on failures
- 30-second timeout per request

## Safety Features

- Content filtering for harmful content
- JSON structure validation
- Input sanitization
- Error boundary handling

## Example Integration

### Student Dashboard Quiz Generation
```javascript
// In Student Quizzes page
const handleGenerateQuiz = async (topic, difficulty) => {
  try {
    const quiz = await quizApi.generateQuiz(topic, difficulty, user.id);
    setCurrentQuiz(quiz);
    setView('quiz');
  } catch (error) {
    console.error('Failed to generate quiz:', error);
  }
};
```

### AI Chat Integration
```javascript
// In ChatWindow component
const handleSendMessage = async (message) => {
  if (isAIChat) {
    const context = {
      role: user.role,
      skills: user.skills,
      course: channel.metadata?.course
    };
    
    const { userMessage, aiMessage } = await chatApi.sendAIMessage(
      channel.id,
      user.id,
      message,
      context
    );
    
    setMessages(prev => [...prev, userMessage, aiMessage]);
  }
};
```

## Performance Considerations

- AI responses are cached in the database
- Rate limiting prevents API abuse
- Fallback mechanisms ensure functionality even if AI fails
- Database indices optimize query performance

## Future Enhancements

- Support for different AI models
- Custom AI personalities for different subjects
- Advanced analytics on AI interactions
- Integration with learning management systems
- Multi-language support
