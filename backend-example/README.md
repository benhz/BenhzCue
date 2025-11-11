# Backend Example for Image to Calendar

This is a sample backend implementation using Vercel serverless functions to proxy requests between the iOS app and Dify API.

## Features

- Multipart form data handling for image uploads
- Secure API key management
- Automatic image cleanup after parsing
- CORS support for iOS app
- Error handling and logging

## Setup

### 1. Install Dependencies

```bash
cd backend-example
npm install
```

### 2. Configure Environment Variables

Create a `.env` file:

```bash
cp .env.example .env
```

Edit `.env` and add your Dify credentials:

```
DIFY_API_KEY=your-actual-api-key
DIFY_WORKFLOW_ID=your-actual-workflow-id
DELETE_AFTER_PARSE=true
```

### 3. Local Development

```bash
npm run dev
```

The API will be available at `http://localhost:3000/api/parse`

### 4. Deploy to Vercel

```bash
# Install Vercel CLI
npm install -g vercel

# Login
vercel login

# Deploy
npm run deploy
```

### 5. Configure Secrets

```bash
vercel secrets add dify-api-key "your-api-key"
vercel secrets add dify-workflow-id "your-workflow-id"
```

## API Endpoint

### POST /api/parse

**Request:**

```
Content-Type: multipart/form-data

Fields:
- image: File (required)
- text: String (optional)
```

**Response:**

```json
{
  "events": [
    {
      "type": "calendar",
      "title": "Team Meeting",
      "start": "2025-11-15T14:00:00Z",
      "end": "2025-11-15T15:00:00Z",
      "location": "Conference Room A",
      "notes": "Quarterly review",
      "confidence": 0.92,
      "pending_fields": []
    }
  ],
  "metadata": {
    "processed_at": "2025-11-11T10:30:00Z",
    "file_id": "file-123456",
    "event_count": 1
  }
}
```

## Testing

### Using cURL

```bash
curl -X POST http://localhost:3000/api/parse \
  -F "image=@/path/to/image.jpg" \
  -F "text=Add this to Wednesday afternoon"
```

### Using Postman

1. Create new POST request
2. URL: `http://localhost:3000/api/parse`
3. Body → form-data
4. Add key `image` (type: File), select image
5. Add key `text` (type: Text), enter optional context
6. Send

## Alternative Implementations

### Cloudflare Workers

```javascript
// worker.js
export default {
  async fetch(request, env) {
    if (request.method !== 'POST') {
      return new Response('Method not allowed', { status: 405 });
    }

    const formData = await request.formData();
    const image = formData.get('image');
    const text = formData.get('text') || '';

    // Forward to Dify
    const uploadForm = new FormData();
    uploadForm.append('file', image);

    const uploadResponse = await fetch('https://api.dify.ai/v1/files/upload', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${env.DIFY_API_KEY}`,
      },
      body: uploadForm,
    });

    const { id } = await uploadResponse.json();

    const workflowResponse = await fetch(
      `https://api.dify.ai/v1/workflows/${env.DIFY_WORKFLOW_ID}/run`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${env.DIFY_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          inputs: { file_id: id, additional_text: text },
          response_mode: 'blocking',
        }),
      }
    );

    const result = await workflowResponse.json();
    return new Response(JSON.stringify(result.data.outputs), {
      headers: { 'Content-Type': 'application/json' },
    });
  },
};
```

### Express.js (Traditional Server)

```javascript
// server.js
import express from 'express';
import multer from 'multer';
import FormData from 'form-data';
import fetch from 'node-fetch';
import fs from 'fs';

const app = express();
const upload = multer({ dest: 'uploads/' });

app.post('/api/parse', upload.single('image'), async (req, res) => {
  try {
    const formData = new FormData();
    formData.append('file', fs.createReadStream(req.file.path));

    const uploadResponse = await fetch('https://api.dify.ai/v1/files/upload', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${process.env.DIFY_API_KEY}`,
        ...formData.getHeaders(),
      },
      body: formData,
    });

    const { id } = await uploadResponse.json();

    const workflowResponse = await fetch(
      `https://api.dify.ai/v1/workflows/${process.env.DIFY_WORKFLOW_ID}/run`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${process.env.DIFY_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          inputs: {
            file_id: id,
            additional_text: req.body.text || '',
          },
          response_mode: 'blocking',
        }),
      }
    );

    const result = await workflowResponse.json();
    fs.unlinkSync(req.file.path); // Cleanup

    res.json(result.data.outputs);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.listen(3000, () => console.log('Server running on port 3000'));
```

## Security Considerations

1. **API Key Protection**: Never expose Dify API keys in the iOS app
2. **Rate Limiting**: Implement rate limiting to prevent abuse
3. **File Validation**: Validate file types and sizes
4. **CORS**: Configure appropriate CORS headers
5. **HTTPS**: Always use HTTPS in production

## Troubleshooting

### "Failed to upload image to Dify"

- Check API key is correct
- Verify file size is under limit (10MB default)
- Ensure image format is supported (JPEG, PNG)

### "Failed to run Dify workflow"

- Verify workflow ID is correct
- Check workflow is published and active
- Ensure workflow inputs match expected format

### "Events array is empty"

- Check Dify workflow output format
- Verify LLM prompt is returning valid JSON
- Review Dify workflow logs

## Performance Tips

1. Use CDN for static assets
2. Enable caching for repeated requests
3. Implement request queuing for high traffic
4. Monitor response times and set timeouts
5. Use async processing for large images

## Monitoring

Add logging and monitoring:

```javascript
// Example with Sentry
import * as Sentry from '@sentry/node';

Sentry.init({ dsn: process.env.SENTRY_DSN });

// In your error handler
catch (error) {
  Sentry.captureException(error);
  // ... rest of error handling
}
```

## License

MIT
