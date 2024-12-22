import Foundation

@MainActor
class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let authService: AuthenticationService
    
    init(authService: AuthenticationService = MockAuthenticationService()) {
        self.authService = authService
    }
    
    func signInWithEmail() async {
        guard validateInput() else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.signInWithEmail(email: email, password: password)
            // Handle successful login
        } catch {
            errorMessage = "Failed to sign in: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func signInAsGuest() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.signInAsGuest()
            // Successfully authenticated as guest
            isLoading = false
        } catch {
            errorMessage = "Failed to sign in as guest: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    private func validateInput() -> Bool {
        guard !email.isEmpty else {
            errorMessage = "Please enter your email"
            return false
        }
        guard !password.isEmpty else {
            errorMessage = "Please enter your password"
            return false
        }
        return true
    }
} 