//
//  AuthService.swift
//  thebitbinder
//
//  Created by Taylor Drew on 2/20/26.
//

import Foundation
import Combine

/// Manages user preferences and basic app state (no external authentication required)
final class AuthService: ObservableObject {
    static let shared = AuthService()
    
    @Published var hasAcceptedTerms = false
    @Published var isLoading = false
    @Published var isAuthenticated = true
    @Published var authError: AuthServiceError?
    
    private let kvStore = iCloudKeyValueStore.shared
    
    private init() {
        hasAcceptedTerms = UserDefaults.standard.bool(forKey: SyncedKeys.termsAccepted)
    }
    
    // MARK: - Terms Acceptance
    
    func acceptTerms() {
        hasAcceptedTerms = true
        kvStore.set(true, forKey: SyncedKeys.termsAccepted)
    }
    
    // MARK: - Auth Stubs (no external auth needed)
    
    /// Always succeeds — no external auth provider required
    func signInAnonymously() async throws {
        isAuthenticated = true
    }
    
    /// Always succeeds — no external auth provider required
    func ensureAuthenticated() async throws {
        isAuthenticated = true
    }
    
    // MARK: - User ID (for local data separation)
    
    var userId: String {
        if let storedId = kvStore.string(forKey: SyncedKeys.userId) {
            return storedId
        } else {
            let newId = UUID().uuidString
            kvStore.set(newId, forKey: SyncedKeys.userId)
            return newId
        }
    }
}

// MARK: - Error Type

enum AuthServiceError: LocalizedError {
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .unknown:
            return "An unknown error occurred"
        }
    }
}
