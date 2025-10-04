//
//  Conversation.swift
//  LocalLabs
//
//  Created by LocalLabs Team
//

import Foundation
import SwiftData

/// Represents a chat conversation with metadata and message history
@Model
final class Conversation {
    /// Unique identifier for the conversation
    var id: UUID

    /// Title of the conversation (auto-generated or user-defined)
    var title: String

    /// Timestamp when the conversation was created
    var createdAt: Date

    /// Timestamp when the conversation was last updated
    var updatedAt: Date

    /// The model used for this conversation (e.g., "llama-3.2-1b-instruct-4bit")
    var modelName: String

    /// All messages in this conversation, ordered by timestamp
    @Relationship(deleteRule: .cascade, inverse: \Message.conversation)
    var messages: [Message]

    init(title: String = "New Chat", modelName: String, createdAt: Date = Date()) {
        self.id = UUID()
        self.title = title
        self.modelName = modelName
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.messages = []
    }

    /// Computed property to get the most recent message
    var lastMessage: Message? {
        messages.sorted(by: { $0.timestamp > $1.timestamp }).first
    }

    /// Update the lastUpdated timestamp
    func touch() {
        self.updatedAt = Date()
    }
}
