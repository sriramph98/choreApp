import SwiftUI

struct LoginView: View {
    @EnvironmentObject var choreViewModel: ChoreViewModel
    @AppStorage("hasCompletedLogin") private var hasCompletedLogin = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var supabaseManager = SupabaseManager.shared
    
    @State private var email = ""
    @State private var password = ""
    @State private var isSecured = true
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    private var biometricType = BiometricAuthHelper.getBiometricType()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                // App title and icon
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                        .foregroundColor(.blue)
                        .padding(.top, 20)
                    
                    Text("Homie")
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
                        Task {
                            await loginWithSupabase()
                        }
                    } label: {
                        Group {
                            if supabaseManager.isLoading {
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
                    .disabled(email.isEmpty || password.isEmpty || supabaseManager.isLoading)
                    .opacity((email.isEmpty || password.isEmpty || supabaseManager.isLoading) ? 0.6 : 1)
                    
                    // Social login options
                    VStack(spacing: 12) {
                        Button {
                            Task {
                                await signInWithGoogle()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "g.circle.fill")
                                    .font(.title3)
                                Text("Continue with Google")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                        }
                        
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
                            showSignUp()
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
        .onChange(of: supabaseManager.isAuthenticated) { newValue in
            if newValue {
                hasCompletedLogin = true
                
                // Also fetch and sync user data from Supabase
                Task {
                    if let supabaseUsers = await supabaseManager.fetchUsers() {
                        // Update local user data
                        DispatchQueue.main.async {
                            for user in supabaseUsers {
                                if !choreViewModel.users.contains(where: { $0.id == user.id }) {
                                    choreViewModel.users.append(user)
                                }
                            }
                        }
                    }
                    
                    if let supaTasks = await supabaseManager.fetchTasks() {
                        // Update local tasks
                        DispatchQueue.main.async {
                            choreViewModel.tasks = supaTasks
                        }
                    }
                }
            }
        }
        .onReceive(supabaseManager.$authError) { error in
            if let error = error {
                errorMessage = error.localizedDescription
                showingErrorAlert = true
            }
        }
    }
    
    private func loginWithSupabase() async {
        if !email.isEmpty && !password.isEmpty {
            let success = await supabaseManager.signIn(email: email, password: password)
            if !success && supabaseManager.authError == nil {
                errorMessage = "Invalid email or password"
                showingErrorAlert = true
            }
        }
    }
    
    private func signInWithGoogle() async {
        let success = await supabaseManager.signInWithProvider(provider: .google)
        if !success && supabaseManager.authError == nil {
            errorMessage = "Unable to sign in with Google"
            showingErrorAlert = true
        }
    }
    
    private func authenticateWithBiometrics() {
        BiometricAuthHelper.authenticate { success, error in
            if success {
                // If successful, try to use stored credentials or token
                hasCompletedLogin = true
            } else if let error = error {
                errorMessage = error
                showingErrorAlert = true
            }
        }
    }
    
    private func showSignUp() {
        // Ideally navigate to sign up screen
        Task {
            if !email.isEmpty && !password.isEmpty {
                let success = await supabaseManager.signUp(email: email, password: password)
                if success {
                    // Successfully created account and logged in
                    hasCompletedLogin = true
                }
            } else {
                errorMessage = "Please enter an email and password to sign up"
                showingErrorAlert = true
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(ChoreViewModel())
} 