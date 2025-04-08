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
    @State private var showingSignUpSheet = false
    @State private var showingSuccessAlert = false
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Logo and header
                VStack(spacing: 15) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Homie")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Your personal task manager")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 60)
                
                // Sign in form
                VStack(spacing: 25) {
                    TextField("Email", text: $email)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    
                    // Sign in button
                    Button {
                        signIn()
                    } label: {
                        Text("Sign In")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .disabled(supabaseManager.isLoading)
                    
                    // Google sign in button
                    Button {
                        signInWithGoogle()
                    } label: {
                        HStack {
                            Image(systemName: "g.circle.fill")
                                .resizable()
                                .frame(width: 20, height: 20)
                                .foregroundColor(.primary)
                            Text("Sign in with Google")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    .disabled(supabaseManager.isLoading)
                    
                    // Sign up prompt
                    HStack {
                        Text("Don't have an account?")
                            .foregroundColor(.secondary)
                        Button {
                            showingSignUpSheet = true
                        } label: {
                            Text("Sign Up")
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.top, 10)
                }
                .padding(.horizontal, 30)
                
                if supabaseManager.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding()
                }
                
                Spacer()
            }
        }
        .alert(isPresented: $showingErrorAlert) {
            Alert(
                title: Text("Sign In Error"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert("Sign Up Successful", isPresented: $showingSuccessAlert) {
            Button("OK") { }
        } message: {
            Text("Your account has been created successfully. You can now sign in with your email and password.")
        }
        .sheet(isPresented: $showingSignUpSheet) {
            SignUpView(
                email: email,
                password: password,
                showingSuccessAlert: $showingSuccessAlert
            )
            .environmentObject(choreViewModel)
        }
        .onChange(of: supabaseManager.isAuthenticated) { oldValue, newValue in
            if newValue {
                hasCompletedLogin = true
                
                // When authenticated, clear existing data and load fresh data for this user
                Task {
                    if let authUser = supabaseManager.authUser {
                        // First fetch users to ensure we have the current user's profile
                        if let supabaseUsers = await supabaseManager.fetchUsers() {
                            if supabaseUsers.isEmpty {
                                // No profile exists yet, this might be a new sign-up
                                print("No existing profile found for user \(authUser.id)")
                            } else {
                                // Profile exists, switch to it
                                await choreViewModel.switchToProfile(userId: authUser.id)
                            }
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
    
    private func signIn() {
        if !email.isEmpty && !password.isEmpty {
            print("Attempting to log in with email: \(email)")
            
            Task {
                let success = await supabaseManager.signIn(email: email, password: password)
                
                if !success {
                    errorMessage = supabaseManager.authError?.localizedDescription ?? "Invalid email or password"
                    showingErrorAlert = true
                }
            }
        }
    }
    
    private func signInWithGoogle() {
        Task {
            let success = await supabaseManager.signInWithProvider(provider: .google)
            if !success && supabaseManager.authError == nil {
                errorMessage = "Unable to sign in with Google"
                showingErrorAlert = true
            }
        }
    }
}

struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var choreViewModel: ChoreViewModel
    @StateObject private var supabaseManager = SupabaseManager.shared
    
    @State var email: String
    @State var password: String
    @Binding var showingSuccessAlert: Bool
    
    @State private var confirmPassword: String = ""
    @State private var isSecured = true
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var name: String = ""
    @State private var isLoading = false
    @AppStorage("hasCompletedLogin") private var hasCompletedLogin = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Name field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Name")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    TextField("Your name", text: $name)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .autocapitalization(.words)
                        .autocorrectionDisabled()
                }
                
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
                                SecureField("Create password", text: $password)
                            } else {
                                TextField("Create password", text: $password)
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
                    
                    if !password.isEmpty {
                        Text("Password must be at least 6 characters")
                            .font(.caption)
                            .foregroundColor(password.count >= 6 ? Color.green : Color.red)
                    }
                }
                
                // Confirm Password field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Confirm Password")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Group {
                            if isSecured {
                                SecureField("Confirm password", text: $confirmPassword)
                            } else {
                                TextField("Confirm password", text: $confirmPassword)
                            }
                        }
                        .padding()
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    }
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    if !confirmPassword.isEmpty {
                        Text("Passwords must match")
                            .font(.caption)
                            .foregroundColor(password == confirmPassword ? Color.green : Color.red)
                    }
                }
                
                Spacer()
                
                // Sign up button
                Button {
                    Task {
                        await signUp()
                    }
                } label: {
                    Group {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Sign Up")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isFormValid ? Color.blue : Color.blue.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!isFormValid || isLoading)
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Create Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.gray)
                    }
                }
            }
            .alert(isPresented: $showingErrorAlert) {
                Alert(
                    title: Text("Sign Up Error"),
                    message: Text(errorMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    private var isFormValid: Bool {
        !name.isEmpty &&
        !email.isEmpty &&
        email.contains("@") &&
        password.count >= 6 &&
        password == confirmPassword
    }
    
    private func signUp() async {
        guard !name.isEmpty, !email.isEmpty, !password.isEmpty, !confirmPassword.isEmpty else {
            errorMessage = "Please fill in all fields"
            showingErrorAlert = true
            return
        }
        
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match"
            showingErrorAlert = true
            return
        }
        
        isLoading = true
        
        let success = await supabaseManager.signUp(
            email: email,
            password: password,
            name: name
        )
        
        if success {
            // Create a new user profile
            let newUser = User(
                id: supabaseManager.authUser?.id ?? UUID(),
                name: name,
                avatarSystemName: "person.circle.fill",
                color: "blue"
            )
            
            // Clear existing data
            await MainActor.run {
                choreViewModel.tasks.removeAll()
                choreViewModel.users.removeAll()
                choreViewModel.customChores.removeAll()
                choreViewModel.currentUser = nil
            }
            
            // Add the user to the view model (don't use addUser which adds to existing users)
            await MainActor.run {
                choreViewModel.users.append(newUser)
                choreViewModel.currentUser = newUser
                hasCompletedLogin = true
            }
            
            // Save the user profile to Supabase
            let profileSaved = await supabaseManager.saveUserProfile(newUser)
            print("Profile saved: \(profileSaved)")
            
            // Show success alert and dismiss
            await MainActor.run {
                showingSuccessAlert = true
                dismiss()
            }
        } else {
            await MainActor.run {
                errorMessage = supabaseManager.authError?.localizedDescription ?? "Sign up failed"
                showingErrorAlert = true
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(ChoreViewModel())
} 