//
//  ChatMessage.swift
//  thebitbinder
//
//  Created by Taylor Drew on 2/20/26.
//

import Foundation

/// Unified chat message model used across all chat views
struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let timestamp: Date
    
    init(text: String, isUser: Bool) {
        self.text = text
        self.isUser = isUser
        self.timestamp = Date()
    }
    
    // Legacy initializer for compatibility
    init(content: String, isUser: Bool) {
        self.text = content
        self.isUser = isUser
        self.timestamp = Date()
    }
    
    // Property alias for compatibility
    var content: String {
        return text
    }
}
