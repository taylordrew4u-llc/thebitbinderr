# Anonymous Usage & Session-Based Conversations

## Overview

The BitBinder AI Widget now supports **two usage modes**:

1. **Authenticated Users** - Sign in with email/password or anonymous account
2. **Anonymous/Session Users** - Use without any authentication (new!)

Users can now start chatting immediately without being forced to sign in.

## How It Works

### Without Authentication (Session-Based)

When a user opens the widget without authentication:

1. **Session ID Created** - Uses the conversation UUID as the session identifier
2. **Messages Saved** - All messages stored under the conversation session
3. **No User Data Stored** - Works without requiring any authentication
4. **Session Persists** - Messages saved for the duration of the app session
5. **Analytics Tracked** - Event logging includes "authenticated: false"

### With Authentication (User-Based)

When a user is authenticated:

1. **User ID Linked** - Conversation linked to user account
2. **Account Persistence** - Messages persist across sessions
3. **Enhanced Privacy** - User ID used instead of anonymous session
4. **Multi-Device** - Access conversations on multiple devices (future)
5. **Profile Data** - User profile information available

## Changes Made

### FloatingAIWidgetView.swift

**Authentication is now optional:**
```swift
// Old: Required authentication
guard let userId = authService.userId else {
    print("❌ Error: User not authenticated")
    return
}

// New: Works with or without auth
let userId = authService.userId ?? "session_\(conversationId)"
```

**Graceful sign-in handling:**
```swift
// Attempts anonymous sign-in but continues if it fails
do {
    try await authService.signInAnonymously()
} catch {
    // Continue without auth - use session-based approach
}
```

### Firebase Security Rules

**Updated to allow unauthenticated access:**
```json
".write": "auth != null || root.child('...').child('ownerId').val() === null"
```

This allows:
- ✅ Authenticated users to write to their conversations
- ✅ Anonymous users to write to conversations without an owner

## User Experience

### Opening the Widget

**Before:**
```
1. User taps widget
2. Auto sign-in attempt
3. If failed → Show auth prompt
4. Force user to sign in
```

**After:**
```
1. User taps widget
2. Auto sign-in attempt (silent)
3. If failed → Continue anyway with session ID
4. User can start chatting immediately
```

### Sending Messages

**Works the same way regardless of auth status:**
- Message appears in widget immediately
- Saved to Firebase
- Sent to ElevenLabs agent
- Response displayed
- Response saved

## Database Structure Changes

### Authenticated User Session
```
users/
└── {userId}/
    └── conversations/
        └── {conversationId}: true

aiWidget/
└── conversations/
    └── {conversationId}/
        ├── metadata/
        │   ├── ownerId: {userId}
        │   └── lastUpdated: timestamp
        └── messages/
            └── {messageId}: {...}
```

### Anonymous Session
```
aiWidget/
└── conversations/
    └── {sessionConversationId}/  (no owner link)
        ├── metadata/
        │   └── lastUpdated: timestamp
        └── messages/
            └── {messageId}: {...}
```

## Analytics Tracking

All events now include authentication status:

```swift
"authenticated": true/false
```

This allows tracking:
- How many users continue without signing in
- Engagement of authenticated vs anonymous users
- Conversion from anonymous to authenticated

## Security Considerations

### What's Protected

✅ **ElevenLabs API Key** - Stored server-side, never exposed  
✅ **Messages** - Stored in Firebase database  
✅ **User Data** - Protected with Firebase rules  

### What's Open

⚠️ **Session Conversations** - No ownership requirement (sessions are temporary)  
✅ **User Conversations** - Protected by user ID requirement  

### Cleanup

For production, consider:
- Auto-delete old session conversations (>7 days old)
- Archive anonymous conversations after timeout
- Implement conversation expiration

## Migration Path

**If users want to keep their session conversations:**

1. They open the widget and chat (session-based)
2. They create an account or sign in
3. Their existing conversation can be transferred to their account:

```swift
// Transfer conversation ownership
try await firebaseService.updateConversationMetadata(
    conversationId: existingSessionConversationId,
    metadata: ["ownerId": userId]
)
```

## Testing

### Test Anonymous Usage

1. Open app fresh (no authentication)
2. Tap AI widget sparkles button
3. Should open without prompts
4. Type a message → should work immediately
5. Close and reopen app → messages still there (same session)

### Test Authenticated Usage

1. Sign in through the widget auth prompt
2. Chat as normal
3. Close and reopen app
4. Conversations should still be accessible

### Test Mixed Usage

1. Chat anonymously
2. Sign in during conversation
3. Conversation should link to user account
4. Messages should be preserved

## Configuration Options

### Allow Only Authenticated

To revert to requiring authentication:

```swift
// In FloatingAIWidgetView.swift
if !authService.isAuthenticated {
    showAuthPrompt = true
    return
}
```

### Auto-Expire Sessions

To auto-delete old conversations:

```swift
// Check if older than 7 days
let metadata = try await firebaseService.readOnce(at: path)
let lastUpdated = metadata["lastUpdated"] as? Int ?? 0
let ageInDays = (Date().timeIntervalSince1970 - Double(lastUpdated) / 1000) / 86400

if ageInDays > 7 {
    try await firebaseService.delete(at: path)
}
```

## User Preferences

Users might prefer different modes:

- **Quick Chat:** Anonymous, no sign-up required
- **Persistent Data:** Authenticated, data saved across devices
- **Privacy-Focused:** Anonymous only, no account needed

The app now supports all three preferences.

## Benefits

✅ **Lower Friction** - Users can start immediately  
✅ **Better Adoption** - No forced authentication barrier  
✅ **Optional Upgrade** - Users can sign in later if they want  
✅ **Engagement** - Measure anonymous vs authenticated usage  
✅ **Flexibility** - Works online and offline (with messages saved locally)  

## Troubleshooting

### "Widget requires sign-in"

**Problem:** Widget still shows auth prompt  
**Solution:** Make sure you have the latest version with anonymous support

### "Session conversations not saving"

**Problem:** Messages lost when app closes  
**Solution:**
- Check Firebase rules are updated
- Verify conversationId is being used consistently
- Check internet connectivity

### "Can't convert session to account"

**Problem:** Can't link anonymous conversation to new account  
**Solution:**
- Manually update ownerId in Firebase console
- Or manually implement transfer logic

## Next Steps

1. ✅ Test anonymous usage
2. ✅ Verify messages save without auth
3. ✅ Check Firebase rules allow writes
4. ✅ Monitor analytics for authentication patterns
5. Optional: Implement auto-cleanup for old sessions

---

**Status**: ✅ Anonymous Usage Enabled  
**Last Updated**: February 21, 2026
