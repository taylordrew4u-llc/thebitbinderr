# ElevenLabs API Connection - Troubleshooting Guide

## Issue: Widget Not Answering Calls

Your app now uses a **dual-method approach** for maximum reliability:

1. **Direct ElevenLabs API** - Primary method (fastest)
2. **Firebase Cloud Function** - Fallback method

## How to Diagnose

### Step 1: Check Console Output

When you send a message, look for this sequence in Xcode console:

```
📤 [Widget] Sending message: <your message>
✅ [Widget] Saved user message to Firebase
🚀 [Widget] Calling ElevenLabs service...
🎤 [ElevenLabs] Attempting direct API call...
🎤 [ElevenLabs Direct] Request URL: https://api.elevenlabs.io/v1/convai/agents/agent_7401ka31ry6qftr9ab89em3339w9
🎤 [ElevenLabs Direct] Request Body: {"message": "..."}
🎤 [ElevenLabs Direct] API Key: sk_40b434d2a8deebbb7c6683...
🎤 [ElevenLabs Direct] Response Status: 200
🎤 [ElevenLabs Direct] Response Data: {...}
📥 [Widget] Received response: <agent response>
✅ [Widget] Saved AI response to Firebase
```

### Step 2: Check Response Status Code

Find the line: `🎤 [ElevenLabs Direct] Response Status: XXX`

**Status Code Meanings:**

| Code | Meaning | Solution |
|------|---------|----------|
| 200-201 | ✅ Success | Working! |
| 400 | Bad Request | Check message format |
| 401 | Unauthorized | **API key is wrong** |
| 403 | Forbidden | Agent ID doesn't match API key |
| 404 | Not Found | Agent ID is invalid |
| 429 | Rate Limited | Too many requests - wait |
| 500-503 | Server Error | ElevenLabs API down |

### Step 3: Verify Credentials

**Check these are correct in console output:**

```
API Key: sk_40b434d2a8deebbb7c6683dba782412a0dcc9ff571d042ca
Agent ID: agent_7401ka31ry6qftr9ab89em3339w9
```

If they don't match, update in `ElevenLabsAgentService.swift`:

```swift
let agentId = "agent_7401ka31ry6qftr9ab89em3339w9"
let apiKey = "sk_40b434d2a8deebbb7c6683dba782412a0dcc9ff571d042ca"
```

## Common Issues & Solutions

### Issue 1: "Response Status: 401"

**Problem:** API key is invalid or expired

**Solution:**
1. Go to ElevenLabs console: https://elevenlabs.io/app
2. Get your API key from Settings → API Keys
3. Verify it matches in code above
4. Check key hasn't been revoked

### Issue 2: "Response Status: 403"

**Problem:** API key doesn't have access to this agent

**Solution:**
1. Verify agent ID is correct: `agent_7401ka31ry6qftr9ab89em3339w9`
2. Check agent is active in ElevenLabs console
3. Verify API key has permissions for this agent
4. Try regenerating API key

### Issue 3: "Response Status: 404"

**Problem:** Agent doesn't exist with that ID

**Solution:**
1. Go to ElevenLabs console
2. Check agent ID in your agents list
3. Copy exact agent ID from console
4. Update in `ElevenLabsAgentService.swift`

### Issue 4: No Response Data

**Problem:** Status is 200 but no message in response

**Solution:**
1. Check response JSON structure:
   - Look for `"response"` field
   - Look for `"message"` field
   - Look for `"text"` field
2. Copy the full response from console:
   `🎤 [ElevenLabs Direct] Response Data: {...}`
3. Check if it contains the agent's response

### Issue 5: "All methods failed"

**Problem:** Both direct API and fallback failed

**Solution:**
1. Check internet connection
2. Check firewall/VPN not blocking API
3. Try from different network
4. Check ElevenLabs status: https://status.elevenlabs.io

## Testing Direct API

### Test with curl

Open terminal and run:

```bash
curl -X POST https://api.elevenlabs.io/v1/convai/agents/agent_7401ka31ry6qftr9ab89em3339w9 \
  -H "Content-Type: application/json" \
  -H "xi-api-key: sk_40b434d2a8deebbb7c6683dba782412a0dcc9ff571d042ca" \
  -d '{"message": "Hello"}'
```

**Expected response:**
```json
{
  "response": "Hello! I'm your AI assistant. How can I help?",
  "conversation_id": "conv_123..."
}
```

**If you get:**
- `"401 Unauthorized"` → API key is wrong
- `"403 Forbidden"` → Agent ID mismatch
- `"404 Not Found"` → Agent doesn't exist
- Connection timeout → Network issue

### Test Agent in ElevenLabs Console

1. Go to https://elevenlabs.io/app
2. Select your agent
3. Click "Test Agent"
4. Send a message
5. If it works here but not in app → issue is in app config
6. If it doesn't work here → issue is with agent or API key

## Debug the Full Flow

### Step-by-Step Testing

1. **Test API Key:**
   ```bash
   curl -H "xi-api-key: sk_40b434d2a8deebbb7c6683dba782412a0dcc9ff571d042ca" \
     https://api.elevenlabs.io/v1/user
   ```
   Should return user info (confirms key is valid)

2. **Test Agent Exists:**
   ```bash
   curl -H "xi-api-key: sk_40b434d2a8deebbb7c6683dba782412a0dcc9ff571d042ca" \
     https://api.elevenlabs.io/v1/convai/agents/agent_7401ka31ry6qftr9ab89em3339w9
   ```
   Should return agent details

3. **Test Send Message:**
   (See curl example above)
   Should return response

4. **Test in App:**
   Run app and send test message
   Should see full debug output

## Network Debugging

### Check if Firewall is Blocking

```bash
# Test connectivity to ElevenLabs API
ping api.elevenlabs.io

# Test HTTPS connection
curl -v https://api.elevenlabs.io/v1/user
```

### Check VPN

- Try disabling VPN
- Try different network (WiFi → Mobile data)
- Check if organization firewall blocks API calls

### Check DNS

```bash
# Verify DNS resolves correctly
nslookup api.elevenlabs.io

# Should return IP address
```

## App Debugging

### Enable Network Logging

Add to AppDelegate or main app init:

```swift
let config = URLSessionConfiguration.default
config.waitsForConnectivity = true
```

### Check Console for Network Errors

Look for messages like:
- "NSURLErrorDomain" → Network error
- "Certificate" → SSL/TLS issue
- "Timeout" → Request took too long

### Log Full Response Headers

The app logs response status, but you can add header logging:

```swift
print("Response Headers: \(httpResponse.allHeaderFields)")
```

## Fallback Method (Firebase Cloud Function)

If direct API fails, app tries Firebase Cloud Function:

```
Direct API failed
  ↓
Fallback to Firebase Function
  ↓
Firebase Function calls ElevenLabs API
  ↓
Returns response to app
```

### Deploy Cloud Function

If you want to use the fallback:

```bash
cd /Users/taylordrew/Documents/thebitbinderr
firebase deploy --only functions
```

Logs will show:
```
🎤 [Firebase Function] Response Status: 200
```

## Success Checklist

✅ Direct API status is 200-201  
✅ Response contains valid JSON  
✅ Response has `"response"` or `"message"` field  
✅ Message text appears in widget  
✅ Console shows `📥 [Widget] Received response:`  
✅ Message saved to Firebase  

## Still Not Working?

### Collect Information

1. Screenshot of console output
2. Full response data (from `Response Data:` line)
3. Network status code
4. Test with curl command above
5. Verify credentials one more time

### Check These

- [ ] API key is correct (no typos)
- [ ] Agent ID is correct (no typos)
- [ ] Agent exists in ElevenLabs console
- [ ] Agent is active/enabled
- [ ] Internet connection working
- [ ] No firewall blocking api.elevenlabs.io
- [ ] Latest version of app deployed

### Get Help

1. Share console output with support
2. Share curl test results
3. Share error code and message
4. Verify credentials with ElevenLabs support

---

**Configuration:**
- Agent ID: `agent_7401ka31ry6qftr9ab89em3339w9`
- API Key: `sk_40b434d2a8deebbb7c6683dba782412a0dcc9ff571d042ca`
- Primary: Direct ElevenLabs API
- Fallback: Firebase Cloud Function

**Status**: 🔍 Diagnosing connection issues  
**Last Updated**: February 21, 2026
