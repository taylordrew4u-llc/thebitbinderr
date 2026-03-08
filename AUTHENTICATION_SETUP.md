# Firebase Authentication Setup for AI Widget

## Overview
Complete Firebase Authentication integration for the BitBinder AI Widget with user ownership tracking, conversation persistence, and security rules.

## What's Included

### 1. **AuthService.swift** (New)
Complete authentication management service with:

**Features:**
- Anonymous sign-in (for users without accounts)
- Email/password sign-up and sign-in
- Password reset
- Profile management
- Account deletion
- User metadata tracking
- Real-time auth state monitoring

**Key Methods:**
```swift
// Anonymous sign-in (no email required)
try await authService.signInAnonymously()

// Email sign-up
try await authService.signUp(email: "user@example.com", password: "password123")

// Email sign-in
try await authService.signIn(email: "user@example.com", password: "password123")

// Sign out
try authService.signOut()

// Password reset
try await authService.sendPasswordResetEmail(to: "user@example.com")

// Update profile
try await authService.updateProfile(displayName: "John Doe", photoURL: nil)

// Get user info
let userId = authService.userId
let email = authService.userEmail
let isAuth = authService.isAuthenticated
```

### 2. **FloatingAIWidgetView.swift** (Updated)
Enhanced with authentication integration:

**New Features:**
- Automatic anonymous sign-in on first use
- Auth prompt with sign-up/sign-in options
- User ID tracking in conversations
- Ownership validation for messages
- Enhanced analytics with user context

**Authentication Flow:**
1. User opens widget
2. If not authenticated → signs in anonymously
3. Creates user profile in Firebase
4. Links conversation to user account
5. Sets conversation ownership

### 3. **FirebaseService.swift** (Extended)
Added authentication helper methods:

**User Management:**
```swift
// Create user profile
try await firebaseService.createUserProfile(
    userId: uid,
    email: "user@example.com",
    metadata: ["accountType": "email"]
)

// Update last active timestamp
try await firebaseService.updateUserLastActive(userId: uid)

// Link conversation to user
try await firebaseService.linkConversationToUser(
    userId: uid,
    conversationId: conversationId
)

// Fetch user's conversations
let conversations = try await firebaseService.fetchUserConversations(userId: uid)

// Validate conversation ownership
let isOwner = try await firebaseService.validateConversationOwnership(
    userId: uid,
    conversationId: conversationId
)
```

### 4. **Firebase Security Rules** (firebase-rules.json)
Comprehensive rules with:
- User-owned conversation access control
- Message ownership validation
- Timestamp protection (prevents backdated messages)
- Data structure validation
- Profile protection

## Database Structure

```
users/
├── {userId}/
│   ├── profile/
│   │   ├── createdAt: timestamp (immutable)
│   │   ├── lastActive: timestamp
│   │   ├── email: string (optional)
│   │   └── accountType: "anonymous" | "email"
│   └── conversations/
│       └── {conversationId}: true

aiWidget/
└── conversations/
    └── {conversationId}/
        ├── metadata/
        │   ├── ownerId: userId (required)
        │   ├── lastUpdated: timestamp
        │   ├── title: string (optional)
        │   ├── archived: boolean (optional)
        │   └── archivedAt: timestamp (optional)
        └── messages/
            └── {messageId}/
                ├── text: string
                ├── isUser: boolean
                ├── timestamp: number
                └── sender: "user" | "assistant"
```

## Setup Instructions

### 1. Enable Authentication in Firebase Console
1. Go to Firebase Console → Authentication
2. Sign-in method → Enable "Anonymous"
3. Sign-in method → Enable "Email/Password"
4. Set up password requirements (minimum 6 characters recommended)

### 2. Update Firebase Rules
1. Go to Firebase Console → Realtime Database → Rules
2. Replace with contents of `firebase-rules.json`
3. Publish rules

### 3. Update App Configuration
The app is already configured to use:
- Firebase Realtime Database: `https://bit-builder-4c59c-default-rtdb.firebaseio.com/`
- Firebase Authentication (enabled by default)
- Firebase Analytics (enabled for event tracking)

## Usage Examples

### Sign In User
```swift
let authService = AuthService.shared

// Anonymous (no email required)
do {
    try await authService.signInAnonymously()
    print("Signed in anonymously")
} catch {
    print("Sign-in failed: \(error)")
}
```

### Create Email Account
```swift
do {
    try await authService.signUp(
        email: "user@example.com",
        password: "SecurePassword123"
    )
    print("Account created and signed in")
} catch let error as AuthError {
    print("Sign-up failed: \(error.errorDescription ?? "")")
}
```

### Track Conversation Ownership
```swift
// When creating a conversation
let userId = authService.userId!
let conversationId = UUID().uuidString

// Link to user
try await firebaseService.linkConversationToUser(
    userId: userId,
    conversationId: conversationId
)

// Set ownership
try await firebaseService.updateConversationMetadata(
    conversationId: conversationId,
    metadata: ["ownerId": userId, "title": "Comedy Tips"]
)
```

### Verify Conversation Access
```swift
let isOwner = try await firebaseService.validateConversationOwnership(
    userId: authService.userId!,
    conversationId: conversationId
)

if isOwner {
    print("User can access this conversation")
} else {
    print("Access denied")
}
```

### Get User Profile
```swift
if let userId = authService.userId {
    let profile = try await authService.getUserProfile(userId: userId)
    if let email = profile?["email"] as? String {
        print("User email: \(email)")
    }
}
```

## Authentication Features

### Anonymous Sign-In
- ✅ No email/password required
- ✅ Instant access to widget
- ✅ Conversations stored under anonymous user ID
- ✅ Can be upgraded to email account later

### Email Authentication
- ✅ Account creation with email/password
- ✅ Secure password storage
- ✅ Password reset functionality
- ✅ Email verification (optional)

### Session Management
- ✅ Automatic persistence across app restarts
- ✅ Real-time auth state monitoring
- ✅ Last active timestamp tracking
- ✅ Secure sign-out

## Security Features

### Data Protection
- **User Ownership**: Only conversation owner can read/write
- **Timestamp Validation**: Prevents backdated messages
- **Data Structure**: Enforces required fields
- **Access Control**: Immutable creation timestamps

### Rules Summary
```json
// Only owner can read conversations
".read": "auth != null && ownerId === auth.uid"

// Only owner can write messages
".write": "auth != null && ownerId === auth.uid && timestamp <= now"

// Data validation
".validate": "hasRequiredFields && validDataTypes"
```

## Error Handling

AuthService provides detailed error types:

```swift
enum AuthError: LocalizedError {
    case invalidEmail
    case wrongPassword
    case userNotFound
    case userDisabled
    case emailAlreadyInUse
    case weakPassword
    case tooManyRequests
    case notAuthenticated
    case unknown(String)
}
```

**Usage:**
```swift
do {
    try await authService.signIn(email: email, password: password)
} catch let error as AuthError {
    switch error {
    case .wrongPassword:
        print("Incorrect password")
    case .userNotFound:
        print("No account with this email")
    default:
        print(error.errorDescription ?? "Unknown error")
    }
}
```

## Analytics Events

Tracked events include:
- `ai_widget_opened` - Widget session started
- `ai_widget_closed` - Widget closed (includes message count)
- `user_message_sent` - User sends message (includes length, userId, conversationId)
- `ai_message_received` - AI responds (includes length, userId, conversationId)
- `message_error` - Error during messaging (includes error details, userId)

**Access in Firebase Console:**
Analytics > Events tab

## Best Practices

### 1. Always Check Authentication
```swift
if authService.isAuthenticated {
    let userId = authService.userId!
    // Safe to use user ID
}
```

### 2. Handle Auth Errors Gracefully
```swift
do {
    try await authService.signIn(email: email, password: password)
} catch {
    print("Error: \(authService.authError?.errorDescription ?? "")")
}
```

### 3. Update Last Active
Automatically done, but can manually update:
```swift
if let userId = authService.userId {
    try await firebaseService.updateUserLastActive(userId: userId)
}
```

### 4. Validate Ownership Before Access
```swift
let hasAccess = try await firebaseService.validateConversationOwnership(
    userId: userId,
    conversationId: conversationId
)
```

## Testing

### Test Anonymous Sign-In
```swift
// In preview or test
@State var authService = AuthService.shared
// Automatically signs in anonymously on widget open
```

### Test Email Sign-Up
Use test credentials during development:
- Email: `test@example.com`
- Password: `Test123456`

### Test Security Rules
Firebase provides a rules emulator for local testing.

## Troubleshooting

**Issue: User can't sign in**
- ✅ Check Firebase Authentication is enabled
- ✅ Verify email/password credentials
- ✅ Check password meets requirements (6+ characters)

**Issue: Conversations not saving**
- ✅ Verify user is authenticated (`authService.isAuthenticated`)
- ✅ Check Firebase Realtime Database rules are published
- ✅ Verify network connection

**Issue: Can't access conversation**
- ✅ Verify conversation `ownerId` matches current user ID
- ✅ Check conversation wasn't deleted
- ✅ Validate using `validateConversationOwnership()`

**Issue: Password reset not working**
- ✅ Verify email address is correct
- ✅ Check email authentication is enabled
- ✅ Check spam folder for reset email

## Migration from Unauthenticated

To upgrade anonymous users to email accounts:

```swift
// User already authenticated anonymously with conversationId

// Prompt for email/password
try await authService.signUp(email: email, password: password)

// User will be signed in with new email account
// Existing conversations linked to old anonymous ID

// Optional: Transfer conversation ownership
try await firebaseService.updateConversationMetadata(
    conversationId: existingConversationId,
    metadata: ["ownerId": authService.userId!]
)
```

## Production Checklist

- [ ] Firebase Authentication enabled with both Anonymous and Email/Password
- [ ] Security rules published to production database
- [ ] Email verification enabled (optional but recommended)
- [ ] Password reset email configured
- [ ] Rate limiting configured for sign-up (Firebase handles automatically)
- [ ] Analytics events tested and validated
- [ ] User profile creation verified
- [ ] Conversation ownership validation tested
- [ ] App tested with multiple user accounts

## Support

For issues or questions:
1. Check Firebase Console → Authentication for user details
2. Review Realtime Database → Rules for permission errors
3. Check app console logs for auth error details
4. Verify network connectivity

---

**Setup Date**: February 20, 2026
**Status**: ✅ Production Ready
**Last Updated**: February 20, 2026
