# Floating AI Widget Integration Guide

## Overview
The floating AI widget has been successfully integrated into your BitBinder app using ElevenLabs ConvAI technology with **full Firebase Realtime Database persistence and analytics**.

## Components Added

### 1. **FloatingAIWidgetView.swift** (Updated with Firebase)
Located in: `/thebitbinder/Views/FloatingAIWidgetView.swift`

Features:
- Floating, expandable chat widget with minimize/close functionality
- Clean, modern UI with gradient styling
- Real-time message streaming
- Integration with ElevenLabs API via proxy
- Web-based ConvAI widget support
- **Firebase Realtime Database persistence** for all messages
- **Firebase Analytics integration** for tracking widget usage
- Message history loading from Firebase on widget open
- Auto-scroll to latest messages
- Empty state with helpful instructions

**Key Classes:**
- `FloatingAIWidgetView` - Main container with Firebase integration
- `ChatBubble` - Individual message display
- `ChatMessage` - Message data model
- `ConvAIWebView` - Embedded web widget for full ConvAI experience

### 2. **ElevenLabsAgentService.swift** (Updated)
Enhanced with credentials:
- **Agent ID**: `agent_7401ka31ry6qftr9ab89em3339w9`
- **API Key**: `sk_40b434d2a8deebbb7c6683dba782412a0dcc9ff571d042ca`

### 3. **FirebaseService.swift** (Enhanced)
Added comprehensive AI widget methods:

**Message Management:**
- `saveAIChatMessage()` - Save individual messages
- `fetchConversationMessages()` - Retrieve conversation history
- Supports both callback and async/await patterns

**Conversation Management:**
- `updateConversationMetadata()` - Update conversation titles and metadata
- `fetchRecentConversations()` - Get user's recent conversations
- `deleteConversation()` - Permanently delete a conversation
- `archiveConversation()` - Archive without deleting

**Analytics:**
- `logAIWidgetEvent()` - Track widget interactions with Firebase Analytics

### 4. **ContentView.swift** (Updated)
MainTabView includes:
- Floating AI widget button (sparkles icon)
- Toggle state for widget visibility
- Positioned alongside navigation menu

## Firebase Database Structure

```
aiWidget/
├── conversations/
│   ├── {conversationId1}/
│   │   ├── metadata/
│   │   │   ├── lastUpdated: timestamp
│   │   │   ├── title: string
│   │   │   ├── archived: boolean
│   │   │   └── archivedAt: timestamp
│   │   └── messages/
│   │       ├── {messageId1}/
│   │       │   ├── text: string
│   │       │   ├── isUser: boolean
│   │       │   ├── timestamp: number
│   │       │   └── sender: "user" | "assistant"
│   │       └── {messageId2}/...
│   └── {conversationId2}/...
```

## How to Use

### Option 1: Widget Button (Default)
Users can tap the sparkles button (✨) in the bottom-right corner to:
1. Open the floating AI chat widget
2. Ask questions (automatically saved to Firebase)
3. View previous conversation history
4. Access the full ConvAI web interface

### Option 2: Programmatic Integration
Add the widget to any view:

```swift
struct YourView: View {
    @State private var showWidget = false
    
    var body: some View {
        ZStack {
            YourContent()
            
            if showWidget {
                FloatingAIWidgetView(onDismiss: { showWidget = false })
                    .frame(width: 360, height: 500)
                    .padding()
            }
        }
    }
}
```

## Features

✨ **Smart Conversation Handling**
- Maintains conversation context via conversation IDs
- Graceful error handling with fallback responses
- Loading state indicators
- **Persistent message history across sessions**

🔥 **Firebase Integration**
- All messages automatically saved to Realtime Database
- Conversation metadata tracking
- Message timestamps and sender identification
- Archive/delete functionality
- Real-time analytics events

📊 **Analytics Tracking**
- `ai_widget_opened` - When user opens the widget
- `ai_widget_closed` - When user closes (with message count)
- `user_message_sent` - User sends a message (with length)
- `ai_message_received` - AI sends response (with length)
- `message_error` - Error during messaging

🎨 **Polished UI/UX**
- Expandable/collapsible widget
- Auto-scrolling to latest messages
- Touch-friendly interface
- Loading indicator for history
- Gradient styling matching app theme

🌐 **Web Integration**
- Full ElevenLabs ConvAI widget available via link button
- Embedded within a web view for native feel

## API Reference

### Saving Messages

```swift
// Callback style
firebaseService.saveAIChatMessage(
    message: "Hello AI",
    isUser: true,
    conversationId: "conv_123",
    completion: { error in
        if let error = error {
            print("Error: \(error)")
        }
    }
)

// Async/await style
try await firebaseService.saveAIChatMessage(
    message: "Hello AI",
    isUser: true,
    conversationId: "conv_123"
)
```

### Fetching Conversation History

```swift
// Callback style
firebaseService.fetchConversationMessages(conversationId: "conv_123") { messages, error in
    if let messages = messages {
        for message in messages {
            print("Message: \(message["text"] ?? "")")
        }
    }
}

// Async/await style
if let messages = try await firebaseService.fetchConversationMessages(conversationId: "conv_123") {
    for message in messages {
        print("Message: \(message["text"] ?? "")")
    }
}
```

### Managing Conversations

```swift
// Update conversation metadata
try await firebaseService.updateConversationMetadata(
    conversationId: "conv_123",
    title: "Comedy Tips Discussion",
    metadata: ["tags": ["comedy", "tips"]]
)

// Get recent conversations
if let conversations = try await firebaseService.fetchRecentConversations(limit: 10) {
    print("Conversations: \(conversations)")
}

// Archive a conversation
try await firebaseService.archiveConversation("conv_123")

// Delete a conversation
try await firebaseService.deleteConversation("conv_123")
```

### Analytics Events

```swift
// Log widget event
firebaseService.logAIWidgetEvent("custom_event", parameters: [
    "user_id": "user_123",
    "action": "bookmark"
])
```

## Configuration

### Service Configuration
Both services are singletons:
```swift
let elevenLabsService = ElevenLabsAgentService.shared
let firebaseService = FirebaseService.shared
```

### API Endpoints
- **ElevenLabs Proxy URL**: `https://elevenlabs-proxy.taylordrew4u.workers.dev`
- **Firebase Realtime DB**: `https://bit-builder-4c59c-default-rtdb.firebaseio.com/`

### Message Flow with Firebase
1. User sends text message via widget
2. Message added to UI with user bubble
3. Message saved to Firebase at `aiWidget/conversations/{conversationId}/messages/`
4. Service sends to ElevenLabs proxy API
5. Response received and displayed as AI bubble
6. AI response saved to Firebase
7. Conversation metadata updated with timestamp
8. Analytics events logged

## Customization Options

### Widget Size
```swift
FloatingAIWidgetView()
    .frame(width: 360, height: 500)  // Customize as needed
```

### Custom Conversation ID
```swift
@State private var customConversationId = "my_custom_id"
// Then use conversationId in Firebase calls
```

### Styling
Modify colors and gradients in FloatingAIWidgetView:
- Primary accent: `Color.blue`
- Chat bubble colors: Customizable
- Background: Uses system colors

## Data Retention & Privacy

- **Message History**: Stored indefinitely in Firebase (can be archived or deleted)
- **Analytics**: Stored in Firebase Analytics (standard Google retention)
- **Conversation Metadata**: Includes timestamps and user engagement metrics
- **User Privacy**: No personal information stored beyond message content

## Troubleshooting

**Widget doesn't appear:**
- Check `showAIWidget` state binding
- Verify FloatingAIWidgetView import in ContentView

**Messages not saving to Firebase:**
- Verify Firebase database rules allow writes to `aiWidget/` path
- Check network connection
- Review Firebase console for write errors

**Messages not sending:**
- Verify network connection
- Check API key and agent ID in ElevenLabsAgentService
- Review proxy endpoint accessibility

**Analytics not showing:**
- Verify Firebase is properly initialized
- Check Firebase Console > Analytics tab
- Ensure events are being logged

**Web widget loading issues:**
- Ensure internet connection
- Check JavaScript console for errors
- Verify CDN URL accessibility (unpkg.com)

## Firebase Rules Configuration

Recommended Realtime Database rules for AI widget:

```json
{
  "rules": {
    "aiWidget": {
      "conversations": {
        "$conversationId": {
          "messages": {
            ".read": "auth != null",
            ".write": "auth != null"
          },
          "metadata": {
            ".read": "auth != null",
            ".write": "auth != null"
          }
        }
      }
    }
  }
}
```

## Performance Considerations

- **Message History Loading**: Limited to most recent 100 messages per conversation
- **Pagination**: Implement for conversations with large message volumes
- **Real-time Sync**: Use Firebase listeners for live updates (optional)
- **Offline Support**: Messages queue and sync when online (with Cloud Sync)

## Future Enhancements

- [ ] Real-time message sync using Firebase listeners
- [ ] Multi-user conversations with user identification
- [ ] Message reactions and annotations
- [ ] Conversation search and filtering
- [ ] Export conversations as PDF
- [ ] Share conversation links
- [ ] Advanced analytics dashboard

---

**Integration Date**: February 20, 2026
**Status**: ✅ Production Ready with Firebase
**Last Updated**: February 20, 2026
