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
        NavigationStack {
            VStack(spacing: 30) {
                // App title and icon
                VStack(spacing: 16) {
                    Image("Logo")
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
                            showingSignUpSheet = true
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
            .sheet(isPresented: $showingSignUpSheet) {
                SignUpView(email: email, password: password, showingSuccessAlert: $showingSuccessAlert)
                    .environmentObject(choreViewModel)
            }
        }
        .alert(isPresented: $showingErrorAlert) {
            Alert(
                title: Text("Login Error"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert(isPresented: $showingSuccessAlert) {
            Alert(
                title: Text("Sign Up Successful"),
                message: Text("Your account has been created successfully. You can now log in."),
                dismissButton: .default(Text("OK"))
            )
        }
        .onChange(of: supabaseManager.isAuthenticated) { oldValue, newValue in
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
            print("Attempting to log in with email: \(email)")
            let success = await supabaseManager.signIn(email: email, password: password)
            
            if !success {
                if let error = supabaseManager.authError {
                    print("Login failed with error: \(error.localizedDescription)")
                    errorMessage = error.localizedDescription
                } else {
                    print("Login failed without specific error")
                    errorMessage = "Invalid email or password"
                }
                showingErrorAlert = true
            } else {
                print("Login successful")
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
            
            // Add the user to the view model
            await MainActor.run {
                choreViewModel.addUser(name: name, color: "blue")
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