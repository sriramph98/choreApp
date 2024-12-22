import Foundation

enum AuthenticationError: Error {
    case invalidEmail
    case invalidPassword
    case networkError
    case unknown
}

protocol AuthenticationService {
    func signInWithEmail(email: String, password: String) async throws
    func signUp(email: String, password: String) async throws
    func signInAsGuest() async throws
}

// Placeholder implementation for now
class MockAuthenticationService: AuthenticationService {
    func signInWithEmail(email: String, password: String) async throws {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        // TODO: Implement actual email authentication
        guard email.contains("@") else {
            throw AuthenticationError.invalidEmail
        }
        guard password.count >= 6 else {
            throw AuthenticationError.invalidPassword
        }
    }
    
    func signUp(email: String, password: String) async throws {
        try await signInWithEmail(email: email, password: password)
    }
    
    func signInAsGuest() async throws {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_000_000_000)
        // In a real implementation, you might create a temporary anonymous account
        // or use a restricted guest access token
    }
} 