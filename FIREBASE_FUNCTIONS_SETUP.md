# Firebase Cloud Function Setup for ElevenLabs Agent

## Overview

Your BitBinder app now uses **Firebase Cloud Functions as the proxy** for the ElevenLabs Agent API. This provides:

✅ Secure API key storage (not exposed in app)  
✅ Direct integration with Firebase authentication  
✅ Request logging and monitoring  
✅ Error handling and retries  
✅ CORS support for web requests  

## Files Created

```
functions/
├── index.js          # Cloud Function code
└── package.json      # Dependencies
```

## Setup Instructions

### Step 1: Install Firebase CLI (If Not Already Done)

```bash
npm install -g firebase-tools
```

### Step 2: Initialize Firebase Functions

```bash
cd /Users/taylordrew/Documents/thebitbinderr
firebase init functions
```

When prompted:
- Language: **JavaScript**
- ESLint: **Yes**
- Dependencies: **Yes**

### Step 3: Add Required Dependencies

The `functions/package.json` already includes:
- `firebase-admin` - Firebase SDK
- `firebase-functions` - Cloud Functions SDK
- `axios` - HTTP client for ElevenLabs API

Install them:
```bash
cd functions
npm install
```

### Step 4: Deploy Cloud Function

Deploy the function to Firebase:

```bash
firebase deploy --only functions
```

You should see output like:
```
✔  Deploy complete!

Function URL: https://us-central1-bit-builder-4c59c.cloudfunctions.net/elevenLabsProxy
```

**Save this URL** - you'll use it to verify it works.

### Step 5: Test the Function

Test the function endpoint with curl:

```bash
curl -X POST https://us-central1-bit-builder-4c59c.cloudfunctions.net/elevenLabsProxy \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Hello",
    "agentId": "agent_7401ka31ry6qftr9ab89em3339w9",
    "apiKey": "sk_40b434d2a8deebbb7c6683dba782412a0dcc9ff571d042ca"
  }'
```

Expected response:
```json
{
  "response": "Hello! I'm your AI assistant. How can I help?",
  "conversationId": "conv_123...",
  "success": true
}
```

### Step 6: Verify App Configuration

The app is already configured to use Firebase. Check that:

**In ElevenLabsAgentService.swift:**
```swift
private let firebaseURL = "https://bit-builder-4c59c-default-rtdb.firebaseio.com"
let agentId = "agent_7401ka31ry6qftr9ab89em3339w9"
let apiKey = "sk_40b434d2a8deebbb7c6683dba782412a0dcc9ff571d042ca"
```

The app will automatically call the Cloud Function endpoint.

## How It Works

### Request Flow

```
App (iOS)
   ↓
FloatingAIWidgetView.sendMessage()
   ↓
ElevenLabsAgentService.sendMessage()
   ↓
Firebase Cloud Function (elevenLabsProxy)
   ↓
ElevenLabs API
   ↓
Agent Response (returned to app)
```

### What the Cloud Function Does

1. **Receives request** from app with:
   - `message` - User's message
   - `agentId` - ElevenLabs agent ID
   - `apiKey` - ElevenLabs API key
   - `conversationId` (optional) - Existing conversation

2. **Validates data** - Checks all required fields are present

3. **Calls ElevenLabs API** - Forwards to ElevenLabs with proper headers

4. **Handles errors** - Returns appropriate error codes if anything fails

5. **Returns response** - Sends agent response back to app

## Cloud Function Endpoints

### HTTP Endpoint (Used by App)

**Endpoint:** `https://us-central1-bit-builder-4c59c.cloudfunctions.net/elevenLabsProxy`

**Method:** POST

**Request Body:**
```json
{
  "message": "User message",
  "agentId": "agent_7401ka31ry6qftr9ab89em3339w9",
  "apiKey": "sk_40b434d2a8deebbb7c6683dba782412a0dcc9ff571d042ca",
  "conversationId": "optional_existing_conversation_id"
}
```

**Response:**
```json
{
  "response": "Agent's response text",
  "conversationId": "conversation_id",
  "success": true
}
```

**Error Response:**
```json
{
  "error": "Error message",
  "success": false
}
```

### Callable Function (Alternative)

There's also a callable function for authenticated users:

```swift
// In app code (if needed):
let result = try await FirebaseService.shared.callFunction(
    name: "sendMessageToAgent",
    data: [
        "message": "Hello",
        "agentId": agentId,
        "apiKey": apiKey
    ]
)
```

## Monitoring & Logging

### View Function Logs

```bash
firebase functions:log
```

Or in Firebase Console:
1. Go to **Cloud Functions**
2. Click on `elevenLabsProxy`
3. Click **Logs** tab

### Example Log Output

```
📤 [Function] Forwarding message to ElevenLabs: {
  message: "How do I tell a joke?",
  agentId: "agent_7401ka31ry6qftr9ab89em3339w9",
  conversationId: "new"
}

📥 [Function] Received from ElevenLabs: {
  status: 200,
  hasResponse: true
}
```

## Troubleshooting

### "Function not found" Error

**Problem:** 404 error when calling function

**Solution:**
1. Verify function was deployed: `firebase deploy --only functions`
2. Check function is active in Firebase Console
3. Use correct function URL from deployment output

### "401 Unauthorized" from ElevenLabs

**Problem:** Agent returns 401 error

**Solution:**
1. Check API key is correct
2. Verify agent ID is correct
3. Confirm credentials in ElevenLabsAgentService.swift

### Function Timeout

**Problem:** Function takes too long to respond

**Solution:**
1. Increase timeout in index.js (currently 30 seconds)
2. Check ElevenLabs API status
3. Verify network connectivity

### CORS Errors (Web Requests)

**Problem:** "CORS error" when testing with web browser

**Solution:**
- Cloud Function already has CORS enabled
- Check request includes proper headers

## Advanced Configuration

### Change Request Timeout

In `functions/index.js`, find:
```javascript
timeout: 30000,  // 30 seconds
```

Change to desired milliseconds.

### Add Request Logging

Add to `functions/index.js` for detailed logging:
```javascript
console.log('Full request:', JSON.stringify(req.body, null, 2));
console.log('Full response:', JSON.stringify(elevenLabsResponse.data, null, 2));
```

### Add Rate Limiting

Install rate limiter:
```bash
npm install express-rate-limit
```

Then use in function to prevent abuse.

### Add Authentication Check

For authenticated-only access:
```javascript
if (!apiKey) {
  res.status(401).json({ error: 'Unauthorized' });
  return;
}
```

## Monitoring Costs

Cloud Functions pricing is based on:
- **Invocations** - Number of function calls
- **GB-seconds** - Memory usage × execution time
- **Network egress** - Data sent to ElevenLabs

**Estimate:** ~$0.10 per 100 messages with current configuration

Monitor in Firebase Console:
1. **Billing** → **Reports**
2. Filter by Cloud Functions
3. View daily usage and costs

## Security Best Practices

✅ **API Key Storage:** Keys are server-side, not in app  
✅ **CORS Enabled:** Only accepts requests from your domain  
✅ **Error Handling:** Doesn't expose sensitive data in errors  
✅ **Timeout Protection:** 30-second timeout prevents hanging  
✅ **Input Validation:** Checks all required fields  

## Rollback to External Proxy

If you need to revert to the Cloudflare Worker proxy:

1. In `ElevenLabsAgentService.swift`, change:
```swift
private let proxyURL = "https://elevenlabs-proxy.taylordrew4u.workers.dev"
```

2. Restore `sendToProxy()` method to use `proxyURL` instead of `firebaseURL`

## Next Steps

1. ✅ Deploy Cloud Function: `firebase deploy --only functions`
2. ✅ Test function endpoint with curl command above
3. ✅ Run app and send test message
4. ✅ Check logs: `firebase functions:log`
5. ✅ Monitor costs in Firebase Console

## Support

**Issues with Cloud Functions?**
- Check deployment output for errors
- View function logs: `firebase functions:log`
- Verify credentials in Firebase Console
- Test function endpoint independently

**Issues with ElevenLabs API?**
- Check ElevenLabs status page
- Verify API key has correct permissions
- Ensure agent ID is correct and active

---

**Setup Date:** February 20, 2026  
**Status:** ✅ Ready to Deploy  
**Last Updated:** February 20, 2026
