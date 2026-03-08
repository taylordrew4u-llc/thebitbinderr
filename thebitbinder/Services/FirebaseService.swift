//
//  FirebaseService.swift
//  thebitbinder
//
//  Created by Taylor Drew on 2/20/26.
//

import Foundation
import FirebaseDatabase
import FirebaseCore
// Analytics removed to fix dSYM issues
import FirebaseAuth

/// Singleton service for reading and writing to the Firebase Realtime Database.
/// Database URL: https://bit-builder-4c59c-default-rtdb.firebaseio.com/
final class FirebaseService: ObservableObject {

    static let shared = FirebaseService()

    private let databaseURL = "https://bit-builder-4c59c-default-rtdb.firebaseio.com/"

    /// Root reference to the Firebase Realtime Database.
    private lazy var database: DatabaseReference = {
        Database.database(url: databaseURL).reference()
    }()

    private init() {}

    // MARK: - Write

    /// Write a value to the given path in the database.
    /// - Parameters:
    ///   - value: Any JSON-compatible value (String, Int, Double, Bool, [String: Any], etc.).
    ///   - path: The database path, e.g. "jokes/abc123".
    ///   - completion: Called with an optional error on completion.
    func write(value: Any, at path: String, completion: ((Error?) -> Void)? = nil) {
        database.child(path).setValue(value) { error, _ in
            if let error = error {
                print("🔥 FirebaseService write error at '\(path)': \(error.localizedDescription)")
            } else {
                print("🔥 FirebaseService: wrote value at '\(path)'")
            }
            completion?(error)
        }
    }

    /// Async/await version of write.
    func write(value: Any, at path: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            database.child(path).setValue(value) { error, _ in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Read (Once)

    /// Read the value once from the given path.
    /// - Parameters:
    ///   - path: The database path, e.g. "jokes/abc123".
    ///   - completion: Called with the snapshot value (or nil) and an optional error.
    func readOnce(at path: String, completion: @escaping (Any?, Error?) -> Void) {
        database.child(path).observeSingleEvent(of: .value) { snapshot in
            if snapshot.exists() {
                completion(snapshot.value, nil)
            } else {
                completion(nil, nil)
            }
        } withCancel: { error in
            print("🔥 FirebaseService read error at '\(path)': \(error.localizedDescription)")
            completion(nil, error)
        }
    }

    /// Async/await version of readOnce.
    func readOnce(at path: String) async throws -> Any? {
        try await withCheckedThrowingContinuation { continuation in
            database.child(path).observeSingleEvent(of: .value) { snapshot in
                continuation.resume(returning: snapshot.exists() ? snapshot.value : nil)
            } withCancel: { error in
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Observe (Realtime)

    /// Observe realtime changes at the given path. Returns a handle you can use to remove the observer.
    /// - Parameters:
    ///   - path: The database path to observe.
    ///   - onChange: Called every time the value changes, with the new value (or nil if it doesn't exist).
    /// - Returns: A `DatabaseHandle` — call `removeObserver(handle:at:)` when done.
    @discardableResult
    func observe(at path: String, onChange: @escaping (Any?) -> Void) -> DatabaseHandle {
        return database.child(path).observe(.value) { snapshot in
            onChange(snapshot.exists() ? snapshot.value : nil)
        }
    }

    /// Remove a realtime observer.
    func removeObserver(handle: DatabaseHandle, at path: String) {
        database.child(path).removeObserver(withHandle: handle)
    }

    // MARK: - Delete

    /// Delete the value at the given path.
    func delete(at path: String, completion: ((Error?) -> Void)? = nil) {
        database.child(path).removeValue { error, _ in
            if let error = error {
                print("🔥 FirebaseService delete error at '\(path)': \(error.localizedDescription)")
            } else {
                print("🔥 FirebaseService: deleted value at '\(path)'")
            }
            completion?(error)
        }
    }

    /// Async/await version of delete.
    func delete(at path: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            database.child(path).removeValue { error, _ in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    // MARK: - AI Widget Methods

    /// Save an AI chat message to Firestore
    /// - Parameters:
    ///   - message: The message text
    ///   - isUser: Whether the message is from the user (true) or AI (false)
    ///   - conversationId: The unique conversation ID
    ///   - completion: Called with an optional error
    func saveAIChatMessage(
        message: String,
        isUser: Bool,
        conversationId: String,
        completion: ((Error?) -> Void)? = nil
    ) {
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let messageData: [String: Any] = [
            "text": message,
            "isUser": isUser,
            "timestamp": timestamp,
            "sender": isUser ? "user" : "assistant"
        ]

        let path = "aiWidget/conversations/\(conversationId)/messages/\(UUID().uuidString)"
        write(value: messageData, at: path, completion: completion)
    }

    /// Async version of saveAIChatMessage
    func saveAIChatMessage(
        message: String,
        isUser: Bool,
        conversationId: String
    ) async throws {
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let messageData: [String: Any] = [
            "text": message,
            "isUser": isUser,
            "timestamp": timestamp,
            "sender": isUser ? "user" : "assistant"
        ]

        let path = "aiWidget/conversations/\(conversationId)/messages/\(UUID().uuidString)"
        try await write(value: messageData, at: path)
    }

    /// Fetch all messages for a conversation
    /// - Parameters:
    ///   - conversationId: The conversation ID
    ///   - completion: Called with array of messages and optional error
    func fetchConversationMessages(
        conversationId: String,
        completion: @escaping ([[String: Any]]?, Error?) -> Void
    ) {
        let path = "aiWidget/conversations/\(conversationId)/messages"
        readOnce(at: path) { value, error in
            if let dict = value as? [String: Any] {
                let messages = dict.values.compactMap { $0 as? [String: Any] }
                completion(messages, error)
            } else {
                completion(nil, error)
            }
        }
    }

    /// Async version of fetchConversationMessages
    func fetchConversationMessages(conversationId: String) async throws -> [[String: Any]]? {
        let path = "aiWidget/conversations/\(conversationId)/messages"
        if let dict = try await readOnce(at: path) as? [String: Any] {
            return dict.values.compactMap { $0 as? [String: Any] }
        }
        return nil
    }

    /// Create or update conversation metadata
    /// - Parameters:
    ///   - conversationId: The conversation ID
    ///   - title: Optional conversation title
    ///   - metadata: Additional metadata to store
    func updateConversationMetadata(
        conversationId: String,
        title: String? = nil,
        metadata: [String: Any]? = nil,
        completion: ((Error?) -> Void)? = nil
    ) {
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        var data: [String: Any] = ["lastUpdated": timestamp]

        if let title = title {
            data["title"] = title
        }

        if let metadata = metadata {
            data.merge(metadata) { _, new in new }
        }

        let path = "aiWidget/conversations/\(conversationId)/metadata"
        write(value: data, at: path, completion: completion)
    }

    /// Async version of updateConversationMetadata
    func updateConversationMetadata(
        conversationId: String,
        title: String? = nil,
        metadata: [String: Any]? = nil
    ) async throws {
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        var data: [String: Any] = ["lastUpdated": timestamp]

        if let title = title {
            data["title"] = title
        }

        if let metadata = metadata {
            data.merge(metadata) { _, new in new }
        }

        let path = "aiWidget/conversations/\(conversationId)/metadata"
        try await write(value: data, at: path)
    }

    /// Log AI widget analytics event
    /// - Parameters:
    ///   - eventName: Name of the event (e.g., "ai_widget_opened", "message_sent")
    ///   - parameters: Optional event parameters
    func logAIWidgetEvent(
        _ eventName: String,
        parameters: [String: Any]? = nil
    ) {
        var eventParams: [String: Any] = [
            "timestamp": Int(Date().timeIntervalSince1970 * 1000)
        ]

        if let parameters = parameters {
            eventParams.merge(parameters) { _, new in new }
        }

        // Event logging handled via print for now
        // Analytics.logEvent removed to fix App Store dSYM issues
        print("🔥 Logged AI widget event: \(eventName)")
    }

    /// Fetch user's recent conversations
    /// - Parameters:
    ///   - limit: Maximum number of conversations to fetch (default: 10)
    ///   - completion: Called with conversation IDs and optional error
    func fetchRecentConversations(
        limit: Int = 10,
        completion: @escaping ([String]?, Error?) -> Void
    ) {
        let path = "aiWidget/conversations"
        readOnce(at: path) { value, error in
            if let dict = value as? [String: Any] {
                let conversations = Array(dict.keys.prefix(limit))
                completion(conversations, error)
            } else {
                completion(nil, error)
            }
        }
    }

    /// Async version of fetchRecentConversations
    func fetchRecentConversations(limit: Int = 10) async throws -> [String]? {
        let path = "aiWidget/conversations"
        if let dict = try await readOnce(at: path) as? [String: Any] {
            return Array(dict.keys.prefix(limit))
        }
        return nil
    }

    /// Delete a conversation and all its messages
    /// - Parameters:
    ///   - conversationId: The conversation to delete
    ///   - completion: Called with optional error
    func deleteConversation(
        _ conversationId: String,
        completion: ((Error?) -> Void)? = nil
    ) {
        let path = "aiWidget/conversations/\(conversationId)"
        delete(at: path, completion: completion)
    }

    /// Async version of deleteConversation
    func deleteConversation(_ conversationId: String) async throws {
        let path = "aiWidget/conversations/\(conversationId)"
        try await delete(at: path)
    }

    /// Archive a conversation without deleting it
    /// - Parameters:
    ///   - conversationId: The conversation to archive
    ///   - completion: Called with optional error
    func archiveConversation(
        _ conversationId: String,
        completion: ((Error?) -> Void)? = nil
    ) {
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let path = "aiWidget/conversations/\(conversationId)/metadata"
        let archiveData: [String: Any] = [
            "archived": true,
            "archivedAt": timestamp
        ]
        database.child(path).updateChildValues(archiveData) { error, _ in
            if let error = error {
                print("🔥 FirebaseService archive error: \(error.localizedDescription)")
            } else {
                print("🔥 FirebaseService: archived conversation '\(conversationId)'")
            }
            completion?(error)
        }
    }

    /// Async version of archiveConversation
    func archiveConversation(_ conversationId: String) async throws {
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let path = "aiWidget/conversations/\(conversationId)/metadata"
        let archiveData: [String: Any] = [
            "archived": true,
            "archivedAt": timestamp
        ]
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            database.child(path).updateChildValues(archiveData) { error, _ in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Authentication Methods

    /// Get the current authenticated user ID
    var currentUserId: String? {
        return Auth.auth().currentUser?.uid
    }

    /// Check if user is authenticated
    var isAuthenticated: Bool {
        return Auth.auth().currentUser != nil
    }

    /// Get current user's email
    var currentUserEmail: String? {
        return Auth.auth().currentUser?.email
    }

    /// Sign in anonymously (for non-authenticated users)
    func signInAnonymously() async throws -> String {
        let result = try await Auth.auth().signInAnonymously()
        let uid = result.user.uid
        print("🔥 FirebaseService: Signed in anonymously as \(uid)")
        return uid
    }

    /// Create user profile in database
    func createUserProfile(
        userId: String,
        email: String? = nil,
        metadata: [String: Any]? = nil,
        completion: ((Error?) -> Void)? = nil
    ) {
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        var userData: [String: Any] = [
            "createdAt": timestamp,
            "lastActive": timestamp
        ]

        if let email = email {
            userData["email"] = email
        }

        if let metadata = metadata {
            userData.merge(metadata) { _, new in new }
        }

        let path = "users/\(userId)/profile"
        write(value: userData, at: path, completion: completion)
    }

    /// Async version of createUserProfile
    func createUserProfile(
        userId: String,
        email: String? = nil,
        metadata: [String: Any]? = nil
    ) async throws {
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        var userData: [String: Any] = [
            "createdAt": timestamp,
            "lastActive": timestamp
        ]

        if let email = email {
            userData["email"] = email
        }

        if let metadata = metadata {
            userData.merge(metadata) { _, new in new }
        }

        let path = "users/\(userId)/profile"
        try await write(value: userData, at: path)
    }

    /// Update user's last active timestamp
    func updateUserLastActive(userId: String, completion: ((Error?) -> Void)? = nil) {
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let path = "users/\(userId)/profile/lastActive"
        write(value: timestamp, at: path, completion: completion)
    }

    /// Async version of updateUserLastActive
    func updateUserLastActive(userId: String) async throws {
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let path = "users/\(userId)/profile/lastActive"
        try await write(value: timestamp, at: path)
    }

    /// Link a conversation to a user
    func linkConversationToUser(
        userId: String,
        conversationId: String,
        completion: ((Error?) -> Void)? = nil
    ) {
        let path = "users/\(userId)/conversations/\(conversationId)"
        write(value: true, at: path, completion: completion)
    }

    /// Async version of linkConversationToUser
    func linkConversationToUser(
        userId: String,
        conversationId: String
    ) async throws {
        let path = "users/\(userId)/conversations/\(conversationId)"
        try await write(value: true, at: path)
    }

    /// Fetch user's conversations
    func fetchUserConversations(
        userId: String,
        completion: @escaping ([String]?, Error?) -> Void
    ) {
        let path = "users/\(userId)/conversations"
        readOnce(at: path) { value, error in
            if let dict = value as? [String: Any] {
                let conversations = Array(dict.keys)
                completion(conversations, error)
            } else {
                completion(nil, error)
            }
        }
    }

    /// Async version of fetchUserConversations
    func fetchUserConversations(userId: String) async throws -> [String]? {
        let path = "users/\(userId)/conversations"
        if let dict = try await readOnce(at: path) as? [String: Any] {
            return Array(dict.keys)
        }
        return nil
    }

    /// Validate conversation ownership
    func validateConversationOwnership(
        userId: String,
        conversationId: String,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        let path = "aiWidget/conversations/\(conversationId)/metadata"
        readOnce(at: path) { value, error in
            if let dict = value as? [String: Any],
               let ownerId = dict["ownerId"] as? String {
                completion(ownerId == userId, error)
            } else {
                completion(false, error)
            }
        }
    }

    /// Async version of validateConversationOwnership
    func validateConversationOwnership(
        userId: String,
        conversationId: String
    ) async throws -> Bool {
        let path = "aiWidget/conversations/\(conversationId)/metadata"
        if let dict = try await readOnce(at: path) as? [String: Any],
           let ownerId = dict["ownerId"] as? String {
            return ownerId == userId
        }
        return false
    }
}
