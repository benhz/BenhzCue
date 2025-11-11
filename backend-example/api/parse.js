// backend-example/api/parse.js
// Example Vercel serverless function for Dify integration

import formidable from 'formidable';
import fs from 'fs';
import FormData from 'form-data';
import fetch from 'node-fetch';

export const config = {
  api: {
    bodyParser: false,
  },
};

export default async function handler(req, res) {
  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    // Parse multipart form data
    const form = formidable({ maxFileSize: 10 * 1024 * 1024 }); // 10MB limit

    const [fields, files] = await new Promise((resolve, reject) => {
      form.parse(req, (err, fields, files) => {
        if (err) reject(err);
        else resolve([fields, files]);
      });
    });

    const imageFile = files.image;
    const additionalText = fields.text || '';

    if (!imageFile) {
      return res.status(400).json({ error: 'No image provided' });
    }

    // Step 1: Upload image to Dify
    console.log('Uploading image to Dify...');
    const uploadFormData = new FormData();
    uploadFormData.append('file', fs.createReadStream(imageFile.filepath), {
      filename: imageFile.originalFilename || 'image.jpg',
      contentType: imageFile.mimetype,
    });
    uploadFormData.append('user', 'ios-app-user');

    const uploadResponse = await fetch('https://api.dify.ai/v1/files/upload', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${process.env.DIFY_API_KEY}`,
        ...uploadFormData.getHeaders(),
      },
      body: uploadFormData,
    });

    if (!uploadResponse.ok) {
      const error = await uploadResponse.text();
      console.error('Dify upload error:', error);
      return res.status(500).json({ error: 'Failed to upload image to Dify' });
    }

    const uploadData = await uploadResponse.json();
    const fileId = uploadData.id;

    console.log('Image uploaded, file ID:', fileId);

    // Step 2: Run Dify workflow
    console.log('Running Dify workflow...');
    const workflowResponse = await fetch(
      `https://api.dify.ai/v1/workflows/${process.env.DIFY_WORKFLOW_ID}/run`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${process.env.DIFY_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          inputs: {
            file_id: fileId,
            additional_text: additionalText,
          },
          response_mode: 'blocking',
          user: 'ios-app-user',
        }),
      }
    );

    if (!workflowResponse.ok) {
      const error = await workflowResponse.text();
      console.error('Dify workflow error:', error);
      return res.status(500).json({ error: 'Failed to run Dify workflow' });
    }

    const workflowData = await workflowResponse.json();
    console.log('Workflow completed');

    // Step 3: Parse and validate response
    let events = [];
    try {
      // Dify workflow should return events in outputs
      const outputText = workflowData.data.outputs.text || workflowData.data.outputs.result;
      events = JSON.parse(outputText).events || [];
    } catch (parseError) {
      console.error('Failed to parse events:', parseError);
      // Return empty events array if parsing fails
      events = [];
    }

    // Step 4: Optional - Delete image from Dify if configured
    if (process.env.DELETE_AFTER_PARSE === 'true') {
      try {
        await fetch(`https://api.dify.ai/v1/files/${fileId}`, {
          method: 'DELETE',
          headers: {
            Authorization: `Bearer ${process.env.DIFY_API_KEY}`,
          },
        });
        console.log('Image deleted from Dify');
      } catch (deleteError) {
        console.error('Failed to delete image:', deleteError);
        // Non-critical, continue
      }
    }

    // Clean up local temp file
    fs.unlinkSync(imageFile.filepath);

    // Return structured response
    return res.status(200).json({
      events: events,
      metadata: {
        processed_at: new Date().toISOString(),
        file_id: fileId,
        event_count: events.length,
      },
    });
  } catch (error) {
    console.error('Parse error:', error);
    return res.status(500).json({
      error: error.message,
      details: error.stack,
    });
  }
}
