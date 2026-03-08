//
//  AuthService.swift
//  thebitbinder
//
//  Created by Taylor Drew on 2/20/26.
//

import Foundation
import FirebaseAuth
import Combine

/// Manages authentication state and user session for the BitBinder app
final class AuthService: NSObject, ObservableObject {
    static let shared = AuthService()
    
    @Published var isAuthenticated = false
    @Published var currentUser: FirebaseAuth.User?
    @Published var userId: String?
    @Published var userEmail: String?
    @Published var isLoading = false
    @Published var authError: AuthError?
    
    private let firebaseService = FirebaseService.shared
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    private override init() {
        super.init()
        setupAuthStateListener()
    }
    
    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
    
    // MARK: - Setup
    
    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.currentUser = user
                self?.isAuthenticated = user != nil
                self?.userId = user?.uid
                self?.userEmail = user?.email
                
                if let user = user {
                    print("🔐 AuthService: User authenticated - \(user.uid)")
                    // Update last active timestamp
                    self?.firebaseService.updateUserLastActive(userId: user.uid) { error in
                        if let error = error {
                            print("🔐 AuthService: Error updating last active - \(error.localizedDescription)")
                        }
                    }
                } else {
                    print("🔐 AuthService: No authenticated user")
                }
            }
        }
    }
    
    // MARK: - Anonymous Authentication
    
    /// Ensure the user is authenticated, signing in anonymously if needed.
    /// Call this from any agent/service before making API requests.
    func ensureAuthenticated() async throws {
        if isAuthenticated { return }
        print("🔐 AuthService: Not authenticated — auto-signing in anonymously...")
        try await signInAnonymously()
    }
    
    /// Sign in anonymously for users without an account
    func signInAnonymously() async throws {
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }
        
        do {
            let uid = try await firebaseService.signInAnonymously()
            
            // Create user profile
            try await firebaseService.createUserProfile(
                userId: uid,
                metadata: ["accountType": "anonymous", "signUpDate": Int(Date().timeIntervalSince1970)]
            )
            
            print("🔐 AuthService: Anonymous sign-in successful")
        } catch {
            let authError = parseAuthError(error)
            await MainActor.run { self.authError = authError }
            throw authError
        }
    }
    
    // MARK: - Email/Password Authentication
    
    /// Sign up with email and password
    func signUp(email: String, password: String) async throws {
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }
        
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let uid = result.user.uid
            
            // Create user profile
            try await firebaseService.createUserProfile(
                userId: uid,
                email: email,
                metadata: ["accountType": "email", "signUpDate": Int(Date().timeIntervalSince1970)]
            )
            
            print("🔐 AuthService: Sign up successful - \(uid)")
        } catch {
            let authError = parseAuthError(error)
            await MainActor.run { self.authError = authError }
            throw authError
        }
    }
    
    /// Sign in with email and password
    func signIn(email: String, password: String) async throws {
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }
        
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            let uid = result.user.uid
            
            // Update last active
            try await firebaseService.updateUserLastActive(userId: uid)
            
            print("🔐 AuthService: Sign in successful - \(uid)")
        } catch {
            let authError = parseAuthError(error)
            await MainActor.run { self.authError = authError }
            throw authError
        }
    }
    
    /// Sign out current user
    func signOut() throws {
        do {
            try Auth.auth().signOut()
            print("🔐 AuthService: User signed out")
        } catch {
            let authError = parseAuthError(error)
            self.authError = authError
            throw authError
        }
    }
    
    // MARK: - Password Reset
    
    /// Send password reset email
    func sendPasswordResetEmail(to email: String) async throws {
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }
        
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            print("🔐 AuthService: Password reset email sent to \(email)")
        } catch {
            let authError = parseAuthError(error)
            await MainActor.run { self.authError = authError }
            throw authError
        }
    }
    
    // MARK: - Profile Updates
    
    /// Update user profile information
    func updateProfile(displayName: String?, photoURL: URL?) async throws {
        guard let user = currentUser else {
            throw AuthError.notAuthenticated
        }
        
        let changeRequest = user.createProfileChangeRequest()
        changeRequest.displayName = displayName
        changeRequest.photoURL = photoURL
        
        try await changeRequest.commitChanges()
        
        print("🔐 AuthService: Profile updated")
    }
    
    /// Update user email
    func updateEmail(_ newEmail: String) async throws {
        guard let user = currentUser else {
            throw AuthError.notAuthenticated
        }
        
        try await user.sendEmailVerification(beforeUpdatingEmail: newEmail)
        print("🔐 AuthService: Email verification sent to \(newEmail)")
    }
    
    /// Update user password
    func updatePassword(_ newPassword: String) async throws {
        guard let user = currentUser else {
            throw AuthError.notAuthenticated
        }
        
        try await user.updatePassword(to: newPassword)
        print("🔐 AuthService: Password updated")
    }
    
    /// Delete user account
    func deleteAccount() async throws {
        guard let user = currentUser else {
            throw AuthError.notAuthenticated
        }
        
        let userId = user.uid
        
        try await user.delete()
        print("🔐 AuthService: Account deleted for user \(userId)")
    }
    
    // MARK: - User Profile Management
    
    /// Get user profile from Firebase
    func getUserProfile(userId: String) async throws -> [String: Any]? {
        let path = "users/\(userId)/profile"
        return try await firebaseService.readOnce(at: path) as? [String: Any]
    }
    
    /// Update user profile metadata
    func updateUserMetadata(_ metadata: [String: Any]) async throws {
        guard let userId = userId else {
            throw AuthError.notAuthenticated
        }
        
        let path = "users/\(userId)/profile"
        var updatedData = metadata
        updatedData["lastUpdated"] = Int(Date().timeIntervalSince1970 * 1000)
        
        try await firebaseService.write(value: updatedData, at: path)
        print("🔐 AuthService: User metadata updated")
    }
    
    // MARK: - Helper Methods
    
    private func parseAuthError(_ error: Error) -> AuthError {
        let nsError = error as NSError
        switch nsError.code {
        case AuthErrorCode.invalidEmail.rawValue:
            return .invalidEmail
        case AuthErrorCode.wrongPassword.rawValue:
            return .wrongPassword
        case AuthErrorCode.userNotFound.rawValue:
            return .userNotFound
        case AuthErrorCode.userDisabled.rawValue:
            return .userDisabled
        case AuthErrorCode.emailAlreadyInUse.rawValue:
            return .emailAlreadyInUse
        case AuthErrorCode.weakPassword.rawValue:
            return .weakPassword
        case AuthErrorCode.operationNotAllowed.rawValue:
            return .operationNotAllowed
        case AuthErrorCode.tooManyRequests.rawValue:
            return .tooManyRequests
        case AuthErrorCode.accountExistsWithDifferentCredential.rawValue:
            return .accountExistsWithDifferentCredential
        default:
            return .unknown(error.localizedDescription)
        }
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case invalidEmail
    case wrongPassword
    case userNotFound
    case userDisabled
    case emailAlreadyInUse
    case weakPassword
    case operationNotAllowed
    case tooManyRequests
    case accountExistsWithDifferentCredential
    case notAuthenticated
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "The email address is invalid."
        case .wrongPassword:
            return "The password is incorrect."
        case .userNotFound:
            return "No account found with this email."
        case .userDisabled:
            return "This account has been disabled."
        case .emailAlreadyInUse:
            return "An account with this email already exists."
        case .weakPassword:
            return "Password must be at least 6 characters."
        case .operationNotAllowed:
            return "This authentication method is not enabled."
        case .tooManyRequests:
            return "Too many login attempts. Try again later."
        case .accountExistsWithDifferentCredential:
            return "An account exists with a different credential."
        case .notAuthenticated:
            return "User is not authenticated."
        case .unknown(let message):
            return message
        }
    }
}
