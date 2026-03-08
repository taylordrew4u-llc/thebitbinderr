//
//  FloatingAIWidgetView.swift
//  thebitbinder
//
//  Created by Taylor Drew on 2/20/26.
//

import SwiftUI

/// A floating AI chat widget using DeepSeek
/// This widget can be overlaid on any view and provides conversational AI capabilities
/// Messages are persisted to Firebase Realtime Database with user authentication
struct FloatingAIWidgetView: View {
    @StateObject private var bitBuddy = BitBuddyService.shared
    @StateObject private var firebaseService = FirebaseService.shared
    @StateObject private var authService = AuthService.shared
    @ObservedObject private var usageTracker = FreeUsageTracker.shared
    @State private var isExpanded = false
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var conversationId = UUID().uuidString
    @State private var isLoadingHistory = false
    @State private var showAuthPrompt = false
    
    let onDismiss: (() -> Void)?
    
    init(onDismiss: (() -> Void)? = nil) {
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if isExpanded {
                // Chat Header
                HStack {
                    VStack(alignment: .leading) {
                        Text("BitBuddy AI")
                            .font(.headline)
                        Text("Your writing buddy")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 12) {
                        Button(action: { isExpanded = false }) {
                            Image(systemName: "minus")
                                .foregroundColor(.secondary)
                        }
                        Button(action: { isExpanded = false; onDismiss?() }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .borderBottom()
                
                // Usage Banner
                AIUsageBanner()
                    .padding(.top, 8)
                
                // Messages View
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            if isLoadingHistory {
                                ProgressView()
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding()
                            } else if messages.isEmpty {
                                VStack(spacing: 16) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 40))
                                        .foregroundColor(AppTheme.Colors.aiAccent)
                                    Text("Start a conversation!")
                                        .font(.headline)
                                    Text("Ask me anything about your comedy routine, recordings, or how to organize your jokes.")
                                        .font(.caption)
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                            } else {
                                ForEach(messages) { message in
                                    ChatBubble(message: message)
                                        .id(message.id)
                                }
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) {
                        if let lastMessage = messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                .frame(maxHeight: .infinity)
                
                // Input Area
                VStack(spacing: 8) {
                    Divider()
                    
                    if usageTracker.hasUsesRemaining {
                        HStack(spacing: 8) {
                            TextField("Ask BitBuddy anything...", text: $inputText)
                                .textFieldStyle(.roundedBorder)
                            
                            Button(action: sendMessage) {
                                Image(systemName: bitBuddy.isLoading ? "hourglass" : "arrow.up.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(AppTheme.Colors.aiAccent)
                            }
                            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || bitBuddy.isLoading)
                        }
                        .padding()
                    } else {
                        AIUsageLockedView(featureName: "AI chats")
                            .padding(.horizontal, 4)
                    }
                }
                .background(Color(.systemBackground))
            } else {
                // Collapsed Widget Button
                Button(action: { withAnimation { isExpanded = true } }) {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.headline)
                        VStack(alignment: .leading) {
                            Text("BitBuddy AI")
                                .font(.headline)
                            Text("Chat with AI")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        AIUsagePill()
                        Image(systemName: "chevron.up")
                            .font(.caption)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.Colors.aiAccent.opacity(0.1))
                    .foregroundColor(.primary)
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 8)
        .sheet(isPresented: $showAuthPrompt) {
            AuthPromptView(isPresented: $showAuthPrompt)
        }
        .onAppear {
            handleWidgetAppear()
        }
        .onDisappear {
            // Clean up memory
            messages.removeAll()
            bitBuddy.cleanupAudioResources()
            firebaseService.logAIWidgetEvent("ai_widget_closed", parameters: ["message_count": messages.count])
        }
    }
    
    private func handleWidgetAppear() {
        // Attempt anonymous sign-in if not already authenticated
        // But don't block if it fails - allow anonymous usage with session ID
        if !authService.isAuthenticated {
            Task {
                do {
                    try await authService.signInAnonymously()
                    print("✅ [Widget] Anonymous sign-in successful")
                    loadConversationHistory()
                    firebaseService.logAIWidgetEvent("ai_widget_opened", parameters: ["authType": "anonymous"])
                } catch {
                    print("⚠️ [Widget] Anonymous sign-in failed, continuing without auth: \(error.localizedDescription)")
                    // Continue without auth - use session-based approach
                    firebaseService.logAIWidgetEvent("ai_widget_opened", parameters: ["authType": "session"])
                }
            }
        } else {
            loadConversationHistory()
            firebaseService.logAIWidgetEvent("ai_widget_opened")
        }
    }
    
    private func loadConversationHistory() {
        // Works with or without auth - uses userId if available, otherwise uses conversationId as session key
        isLoadingHistory = true
        Task {
            do {
                if let savedMessages = try await firebaseService.fetchConversationMessages(conversationId: conversationId) {
                    await MainActor.run {
                        self.messages = savedMessages.compactMap { dict in
                            guard let text = dict["text"] as? String,
                                  let isUser = dict["isUser"] as? Bool else {
                                return nil
                            }
                            return ChatMessage(text: text, isUser: isUser)
                        }.sorted { (dict1, dict2) in
                            let time1 = (savedMessages.first { $0["text"] as? String == dict1.text }?["timestamp"] as? Int) ?? 0
                            let time2 = (savedMessages.first { $0["text"] as? String == dict2.text }?["timestamp"] as? Int) ?? 0
                            return time1 < time2
                        }
                        isLoadingHistory = false
                    }
                } else {
                    await MainActor.run { isLoadingHistory = false }
                }
                
                // Link conversation to user if authenticated
                if let userId = authService.userId {
                    try await firebaseService.linkConversationToUser(userId: userId, conversationId: conversationId)
                    
                    // Update conversation metadata with owner
                    try await firebaseService.updateConversationMetadata(
                        conversationId: conversationId,
                        metadata: ["ownerId": userId]
                    )
                }
            } catch {
                print("⚠️ [Widget] Error loading conversation history: \(error.localizedDescription)")
                await MainActor.run { isLoadingHistory = false }
            }
        }
    }
    
    private func sendMessage() {
        let message = inputText.trimmingCharacters(in: .whitespaces)
        guard !message.isEmpty else { return }
        guard !bitBuddy.isLoading else { return }
        
        // Add user message to UI
        let userMessage = ChatMessage(text: message, isUser: true)
        messages.append(userMessage)
        inputText = ""
        
        // Single task — sequential: save → call AI → show response → save response
        Task {
            // Save user message to Firebase (non-blocking if it fails)
            try? await firebaseService.saveAIChatMessage(
                message: message,
                isUser: true,
                conversationId: conversationId
            )
            
            // Call DeepSeek
            do {
                let response = try await bitBuddy.sendMessage(message)
                
                let aiMessage = ChatMessage(text: response, isUser: false)
                await MainActor.run {
                    messages.append(aiMessage)
                }
                
                // Save AI response to Firebase
                try? await firebaseService.saveAIChatMessage(
                    message: response,
                    isUser: false,
                    conversationId: conversationId
                )
            } catch let error as UsageLimitError {
                let limitMsg = ChatMessage(text: error.localizedDescription, isUser: false)
                await MainActor.run {
                    messages.append(limitMsg)
                }
            } catch {
                let errorMsg = ChatMessage(text: "Sorry, I encountered an error. Please try again.", isUser: false)
                await MainActor.run {
                    messages.append(errorMsg)
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct ChatBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(.body)
                    .padding(12)
                    .background(message.isUser ? AppTheme.Colors.inkBlue : AppTheme.Colors.surfaceElevated)
                    .foregroundColor(message.isUser ? .white : AppTheme.Colors.inkBlack)
                    .cornerRadius(12)
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !message.isUser {
                Spacer()
            }
        }
    }
}

// MARK: - Authentication Prompt View

struct AuthPromptView: View {
    @Binding var isPresented: Bool
    @StateObject private var authService = AuthService.shared
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 48))
                        .foregroundColor(AppTheme.Colors.brand)
                    
                    Text("Authentication Required")
                        .font(.title2.bold())
                    
                    Text("Sign in or create an account to use BitBuddy and save your conversations.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 32)
                
                VStack(spacing: 12) {
                    Button(action: signInAnonymously) {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        } else {
                            HStack {
                                Image(systemName: "person.badge.plus")
                                Text("Continue Anonymously")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading)
                    
                    Divider()
                    
                    NavigationLink(destination: SignUpView(isPresented: $isPresented)) {
                        HStack {
                            Image(systemName: "envelope.badge.fill")
                            Text("Sign Up with Email")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    
                    NavigationLink(destination: SignInView(isPresented: $isPresented)) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                            Text("Sign In with Email")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
                
                Button(action: { isPresented = false }) {
                    Text("Skip for Now")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { isPresented = false }
                }
            }
        }
    }
    
    private func signInAnonymously() {
        isLoading = true
        Task {
            do {
                try await authService.signInAnonymously()
                await MainActor.run {
                    isPresented = false
                }
            } catch {
                print("Error signing in anonymously: \(error.localizedDescription)")
                isLoading = false
            }
        }
    }
}

// MARK: - Sign Up View

struct SignUpView: View {
    @Binding var isPresented: Bool
    @StateObject private var authService = AuthService.shared
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email, password, confirmPassword
    }
    
    var body: some View {
        Form {
            Section("Account Information") {
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .focused($focusedField, equals: .email)
                    .autocorrectionDisabled()
                
                SecureField("Password", text: $password)
                    .textContentType(.newPassword)
                    .focused($focusedField, equals: .password)
                
                SecureField("Confirm Password", text: $confirmPassword)
                    .textContentType(.newPassword)
                    .focused($focusedField, equals: .confirmPassword)
            }
            
            if let error = authService.authError {
                Section {
                    Text(error.errorDescription ?? "Unknown error")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            
            Section {
                Button(action: signUp) {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Create Account")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading || !isFormValid)
            }
        }
        .navigationTitle("Create Account")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && password == confirmPassword && password.count >= 6
    }
    
    private func signUp() {
        isLoading = true
        Task {
            do {
                try await authService.signUp(email: email, password: password)
                await MainActor.run {
                    isPresented = false
                }
            } catch {
                isLoading = false
            }
        }
    }
}

// MARK: - Sign In View

struct SignInView: View {
    @Binding var isPresented: Bool
    @StateObject private var authService = AuthService.shared
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email, password
    }
    
    var body: some View {
        Form {
            Section("Login Credentials") {
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .focused($focusedField, equals: .email)
                    .autocorrectionDisabled()
                
                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .focused($focusedField, equals: .password)
            }
            
            if let error = authService.authError {
                Section {
                    Text(error.errorDescription ?? "Unknown error")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            
            Section {
                Button(action: signIn) {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Sign In")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading || email.isEmpty || password.isEmpty)
            }
        }
        .navigationTitle("Sign In")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func signIn() {
        isLoading = true
        Task {
            do {
                try await authService.signIn(email: email, password: password)
                await MainActor.run {
                    isPresented = false
                }
            } catch {
                isLoading = false
            }
        }
    }
}

#Preview {
    FloatingAIWidgetView()
        .frame(width: 360, height: 500)
}
