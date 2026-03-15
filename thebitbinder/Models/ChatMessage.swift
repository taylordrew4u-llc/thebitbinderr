//
//  ChatMessage.swift
//  thebitbinder
//
//  Created by Taylor Drew on 2/20/26.
//

import Foundation
import SwiftData

/// Unified chat message model used across all chat views
@Model
final class ChatMessage {
    var id: UUID = UUID()
    var text: String = ""
    var isUser: Bool = false
    var timestamp: Date = Date()
    var conversationId: String = ""
    
    init(text: String, isUser: Bool, conversationId: String = UUID().uuidString) {
        self.id = UUID()
        self.text = text
        self.isUser = isUser
        self.timestamp = Date()
        self.conversationId = conversationId
    }
}
