//
//  BitBuddyAIChatView.swift
//  thebitbinder
//
//  Created by Taylor Drew on 2/20/26.
//

import SwiftUI
import SwiftData

/// Full-screen AI chat view accessed from the side menu
struct BitBuddyAIChatView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Joke.dateCreated, order: .reverse) private var jokes: [Joke]
    @StateObject private var bitBuddy = BitBuddyService.shared
    
    @StateObject private var authService = AuthService.shared
    @ObservedObject private var usageTracker = FreeUsageTracker.shared
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var conversationId = UUID().uuidString
    
    var body: some View {
        VStack(spacing: 0) {
            // Usage Banner
            AIUsageBanner()
                .padding(.top, 8)
            
            if bitBuddy.isUsingLocalFallback {
                HStack(spacing: 8) {
                    Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                    Text("BitBuddy is running in local offline mode.")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundStyle(AppTheme.Colors.aiAccent)
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            
            // Messages View
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if messages.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 40))
                                    .foregroundColor(AppTheme.Colors.aiAccent)
                                Text("Start a conversation!")
                                    .font(.headline)
                                Text("Ask me anything about your comedy routine, recordings, or how to organize your jokes.")
                                    .font(.subheadline)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
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
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                } else {
                    AIUsageLockedView(featureName: "AI chats")
                        .padding(.horizontal, 4)
                        .padding(.bottom, 8)
                }
            }
            .background(Color(.systemBackground))
        }
        .navigationTitle("BitBuddy AI")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Done") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    messages.removeAll()
                    conversationId = UUID().uuidString
                    bitBuddy.startNewConversation()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .disabled(messages.isEmpty)
            }
        }
        .onAppear {
            handleAppear()
            bitBuddy.registerJokeDataProvider {
                jokes.prefix(25).map {
                    BitBuddyJokeSummary(
                        id: $0.id,
                        title: $0.title,
                        content: $0.content,
                        tags: $0.tags,
                        dateCreated: $0.dateCreated
                    )
                }
            }
        }
        .onDisappear {
            messages.removeAll()
            bitBuddy.cleanupAudioResources()
        }
    }
    
    private func handleAppear() {
        if !authService.isAuthenticated {
            Task {
                try? await authService.signInAnonymously()
            }
        }
    }
    
    private func sendMessage() {
        let message = inputText.trimmingCharacters(in: .whitespaces)
        guard !message.isEmpty else { return }
        guard !bitBuddy.isLoading else { return }
        
        let userMessage = ChatMessage(text: message, isUser: true, conversationId: conversationId)
        messages.append(userMessage)
        inputText = ""
        
        Task {
            do {
                let response = try await bitBuddy.sendMessage(message)
                let aiMessage = ChatMessage(text: response, isUser: false, conversationId: conversationId)
                await MainActor.run {
                    messages.append(aiMessage)
                }
            } catch let error as UsageLimitError {
                let limitMsg = ChatMessage(text: error.localizedDescription, isUser: false, conversationId: conversationId)
                await MainActor.run {
                    messages.append(limitMsg)
                }
            } catch {
                let errorMsg = ChatMessage(text: "Sorry, I encountered an error. Please try again.", isUser: false, conversationId: conversationId)
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

#Preview {
    NavigationStack {
        BitBuddyAIChatView()
    }
}
