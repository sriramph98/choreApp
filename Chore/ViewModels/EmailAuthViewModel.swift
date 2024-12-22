import Foundation

class EmailAuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var isSigningUp = false
    @Published var isLoading = false
    @Published var error: String?
    
    private let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
    
    func signIn() {
        guard validateEmail() else { return }
        guard validatePassword() else { return }
        
        isLoading = true
        error = nil
        
        // TODO: Integrate with your backend
        // For now, we'll simulate an API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.isLoading = false
            // Simulate successful sign in
            print("Signed in with email: \(self?.email ?? "")")
        }
    }
    
    func signUp() {
        guard validateEmail() else { return }
        guard validatePassword() else { return }
        guard validateConfirmPassword() else { return }
        
        isLoading = true
        error = nil
        
        // TODO: Integrate with your backend
        // For now, we'll simulate an API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.isLoading = false
            // Simulate successful sign up
            print("Signed up with email: \(self?.email ?? "")")
        }
    }
    
    private func validateEmail() -> Bool {
        guard NSPredicate(format: "SELF MATCHES %@", emailRegex)
                .evaluate(with: email) else {
            error = "Please enter a valid email address"
            return false
        }
        return true
    }
    
    private func validatePassword() -> Bool {
        guard password.count >= 8 else {
            error = "Password must be at least 8 characters"
            return false
        }
        return true
    }
    
    private func validateConfirmPassword() -> Bool {
        guard password == confirmPassword else {
            error = "Passwords don't match"
            return false
        }
        return true
    }
} 