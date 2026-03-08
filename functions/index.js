/**
 * Firebase Cloud Function: ElevenLabs Agent Proxy
 * 
 * This function handles requests from the BitBinder app and forwards them to the ElevenLabs API
 * 
 * Deploy with:
 * firebase deploy --only functions:elevenLabsProxy
 * 
 * Configuration needed:
 * - Set environment variables in Firebase Console or .env.local
 */

const functions = require('firebase-functions');
const axios = require('axios');

// ElevenLabs API endpoint
const ELEVENLABS_API = 'https://api.elevenlabs.io/v1/convai/agents';

/**
 * HTTP Cloud Function to forward messages to ElevenLabs Agent
 */
exports.elevenLabsProxy = functions.https.onRequest(async (req, res) => {
  // Enable CORS
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed. Use POST.' });
    return;
  }

  try {
    const { message, agentId, apiKey, conversationId } = req.body;

    // Validate required fields
    if (!message || !agentId || !apiKey) {
      res.status(400).json({
        error: 'Missing required fields: message, agentId, apiKey',
      });
      return;
    }

    console.log('📤 [Function] Forwarding message to ElevenLabs:', {
      message,
      agentId,
      conversationId: conversationId || 'new',
    });

    // Build ElevenLabs API request
    const elevenLabsPayload = {
      message: message,
    };

    if (conversationId) {
      elevenLabsPayload.conversation_id = conversationId;
    }

    // Call ElevenLabs API
    const elevenLabsResponse = await axios.post(
      `${ELEVENLABS_API}/${agentId}`,
      elevenLabsPayload,
      {
        headers: {
          'xi-api-key': apiKey,
          'Content-Type': 'application/json',
        },
        timeout: 30000,
      }
    );

    console.log('📥 [Function] Received from ElevenLabs:', {
      status: elevenLabsResponse.status,
      hasResponse: !!elevenLabsResponse.data.response,
    });

    // Extract response data
    const responseData = {
      response: elevenLabsResponse.data.response || '',
      conversationId: elevenLabsResponse.data.conversation_id || conversationId,
      success: true,
    };

    // Return successful response
    res.status(200).json(responseData);
  } catch (error) {
    console.error('❌ [Function] Error calling ElevenLabs:', error.message);

    // Handle specific error types
    if (error.response) {
      // ElevenLabs API error
      const status = error.response.status;
      const data = error.response.data;

      console.error('ElevenLabs API Error:', {
        status,
        data,
      });

      res.status(status).json({
        error: 'ElevenLabs API error',
        details: data,
        success: false,
      });
    } else if (error.code === 'ECONNABORTED') {
      // Timeout
      res.status(504).json({
        error: 'Request timeout - ElevenLabs API took too long to respond',
        success: false,
      });
    } else {
      // Network or other error
      res.status(502).json({
        error: 'Failed to communicate with ElevenLabs API',
        message: error.message,
        success: false,
      });
    }
  }
});

/**
 * Callable Cloud Function version (alternative to HTTP)
 * Use this if you want better error handling and authentication
 */
exports.sendMessageToAgent = functions.https.onCall(async (data, context) => {
  // Verify user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  try {
    const { message, agentId, apiKey, conversationId } = data;

    if (!message || !agentId || !apiKey) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Missing required fields: message, agentId, apiKey'
      );
    }

    console.log('📤 [Callable] User ' + context.auth.uid + ' sending message');

    // Call ElevenLabs API
    const elevenLabsPayload = {
      message: message,
    };

    if (conversationId) {
      elevenLabsPayload.conversation_id = conversationId;
    }

    const elevenLabsResponse = await axios.post(
      `${ELEVENLABS_API}/${agentId}`,
      elevenLabsPayload,
      {
        headers: {
          'xi-api-key': apiKey,
          'Content-Type': 'application/json',
        },
        timeout: 30000,
      }
    );

    return {
      response: elevenLabsResponse.data.response || '',
      conversationId: elevenLabsResponse.data.conversation_id || conversationId,
      success: true,
    };
  } catch (error) {
    console.error('❌ [Callable] Error:', error.message);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to get response from agent: ' + error.message
    );
  }
});
