//
//  Message.swift
//  LocalLabs
//
//  Created by LocalLabs Team
//

import Foundation
import SwiftData

/// Represents a single message in a conversation
@Model
final class Message {
    /// Unique identifier for the message
    var id: UUID

    /// The text content of the message
    var content: String

    /// The role of the message sender (user or assistant)
    var role: MessageRole

    /// Timestamp when the message was created
    var timestamp: Date

    /// Reference to the parent conversation
    var conversation: Conversation?

    init(content: String, role: MessageRole, timestamp: Date = Date()) {
        self.id = UUID()
        self.content = content
        self.role = role
        self.timestamp = timestamp
    }
}

/// Enum representing the role of a message sender
enum MessageRole: String, Codable {
    case user = "user"
    case assistant = "assistant"
    case system = "system"
}
