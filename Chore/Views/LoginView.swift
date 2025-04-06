import SwiftUI

struct LoginView: View {
    @EnvironmentObject var choreViewModel: ChoreViewModel
    @AppStorage("hasCompletedLogin") private var hasCompletedLogin = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    @State private var email = ""
    @State private var password = ""
    @State private var isSecured = true
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var isLoggingIn = false
    
    private var biometricType = BiometricAuthHelper.getBiometricType()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                // App title and icon
                VStack(spacing: 16) {
                    Image("AppIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                        .cornerRadius(20)
                        .padding(.top, 20)
                    
                    Text("Chore")
                        .font(.system(size: 32, weight: .bold))
                }
                .padding(.top, 30)
                
                // Login form
                VStack(spacing: 20) {
                    // Email field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        TextField("your@email.com", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                    
                    // Password field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Group {
                                if isSecured {
                                    SecureField("Enter your password", text: $password)
                                } else {
                                    TextField("Enter your password", text: $password)
                                }
                            }
                            .padding()
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            
                            Button {
                                isSecured.toggle()
                            } label: {
                                Image(systemName: isSecured ? "eye.slash" : "eye")
                                    .foregroundColor(.gray)
                            }
                            .padding(.trailing, 12)
                        }
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        
                        HStack {
                            // Remember me checkbox
                            Toggle("Remember me", isOn: .constant(true))
                                .toggleStyle(SwitchToggleStyle(tint: .blue))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            // Forgot password
                            Button {
                                // Password reset functionality would go here
                            } label: {
                                Text("Forgot Password?")
                                    .font(.footnote)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.top, 5)
                    }
                }
                .padding(.horizontal, 30)
                
                Spacer()
                
                // Login buttons
                VStack(spacing: 16) {
                    Button {
                        login()
                    } label: {
                        Group {
                            if isLoggingIn {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Log In")
                                    .font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(email.isEmpty || password.isEmpty || isLoggingIn)
                    .opacity((email.isEmpty || password.isEmpty || isLoggingIn) ? 0.6 : 1)
                    
                    // Biometric authentication
                    if biometricType != .none {
                        Button {
                            authenticateWithBiometrics()
                        } label: {
                            HStack {
                                Image(systemName: biometricType.iconName)
                                Text("Sign in with \(biometricType.title)")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                        }
                    }
                    
                    // Skip login
                    Button {
                        // Skip login and proceed to the app
                        hasCompletedLogin = true
                    } label: {
                        Text("Skip Login for Now")
                            .foregroundColor(.blue)
                    }
                    .padding(.bottom)
                    
                    // Sign up option
                    HStack {
                        Text("Don't have an account?")
                            .foregroundColor(.secondary)
                        
                        Button {
                            // Show sign up page
                        } label: {
                            Text("Sign Up")
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                    }
                    .font(.subheadline)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
            }
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert(isPresented: $showingErrorAlert) {
            Alert(
                title: Text("Login Error"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func login() {
        guard !email.isEmpty && !password.isEmpty else {
            return
        }
        
        isLoggingIn = true
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // For demonstration purposes, we'll just accept any email/password
            // In a real app, you would validate credentials against a backend
            hasCompletedLogin = true
            isLoggingIn = false
        }
    }
    
    private func authenticateWithBiometrics() {
        BiometricAuthHelper.authenticate { success, error in
            if success {
                hasCompletedLogin = true
            } else if let error = error {
                errorMessage = error
                showingErrorAlert = true
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(ChoreViewModel())
} 