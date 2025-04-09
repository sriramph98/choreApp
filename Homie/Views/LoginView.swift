import SwiftUI

struct LoginView: View {
    @EnvironmentObject var choreViewModel: ChoreViewModel
    @AppStorage("hasCompletedLogin") private var hasCompletedLogin = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("isInOfflineMode") private var isInOfflineMode = false
    @StateObject private var supabaseManager = SupabaseManager.shared
    
    @State private var email = ""
    @State private var password = ""
    @State private var isSecured = true
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var showingSignUpSheet = false
    @State private var showingSuccessAlert = false
    @State private var showingOfflineNamePrompt = false
    @State private var offlineName = ""
    @State private var isInSignUpMode = false
    @State private var confirmPassword = ""
    @State private var name = ""
    @State private var showEmailSignUp = false
    @State private var showCreateHouseholdScreen = false
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Logo and header
                VStack(spacing: 10) {
                    Image("Logo")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("Homie")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Your personal task manager")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                
                // Sign in form
                VStack(spacing: 15) {
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
                    
                    // Offline mode button
                    Button {
                        createOfflineProfile()
                    } label: {
                        HStack {
                            Image(systemName: "wifi.slash")
                                .resizable()
                                .frame(width: 20, height: 20)
                                .foregroundColor(.primary)
                            Text("Offline Mode")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
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
        .sheet(isPresented: $showingOfflineNamePrompt) {
            OfflineNamePromptView(
                isPresented: $showingOfflineNamePrompt,
                name: $offlineName,
                onComplete: continueWithOfflineMode
            )
        }
        .sheet(isPresented: $showCreateHouseholdScreen) {
            CreateHouseholdView(isPresented: $showCreateHouseholdScreen)
                .environmentObject(choreViewModel)
        }
        .onAppear {
            // Always check app state when view appears
            restoreAppState()
            handleAuthStateChange()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Also check app state when app returns from background
            print("App returning to foreground, checking authentication state")
            Task {
                await supabaseManager.checkAndSetSession()
            }
        }
        .onChange(of: supabaseManager.isAuthenticated) { oldValue, newValue in
            if newValue {
                hasCompletedLogin = true
                
                // When authenticated, load data for this user
                Task {
                    if let authUser = supabaseManager.authUser {
                        print("User authenticated, loading profile for: \(authUser.id)")
                        await choreViewModel.switchToProfile(userId: authUser.id)
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
    
    private func createOfflineProfile() {
        // Check if we already have offline data saved
        if let offlineUser = choreViewModel.loadOfflineUser() {
            // User has used offline mode before, reuse existing data
            continueWithOfflineMode(name: offlineUser.name, id: offlineUser.id)
        } else {
            // First time using offline mode, ask for name
            offlineName = ""
            showingOfflineNamePrompt = true
        }
    }
    
    private func continueWithOfflineMode() {
        // Use the name from the alert, or "Offline User" as default
        let userName = offlineName.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = userName.isEmpty ? "Offline User" : userName
        let offlineUserId = UUID()
        
        continueWithOfflineMode(name: displayName, id: offlineUserId)
    }
    
    private func continueWithOfflineMode(name: String, id: UUID) {
        // Create offline user profile
        let offlineUser = User(
            id: id,
            name: name,
            avatarSystemName: "wifi.slash.circle.fill",
            color: "gray"
        )
        
        // Save offline user details for future use
        choreViewModel.saveOfflineUser(name, id: id)
        
        // Set offline mode flag in both the view model and UserDefaults
        choreViewModel.isOfflineMode = true
        isInOfflineMode = true
        
        // Clear any existing data
        choreViewModel.tasks.removeAll()
        choreViewModel.users.removeAll()
        choreViewModel.customChores.removeAll()
        
        // Try to load previous offline data
        choreViewModel.loadOfflineData()
        
        // If no existing data, create a fresh offline profile
        if choreViewModel.users.isEmpty {
            // Add the offline user to the view model
            choreViewModel.users.append(offlineUser)
            choreViewModel.currentUser = offlineUser
            
            // Add sample tasks for offline mode
            _ = choreViewModel.addTask(
                name: "Sample Task 1",
                dueDate: Date(),
                assignedTo: id
            )
            
            _ = choreViewModel.addTask(
                name: "Sample Task 2",
                dueDate: Date().addingTimeInterval(86400),
                assignedTo: id
            )
            
            // Save this initial data
            choreViewModel.saveOfflineData()
        }
        
        // Complete login without authentication
        hasCompletedLogin = true
    }
    
    // Function to restore app state when the app starts
    private func restoreAppState() {
        // Check if we're in offline mode first
        if isInOfflineMode {
            print("Restoring offline mode session")
            
            // Set the offline mode flag in the view model
            choreViewModel.isOfflineMode = true
            
            // Load the offline user data and tasks
            choreViewModel.loadOfflineData()
            
            // Complete login to bypass this screen
            hasCompletedLogin = true
            return
        }
        
        // Only check Supabase session if not in offline mode
        Task {
            await supabaseManager.checkAndSetSession()
            
            // If we have a valid session, the onChange handler for isAuthenticated
            // will handle setting hasCompletedLogin and loading data
            
            // If no active Supabase session, check if we were in offline mode
            if !supabaseManager.isAuthenticated {
                // Neither authenticated nor offline mode - show login screen
                print("No active session found, showing login screen")
                hasCompletedLogin = false
            }
        }
    }
    
    // Handle authentication state changes
    private func handleAuthStateChange() {
        // Skip auth state monitoring if in offline mode
        if isInOfflineMode {
            print("Skipping auth state monitoring - in offline mode")
            return
        }
        
        // Listen for authentication changes
        Task {
            let client = SupabaseManager.shared.client
            for await _ in client.auth.authStateChanges {
                if SupabaseManager.shared.isAuthenticated, let authUser = SupabaseManager.shared.authUser {
                    print("User authenticated: \(authUser.id)")
                    hasCompletedLogin = true
                    
                    // Clear existing data before loading new profile
                    await MainActor.run {
                        choreViewModel.tasks.removeAll()
                        choreViewModel.users.removeAll()
                        choreViewModel.customChores.removeAll()
                        choreViewModel.currentUser = nil
                        choreViewModel.households = []
                        choreViewModel.currentHousehold = nil
                    }
                    
                    // Load the profile for this user
                    await choreViewModel.switchToProfile(userId: authUser.id)
                    
                    // Check if the user has any households
                    await choreViewModel.fetchHouseholds()
                    
                    await MainActor.run {
                        let hasHouseholds = !choreViewModel.households.isEmpty
                        print("User has households: \(hasHouseholds)")
                        
                        // Update UserDefaults with household selection status
                        UserDefaults.standard.set(hasHouseholds, forKey: "hasSelectedHousehold")
                        
                        if !hasHouseholds {
                            // User has no households, show create household screen with a delay
                            // (to ensure profile loading has completed)
                            Task {
                                // Short delay to ensure user profile is loaded
                                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                                
                                await MainActor.run {
                                    // Double-check that we still don't have any households
                                    if choreViewModel.households.isEmpty {
                                        print("Showing create household screen for new user")
                                        showCreateHouseholdScreen = true
                                    } else {
                                        print("Households were found after waiting, no need to show creation screen")
                                    }
                                }
                            }
                        }
                    }
                } else {
                    print("No authenticated user")
                    hasCompletedLogin = false
                }
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
            // After successful signup, fetch the user profile from Supabase
            await choreViewModel.syncUsersFromSupabase()
            
            // Set hasCompletedLogin to true to navigate to the main app
            await MainActor.run {
                hasCompletedLogin = true
                showingSuccessAlert = true
                dismiss()
            }
        } else {
            await MainActor.run {
                errorMessage = supabaseManager.authError?.localizedDescription ?? "Sign up failed"
                showingErrorAlert = true
                isLoading = false
            }
        }
    }
}

struct OfflineNamePromptView: View {
    @Binding var isPresented: Bool
    @Binding var name: String
    var onComplete: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Please enter your name for the offline profile")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding()
                
                TextField("Your Name", text: $name)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                
                Button {
                    onComplete()
                    isPresented = false
                } label: {
                    Text("Continue")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                
                Spacer()
            }
            .padding(.top, 30)
            .navigationTitle("Offline Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(ChoreViewModel())
} 