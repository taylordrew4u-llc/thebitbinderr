# How to Diagnose the Connection Issue

## What Changed

I've added **detailed debug logging** and a **test view** to help identify exactly what's failing.

## Step 1: Use the Test View

The best way to diagnose is to use the new test view:

**Add this code to a view or NavigationStack** to test the connection:

```swift
NavigationLink(destination: ElevenLabsTestView()) {
    Text("🧪 Test ElevenLabs API")
}
```

Or access it through your app's menu.

## Step 2: Run the Test

1. Build and run the app
2. Navigate to the test view
3. Click "Send Test Message"
4. **Keep Xcode open and watch the console**

## Step 3: Read the Console Output

Look for this sequence:

```
🎤 [ElevenLabs] Sending message: Hello, test message
🎤 [ElevenLabs] Attempting direct API call...
🎤 [ElevenLabs Direct] Creating request to: https://api.elevenlabs.io/v1/convai/agents/agent_7401ka31ry6qftr9ab89em3339w9
🎤 [ElevenLabs Direct] Request URL: https://api.elevenlabs.io/v1/convai/agents/agent_7401ka31ry6qftr9ab89em3339w9
🎤 [ElevenLabs Direct] Request Body: {"message": "Hello, test message"}
🎤 [ElevenLabs Direct] API Key set: sk_40b434d2a8deebbb7c6683...
🎤 [ElevenLabs Direct] Response Status: XXX
```

## Step 4: Check Response Status

### Find this line in console:
```
🎤 [ElevenLabs Direct] Response Status: XXX
```

### What the status code means:

| Status | Meaning | Next Step |
|--------|---------|-----------|
| **200** or **201** | ✅ Success! | Look at "Response Data:" line below |
| **400** | Bad request | Check message format |
| **401** | Unauthorized | **API key is invalid or expired** |
| **403** | Forbidden | Agent ID doesn't match API key |
| **404** | Not found | Agent doesn't exist |
| **429** | Rate limited | Too many requests - wait 60s |
| **500-503** | Server error | ElevenLabs API is down |
| **No status** | Network error | Can't reach API - check internet |

## Troubleshooting by Response Code

### Response Status: 401 (Most Common Issue)

**Problem:** API key is invalid, expired, or wrong

**Solution:**
1. Go to https://elevenlabs.io/app/settings/api-keys
2. Copy your API key
3. Update in code: `ElevenLabsAgentService.swift` line 21
4. Rebuild and test

### Response Status: 403

**Problem:** API key doesn't have access to this agent

**Solution:**
1. Verify agent ID is correct: `agent_7401ka31ry6qftr9ab89em3339w9`
2. Check in ElevenLabs console that agent exists
3. Try regenerating API key with full permissions

### Response Status: 404

**Problem:** Agent doesn't exist or URL is wrong

**Solution:**
1. Go to https://elevenlabs.io/app/agents
2. Verify agent exists
3. Copy exact agent ID from console
4. Update in code

### Response Status: 200 but Still Error

**Problem:** API responded but no message in response

**Solution:**
Look at the full response:
```
🎤 [ElevenLabs Direct] Response Data: {...}
🎤 [ElevenLabs Direct] Parsed JSON: {...}
```

Check what fields are in the response. It might be:
- `response` field
- `message` field  
- `text` field
- Something else

Report the full JSON and I'll update the parsing code.

### No Response Status Line

**Problem:** Request never reached API

**Solution:**
1. Check internet connection
2. Disable VPN (if using)
3. Try different network (WiFi ↔ Mobile)
4. Check firewall isn't blocking `api.elevenlabs.io`

Test connectivity:
```bash
curl https://api.elevenlabs.io/v1/user \
  -H "xi-api-key: sk_40b434d2a8deebbb7c6683dba782412a0dcc9ff571d042ca"
```

Should return user info if API key is valid.

## What to Report

When the test fails, collect:

1. **Full console output** (copy everything from "🧪 TESTING")
2. **Response Status code** (the XXX in "Response Status: XXX")
3. **Full Response Data** (the JSON in "Response Data:")
4. **API Key (first 20 chars)** - verify it matches: `sk_40b434d2a8deebbb7c6683...`
5. **Agent ID** - verify it's: `agent_7401ka31ry6qftr9ab89em3339w9`

## Console Output Examples

### Example 1: Success ✅
```
🎤 [ElevenLabs Direct] Response Status: 200
🎤 [ElevenLabs Direct] Response Data: {"response":"Hello! How can I help?","conversation_id":"conv_123..."}
🎤 [ElevenLabs Direct] Parsed JSON: {...}
🎤 [ElevenLabs Direct] Found response field
✅ SUCCESS!
Response: Hello! How can I help?
```

### Example 2: Invalid API Key ❌
```
🎤 [ElevenLabs Direct] Response Status: 401
🎤 [ElevenLabs Direct] Response Data: {"error":"Invalid API key"}
❌ ERROR:
Type: ElevenLabsError
Message: API Error (401): {"error":"Invalid API key"}
```

### Example 3: Network Error ❌
```
🎤 [ElevenLabs Direct] Request URL: https://api.elevenlabs.io/v1/convai/agents/agent_7401ka31ry6qftr9ab89em3339w9
❌ [ElevenLabs] ERROR: URLError(_NSError(...))
❌ [ElevenLabs] Error Description: The Internet connection appears to be offline.
```

## Quick Fixes to Try First

### 1. Check Internet Connection
```bash
ping google.com
```

### 2. Verify API Key is Valid
```bash
curl https://api.elevenlabs.io/v1/user \
  -H "xi-api-key: sk_40b434d2a8deebbb7c6683dba782412a0dcc9ff571d042ca"
```

### 3. Verify Agent Exists
```bash
curl https://api.elevenlabs.io/v1/convai/agents/agent_7401ka31ry6qftr9ab89em3339w9 \
  -H "xi-api-key: sk_40b434d2a8deebbb7c6683dba782412a0dcc9ff571d042ca"
```

### 4. Test Direct API Call
```bash
curl -X POST https://api.elevenlabs.io/v1/convai/agents/agent_7401ka31ry6qftr9ab89em3339w9 \
  -H "Content-Type: application/json" \
  -H "xi-api-key: sk_40b434d2a8deebbb7c6683dba782412a0dcc9ff571d042ca" \
  -d '{"message": "Hello"}'
```

If these curl commands fail, the issue is **not with the app** - it's with:
- API credentials (key/agent ID)
- Network connectivity
- ElevenLabs API being down

## Next Steps

1. ✅ Run the test view
2. ✅ Check console output for response status
3. ✅ Identify the problem using table above
4. ✅ Apply fix
5. ✅ Test again

Once you run the test and see the output, **share the console logs** and I can pinpoint the exact issue! 📊

---

**Test View Location:** `ElevenLabsTestView.swift`  
**Service File:** `ElevenLabsAgentService.swift`  
**Status:** Ready to diagnose ✅
