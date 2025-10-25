# Supabase Edge Function Deployment Guide

## Deploying the Gemini Proxy Edge Function

### 1. Install Supabase CLI

```bash
npm install -g supabase
```

### 2. Login to Supabase

```bash
supabase login
```

### 3. Link to Your Project

```bash
supabase link --project-ref your-project-ref
```

### 4. Set Environment Variables

Set the Gemini API key in your Supabase project:

```bash
supabase secrets set GEMINI_KEY=your_gemini_api_key_here
```

Or via the Supabase dashboard:
1. Go to Settings > Edge Functions
2. Add secret: `GEMINI_KEY` with your Gemini API key

### 5. Deploy the Edge Function

```bash
supabase functions deploy gemini-proxy
```

### 6. Test the Edge Function

```bash
# Test locally
supabase functions serve

# Test deployed function
curl -X POST 'https://your-project-ref.supabase.co/functions/v1/gemini-proxy' \
  -H 'Authorization: Bearer your-anon-key' \
  -H 'Content-Type: application/json' \
  -d '{"prompt": "Hello, how are you?"}'
```

### 7. Update Client Configuration

The client will automatically use the Edge Function instead of direct API calls. No additional configuration needed.

## Security Benefits

- ✅ API keys are kept secure on the server
- ✅ Rate limiting and usage tracking
- ✅ Request validation and sanitization
- ✅ CORS handling
- ✅ Error handling and logging
- ✅ No client-side API key exposure

## Environment Variables

Required environment variables in Supabase:
- `GEMINI_KEY`: Your Google Gemini API key

## Monitoring

Monitor Edge Function usage in the Supabase dashboard:
- Go to Edge Functions > gemini-proxy
- View logs, metrics, and errors
- Set up alerts for failures
