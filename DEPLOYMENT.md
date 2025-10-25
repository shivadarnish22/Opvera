# Deployment Configuration

## Frontend Deployment (Vercel/Netlify)

### Environment Variables
Set these environment variables in your deployment platform:

```bash
# Supabase Configuration
VITE_SUPABASE_URL=your_supabase_project_url
VITE_SUPABASE_ANON_KEY=your_supabase_anon_key

# Gemini API (for client-side operations - consider moving to Edge Functions)
VITE_GEMINI_KEY=your_gemini_api_key
```

### Vercel Deployment

1. **Connect Repository**: Link your GitHub repository to Vercel
2. **Environment Variables**: Add the above environment variables in Vercel dashboard
3. **Build Settings**:
   - Framework Preset: Vite
   - Build Command: `npm run build`
   - Output Directory: `dist`
   - Install Command: `npm install`

### Netlify Deployment

1. **Connect Repository**: Link your GitHub repository to Netlify
2. **Environment Variables**: Add the above environment variables in Netlify dashboard
3. **Build Settings**:
   - Build Command: `npm run build`
   - Publish Directory: `dist`
   - Node Version: `18.x`

## Supabase Edge Functions (Recommended for Sensitive Operations)

### Setup Edge Functions

1. **Install Supabase CLI**:
   ```bash
   npm install -g supabase
   ```

2. **Initialize Edge Functions**:
   ```bash
   supabase init
   supabase functions new gemini-proxy
   ```

3. **Edge Function Example** (`supabase/functions/gemini-proxy/index.ts`):
   ```typescript
   import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
   import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

   const corsHeaders = {
     'Access-Control-Allow-Origin': '*',
     'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
   }

   serve(async (req) => {
     if (req.method === 'OPTIONS') {
       return new Response('ok', { headers: corsHeaders })
     }

     try {
       const { prompt, options = {} } = await req.json()
       
       // Verify user authentication
       const authHeader = req.headers.get('Authorization')
       if (!authHeader) {
         return new Response('Unauthorized', { status: 401, headers: corsHeaders })
       }

       const supabaseClient = createClient(
         Deno.env.get('SUPABASE_URL') ?? '',
         Deno.env.get('SUPABASE_ANON_KEY') ?? '',
         { global: { headers: { Authorization: authHeader } } }
       )

       const { data: { user }, error } = await supabaseClient.auth.getUser()
       if (error || !user) {
         return new Response('Unauthorized', { status: 401, headers: corsHeaders })
       }

       // Call Gemini API with server-side key
       const response = await fetch(
         `https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=${Deno.env.get('GEMINI_KEY')}`,
         {
           method: 'POST',
           headers: { 'Content-Type': 'application/json' },
           body: JSON.stringify({
             contents: [{ parts: [{ text: prompt }] }],
             generationConfig: {
               temperature: options.temperature || 0.7,
               topK: options.topK || 40,
               topP: options.topP || 0.95,
               maxOutputTokens: options.maxOutputTokens || 1024,
             },
             safetySettings: [
               { category: "HARM_CATEGORY_HARASSMENT", threshold: "BLOCK_MEDIUM_AND_ABOVE" },
               { category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_MEDIUM_AND_ABOVE" },
               { category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_MEDIUM_AND_ABOVE" },
               { category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_MEDIUM_AND_ABOVE" }
             ]
           })
         }
       )

       const data = await response.json()
       return new Response(JSON.stringify(data), {
         headers: { ...corsHeaders, 'Content-Type': 'application/json' }
       })
     } catch (error) {
       return new Response(JSON.stringify({ error: error.message }), {
         status: 500,
         headers: { ...corsHeaders, 'Content-Type': 'application/json' }
       })
     }
   })
   ```

4. **Deploy Edge Functions**:
   ```bash
   supabase functions deploy gemini-proxy
   ```

5. **Set Edge Function Environment Variables**:
   ```bash
   supabase secrets set GEMINI_KEY=your_gemini_api_key
   ```

### Update Client Code to Use Edge Functions

Update `src/lib/geminiClient.js` to use Edge Functions for sensitive operations:

```javascript
// For sensitive operations, use Edge Functions
export async function callGeminiSecure(prompt, opts = {}) {
  const { data: { session } } = await supabase.auth.getSession()
  
  if (!session) {
    throw new Error('Authentication required')
  }

  const response = await fetch(`${supabase.supabaseUrl}/functions/v1/gemini-proxy`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${session.access_token}`,
      'apikey': supabase.supabaseKey
    },
    body: JSON.stringify({ prompt, options: opts })
  })

  if (!response.ok) {
    throw new Error(`Edge function error: ${response.statusText}`)
  }

  return await response.json()
}
```

## CI/CD Pipeline

### GitHub Actions Workflow (`.github/workflows/deploy.yml`)

```yaml
name: Deploy to Production

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test-and-deploy:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
        
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'
          
      - name: Install dependencies
        run: npm ci
        
      - name: Run linter
        run: npm run lint
        
      - name: Run tests (if available)
        run: npm test --if-present
        
      - name: Build application
        run: npm run build
        env:
          VITE_SUPABASE_URL: ${{ secrets.VITE_SUPABASE_URL }}
          VITE_SUPABASE_ANON_KEY: ${{ secrets.VITE_SUPABASE_ANON_KEY }}
          VITE_GEMINI_KEY: ${{ secrets.VITE_GEMINI_KEY }}
          
      - name: Deploy to Vercel
        if: github.ref == 'refs/heads/main'
        uses: amondnet/vercel-action@v20
        with:
          vercel-token: ${{ secrets.VERCEL_TOKEN }}
          vercel-org-id: ${{ secrets.VERCEL_ORG_ID }}
          vercel-project-id: ${{ secrets.VERCEL_PROJECT_ID }}
          working-directory: ./
```

### Required GitHub Secrets

Add these secrets to your GitHub repository:

- `VITE_SUPABASE_URL`: Your Supabase project URL
- `VITE_SUPABASE_ANON_KEY`: Your Supabase anonymous key
- `VITE_GEMINI_KEY`: Your Gemini API key
- `VERCEL_TOKEN`: Vercel deployment token
- `VERCEL_ORG_ID`: Vercel organization ID
- `VERCEL_PROJECT_ID`: Vercel project ID

## Security Best Practices

### Environment Variables
- ✅ Use `VITE_` prefix for client-side environment variables
- ✅ Store sensitive keys (like `GEMINI_KEY`) in Edge Functions or server-side
- ✅ Never commit `.env` files to version control
- ✅ Use different API keys for development and production

### Rate Limiting
- Implement client-side rate limiting for API calls
- Use Supabase RLS (Row Level Security) for database access
- Consider implementing request throttling for Edge Functions

### Content Security Policy
Add CSP headers to your deployment:

```html
<meta http-equiv="Content-Security-Policy" content="
  default-src 'self';
  script-src 'self' 'unsafe-inline' 'unsafe-eval';
  style-src 'self' 'unsafe-inline';
  img-src 'self' data: https:;
  connect-src 'self' https://*.supabase.co https://generativelanguage.googleapis.com;
  font-src 'self';
">
```

## Monitoring and Logging

### Error Tracking
- Consider integrating Sentry or similar service for error tracking
- Log authentication events and API usage
- Monitor Edge Function performance and errors

### Analytics
- Track user interactions and feature usage
- Monitor API response times and error rates
- Set up alerts for critical errors

## Database Security

### Row Level Security (RLS)
Ensure all tables have proper RLS policies:

```sql
-- Example RLS policy for profiles table
CREATE POLICY "Users can view their own profile" ON profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile" ON profiles
  FOR UPDATE USING (auth.uid() = id);
```

### API Security
- Validate all inputs on both client and server side
- Use prepared statements for database queries
- Implement proper CORS policies
- Rate limit API endpoints

## Backup and Recovery

### Database Backups
- Enable automatic backups in Supabase
- Test backup restoration procedures
- Document recovery procedures

### Code Backup
- Use Git for version control
- Tag releases for easy rollback
- Maintain staging environment for testing

## Performance Optimization

### Frontend
- Enable gzip compression
- Use CDN for static assets
- Implement lazy loading for components
- Optimize images and assets

### Backend
- Use database indexes appropriately
- Implement caching strategies
- Monitor query performance
- Use connection pooling

## Troubleshooting

### Common Issues
1. **Environment Variables Not Loading**: Check VITE_ prefix and deployment platform settings
2. **CORS Errors**: Verify Supabase CORS configuration
3. **Authentication Issues**: Check session handling and token refresh
4. **Build Failures**: Verify all dependencies are properly installed

### Debug Mode
Enable debug mode in development:

```javascript
// In development only
if (import.meta.env.DEV) {
  console.log('Environment variables:', {
    supabaseUrl: import.meta.env.VITE_SUPABASE_URL,
    hasGeminiKey: !!import.meta.env.VITE_GEMINI_KEY
  })
}
```
