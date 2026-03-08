# Making the Real ElevenLabs Agent Work

## The Problem

The WebSocket implementation is now in place, but the API key provided doesn't have the `convai_read` permission needed to access the agent. This is why the connection fails.

## Solution: Update API Key Permissions

Your API key (`sk_40b434d2a8deebbb7c6683dba782412a0dcc9ff571d042ca`) needs to have ConvAI permissions enabled.

### Steps to Fix:

1. **Go to ElevenLabs Console**
   - Visit: https://elevenlabs.io/app/settings/api-keys

2. **Check Your API Key**
   - Locate: `sk_40b434d2a8deebbb7c6683dba782412a0dcc9ff571d042ca`
   - Check the permissions listed

3. **Ensure These Permissions Are Enabled:**
   - ✅ `convai_read` - Read access to ConvAI agents
   - ✅ `convai_write` - Write access for conversations
   - ✅ Any other ConvAI permissions

4. **If Permissions Are Missing:**
   - Click the key to edit it
   - Enable "ConvAI" permissions
   - Save changes

5. **If You Can't Modify It:**
   - Create a **new API key** with full ConvAI permissions
   - Replace the current key in `ElevenLabsAgentService.swift` line 16:
   ```swift
   let apiKey = "YOUR_NEW_API_KEY_HERE"
   ```

## How the WebSocket Connection Works

```
App sends message
    ↓
FloatingAIWidgetView.sendMessage()
    ↓
ElevenLabsAgentService.sendMessage()
    ↓
Connect to WebSocket if needed
    ↓
wss://api.elevenlabs.io/v1/convai/agents/{agentId}/sessions?key={apiKey}
    ↓
Send message as JSON data
    ↓
Receive response from agent
    ↓
Parse and return to widget
```

## Current Implementation

The `ElevenLabsAgentService.swift` now has proper WebSocket support:

✅ **WebSocket connection** to ElevenLabs ConvAI  
✅ **Message encoding/decoding** to proper JSON format  
✅ **Response parsing** from various field names  
✅ **Connection management** with reconnect capability  
✅ **Error handling** with detailed logging  
✅ **Audio support** for voice messages  

## What to Do Now

1. **Verify your API key has ConvAI permissions**
2. **If not, generate a new API key with those permissions**
3. **Update the key in ElevenLabsAgentService.swift if needed**
4. **Run the app and test**

The widget should now connect to your actual agent and receive real responses! 

## Debugging

If it still doesn't work, check the Xcode console for messages like:

```
🎤 [ElevenLabs] Connecting to agent...
🎤 [ElevenLabs] Connected to agent WebSocket
🎤 [ElevenLabs] Message sent successfully
🎤 [ElevenLabs] Received response: [agent's actual response]
```

These indicate successful connection and communication.

**If you see connection errors, the API key likely needs ConvAI permission.**

---

**Status:** WebSocket Implementation Ready  
**Next Step:** Ensure API key has ConvAI permissions  
**Agent ID:** `agent_7401ka31ry6qftr9ab89em3339w9`
