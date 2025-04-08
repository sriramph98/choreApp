import Foundation
import Supabase
import Auth

/// Manager class for all Supabase-related operations
class SupabaseManager: ObservableObject {
    // MARK: - Properties
    
    /// Shared instance for singleton access
    @MainActor static let shared = SupabaseManager()
    
    /// Supabase client instance
    let client: SupabaseClient
    
    /// Published properties for auth state
    @Published var authUser: Auth.User?
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var authError: Error?
    
    // MARK: - Initialization
    
    private init() {
        // Initialize Supabase client with your project URL and anon key
        // Replace these with your actual Supabase project credentials
        let supabaseURL = URL(string: "https://jhefnaijefjnnxvjcrvx.supabase.co")!
        let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpoZWZuYWlqZWZqbm54dmpjcnZ4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDM5MzQ1NzMsImV4cCI6MjA1OTUxMDU3M30.rXl-DdyP8mkocGrunSpyrnQtQIvoDP3k3BfWMvXtOfU"
        
        // Print debug info
        print("Initializing Supabase client with URL: \(supabaseURL)")
        
        // Initialize with default options
        self.client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey
        )
        
        print("Supabase client initialized successfully")
        
        // Check for existing session on init
        Task {
            await checkAndSetSession()
        }
    }
    
    // MARK: - Authentication Methods
    
    /// Check for existing session and set user if available
    @MainActor
    func checkAndSetSession() async {
        print("Checking for existing Supabase session...")
        
        // Start with isLoading true to prevent UI flicker
        isLoading = true
        
        do {
            // First try to retrieve the session from Supabase
            let session = try await client.auth.session
            print("Found existing session: \(session.accessToken)")
            
            // We have a valid session, set the user and authentication state
            let user = session.user
            print("Setting authenticated user: \(user.id)")
            self.authUser = user
            self.isAuthenticated = true
            
            // Save the user ID to UserDefaults to ensure persistence
            UserDefaults.standard.set(user.id.uuidString, forKey: "lastAuthenticatedUserId")
            
            // Verify session is actually valid by making a simple API call
            if let _ = await fetchUsers() {
                print("Session verified - successfully fetched users")
            } else {
                // If API call fails, session might be invalid or expired
                print("Session verification failed - could not fetch data")
                throw NSError(domain: "com.homie.app", code: 401, userInfo: [NSLocalizedDescriptionKey: "Session expired"])
            }
        } catch {
            print("No valid session found: \(error)")
            
            // Clear authentication state
            self.authUser = nil
            self.isAuthenticated = false
            
            // Try to recover using the last known user ID if we have one
            if let lastUserIdString = UserDefaults.standard.string(forKey: "lastAuthenticatedUserId") {
                print("Found previous user ID: \(lastUserIdString) but could not restore session")
            }
        }
        
        isLoading = false
    }
    
    /// Sign in with email and password
    @MainActor
    func signIn(email: String, password: String) async -> Bool {
        isLoading = true
        authError = nil
        
        print("Attempting to sign in with email: \(email)")
        
        do {
            let authResponse = try await client.auth.signIn(
                email: email,
                password: password
            )
            
            print("Sign in successful with user ID: \(authResponse.user.id)")
            print("Access token: \(authResponse.accessToken.prefix(15))...")
            
            self.authUser = authResponse.user
            self.isAuthenticated = true
            
            // Fetch user profile and tasks after successful login
            if let users = await fetchUsers() {
                print("Successfully fetched \(users.count) users for the account")
            }
            
            if let tasks = await fetchTasks() {
                print("Successfully fetched \(tasks.count) tasks for the user")
            }
            
            isLoading = false
            return true
        } catch {
            print("Sign in error: \(error.localizedDescription)")
            self.authError = error
            isLoading = false
            return false
        }
    }
    
    /// Sign in with Apple, Google, etc.
    @MainActor
    func signInWithProvider(provider: Provider) async -> Bool {
        isLoading = true
        authError = nil
        
        do {
            // For iOS apps, we need to use a deep link back to the app
            // This URL must match your URL scheme in Info.plist
            let bundleId = Bundle.main.bundleIdentifier ?? "com.homie.app"
            let redirectURL = URL(string: "\(bundleId)://login-callback")!
            
            print("Starting OAuth sign in with provider: \(provider)")
            print("Using redirect URL: \(redirectURL)")
            
            // Use the correct options format for the current SDK version
            let response = try await client.auth.signInWithOAuth(
                provider: provider,
                redirectTo: redirectURL,
                queryParams: [("prefers_ephemeral_web_browser_session", "true")]
            )
            
            print("OAuth sign in successful with user ID: \(response.user.id)")
            print("User email: \(response.user.email ?? "No email")")
            print("User metadata: \(response.user.userMetadata)")
            
            // Store user and mark as authenticated
            self.authUser = response.user
            self.isAuthenticated = true
            
            // Check if user profile exists
            if let users = await fetchUsers(), users.isEmpty {
                print("No user profile found, creating one...")
                
                // Extract name from user metadata
                let name = response.user.userMetadata["full_name"]?.stringValue ?? 
                          response.user.userMetadata["name"]?.stringValue ?? 
                          response.user.email?.components(separatedBy: "@").first ?? 
                          "User"
                
                // Create a new user profile
                let newUser = User(
                    id: response.user.id,
                    name: name,
                    avatarSystemName: "person.circle.fill",
                    color: "blue"
                )
                
                // Save user profile
                let profileSaved = await saveUserProfile(newUser)
                if profileSaved {
                    print("Created new user profile for OAuth user")
                } else {
                    print("Failed to create user profile for OAuth user")
                }
            }
            
            // Fetch user profile and tasks after successful login
            if let users = await fetchUsers() {
                print("Successfully fetched \(users.count) users for the account")
            }
            
            if let tasks = await fetchTasks() {
                print("Successfully fetched \(tasks.count) tasks for the user")
            }
            
            isLoading = false
            return true
        } catch {
            print("OAuth error: \(error.localizedDescription)")
            self.authError = error
            isLoading = false
            return false
        }
    }
    
    /// Sign up with email and password
    @MainActor
    func signUp(email: String, password: String, name: String) async -> Bool {
        isLoading = true
        authError = nil
        
        print("Attempting to sign up with email: \(email)")
        
        do {
            // 1. Sign up with Supabase
            let response = try await client.auth.signUp(
                email: email,
                password: password,
                data: ["name": AnyJSON(stringLiteral: name)]
            )
            
            // The response.user is non-optional in this version of the SDK
            let user = response.user
            print("Sign up successful with user ID: \(user.id)")
            print("User email: \(user.email ?? "No email")")
            print("User metadata: \(user.userMetadata)")
            
            // 4. Store user and mark as authenticated
            self.authUser = user
            self.isAuthenticated = true
            
            // 2. Create user profile using the authenticated user's ID
            let newUser = User(
                id: user.id,  // Use the auth user's ID
                name: name,
                avatarSystemName: "person.circle.fill",
                color: "blue"
            )
            
            // 3. Save profile to Supabase
            let profileSaved = await saveUserProfile(newUser)
            if profileSaved {
                print("User profile saved successfully to Supabase")
            } else {
                print("Failed to save user profile to Supabase")
            }
            
            // 5. Fetch initial data
            if let users = await fetchUsers() {
                print("Successfully fetched \(users.count) users for the account")
            }
            
            if let tasks = await fetchTasks() {
                print("Successfully fetched \(tasks.count) tasks for the user")
            }
            
            isLoading = false
            return true
            
        } catch {
            print("Sign up error: \(error.localizedDescription)")
            self.authError = error
            isLoading = false
            return false
        }
    }
    
    /// Sign out the current user
    @MainActor
    func signOut() async -> Bool {
        isLoading = true
        authError = nil
        
        do {
            try await client.auth.signOut()
            self.authUser = nil
            self.isAuthenticated = false
            isLoading = false
            return true
        } catch {
            self.authError = error
            isLoading = false
            return false
        }
    }
    
    // MARK: - Database Methods
    
    /// Fetch all tasks for the current user
    @MainActor
    func fetchTasks() async -> [ChoreViewModel.ChoreTask]? {
        guard isAuthenticated, let userId = authUser?.id else { return nil }
        
        do {
            let stringUserId = userId.uuidString
            print("Fetching tasks for user_id: \(stringUserId)")
            
            let response = try await client
                .from("tasks")
                .select()
                .eq("userid", value: stringUserId)
                .order("createdat", ascending: false) // Get newest first
                .execute()
                
            print("Task fetch response status: \(response.status)")
            
            let data = response.data
            
            // Custom key mapping for database column names to model properties
            let customKeyMapping: [String: String] = [
                "id": "id",
                "userid": "userId",
                "name": "name",
                "duedate": "dueDate",
                "iscompleted": "isCompleted",
                "assignedto": "assignedTo",
                "notes": "notes",
                "repeatoption": "repeatOption",
                "parenttaskid": "parentTaskId",
                "createdat": "createdAt"
            ]
            
            let tasks = try decode(data: data, keyMapping: customKeyMapping, as: [TaskModel].self)
            
            print("Decoded \(tasks.count) tasks for user \(stringUserId)")
            
            // Convert to app's ChoreTask model
            return tasks.map { task in
                return ChoreViewModel.ChoreTask(
                    id: UUID(uuidString: task.id) ?? UUID(),
                    name: task.name,
                    dueDate: ISO8601DateFormatter().date(from: task.dueDate) ?? Date(),
                    isCompleted: task.isCompleted,
                    assignedTo: task.assignedTo != nil && !task.assignedTo!.isEmpty ? UUID(uuidString: task.assignedTo!) : nil,
                    notes: task.notes?.isEmpty == true ? nil : task.notes,
                    repeatOption: ChoreViewModel.RepeatOption(rawValue: task.repeatOption ?? "never") ?? .never,
                    parentTaskId: task.parentTaskId != nil && !task.parentTaskId!.isEmpty ? UUID(uuidString: task.parentTaskId!) : nil
                )
            }
        } catch {
            print("Error fetching tasks for user \(userId.uuidString): \(error)")
            return nil
        }
    }
    
    /// Fetch all tasks that have been modified since a given timestamp
    @MainActor
    func fetchTasksModifiedSince(_ timestamp: Date) async -> [ChoreViewModel.ChoreTask]? {
        guard isAuthenticated, let userId = authUser?.id else { return nil }
        
        do {
            let stringUserId = userId.uuidString
            let isoFormatter = ISO8601DateFormatter()
            let timestampString = isoFormatter.string(from: timestamp)
            
            print("Fetching tasks modified since \(timestamp)")
            
            // Use createdat instead of updatedat since that's what exists in the database
            let response = try await client
                .from("tasks")
                .select()
                .eq("userid", value: stringUserId)
                .gt("createdat", value: timestampString)
                .order("createdat", ascending: false)
                .execute()
            
            print("Modified tasks fetch response status: \(response.status)")
            
            let data = response.data
            
            // Custom key mapping for database column names to model properties
            let customKeyMapping: [String: String] = [
                "id": "id",
                "userid": "userId",
                "name": "name",
                "duedate": "dueDate",
                "iscompleted": "isCompleted",
                "assignedto": "assignedTo",
                "notes": "notes",
                "repeatoption": "repeatOption",
                "parenttaskid": "parentTaskId",
                "createdat": "createdAt"
            ]
            
            let tasks = try decode(data: data, keyMapping: customKeyMapping, as: [TaskModel].self)
            
            print("Decoded \(tasks.count) modified tasks since \(timestamp)")
            
            // Convert to app's ChoreTask model
            return tasks.map { task in
                return ChoreViewModel.ChoreTask(
                    id: UUID(uuidString: task.id) ?? UUID(),
                    name: task.name,
                    dueDate: ISO8601DateFormatter().date(from: task.dueDate) ?? Date(),
                    isCompleted: task.isCompleted,
                    assignedTo: task.assignedTo != nil && !task.assignedTo!.isEmpty ? UUID(uuidString: task.assignedTo!) : nil,
                    notes: task.notes?.isEmpty == true ? nil : task.notes,
                    repeatOption: ChoreViewModel.RepeatOption(rawValue: task.repeatOption ?? "never") ?? .never,
                    parentTaskId: task.parentTaskId != nil && !task.parentTaskId!.isEmpty ? UUID(uuidString: task.parentTaskId!) : nil
                )
            }
        } catch {
            print("Error fetching modified tasks: \(error)")
            return nil
        }
    }
    
    /// Save a task to Supabase
    @MainActor
    func saveTask(_ task: ChoreViewModel.ChoreTask) async -> Bool {
        guard isAuthenticated, let userId = authUser?.id else { return false }
        
        print("Saving task with ID: \(task.id) and user_id: \(userId)")
        
        do {
            let currentTime = ISO8601DateFormatter().string(from: Date())
            
            // Create a dictionary with the right data types for Supabase
            var taskData: [String: AnyJSON] = [
                "id": AnyJSON(stringLiteral: task.id.uuidString),
                "name": AnyJSON(stringLiteral: task.name),
                "duedate": AnyJSON(stringLiteral: ISO8601DateFormatter().string(from: task.dueDate)),
                "iscompleted": AnyJSON(booleanLiteral: task.isCompleted),
                "repeatoption": AnyJSON(stringLiteral: task.repeatOption.rawValue),
                "userid": AnyJSON(stringLiteral: userId.uuidString),
                "createdat": AnyJSON(stringLiteral: currentTime)
                // Removed updatedat field that doesn't exist in the database
            ]
            
            // Only add optional fields if they have valid values
            if let assignedTo = task.assignedTo, !assignedTo.uuidString.isEmpty {
                taskData["assignedto"] = AnyJSON(stringLiteral: assignedTo.uuidString)
            }
            
            if let notes = task.notes, !notes.isEmpty {
                taskData["notes"] = AnyJSON(stringLiteral: notes)
            }
            
            if let parentTaskId = task.parentTaskId, !parentTaskId.uuidString.isEmpty {
                taskData["parenttaskid"] = AnyJSON(stringLiteral: parentTaskId.uuidString)
            }
            
            print("Saving task with data: \(taskData)")
            
            // Use upsert instead of insert to handle existing tasks
            let response = try await client
                .from("tasks")
                .upsert(taskData)
                .execute()
            
            print("Task save response: \(response)")
            return true
        } catch {
            print("Error saving task: \(error) - make sure the information saved in the app is in the supabase")
            return false
        }
    }
    
    /// Delete a task from Supabase
    @MainActor
    func deleteTask(id: UUID) async -> Bool {
        guard isAuthenticated else { return false }
        
        do {
            let stringId = id.uuidString
            _ = try await client
                .from("tasks")
                .delete()
                .eq("id", value: stringId)
                .execute()
            
            return true
        } catch {
            print("Error deleting task: \(error)")
            return false
        }
    }
    
    /// Save user profile to Supabase
    @MainActor
    func saveUserProfile(_ user: User) async -> Bool {
        guard isAuthenticated, let authUserId = authUser?.id else { 
            print("Cannot save profile: No authenticated user")
            return false 
        }
        
        do {
            // Ensure the authUserId value matches the current authenticated user's ID
            let profileData: [String: AnyJSON] = [
                "id": AnyJSON(stringLiteral: user.id.uuidString),
                "authuserid": AnyJSON(stringLiteral: authUserId.uuidString),
                "name": AnyJSON(stringLiteral: user.name),
                "avatarsystemname": AnyJSON(stringLiteral: user.avatarSystemName),
                "color": AnyJSON(stringLiteral: user.color),
                "createdat": AnyJSON(stringLiteral: ISO8601DateFormatter().string(from: Date()))
            ]
            
            print("Saving profile with data: \(profileData)")
            
            // Use upsert instead of insert to handle existing profiles
            let response = try await client
                .from("profiles")
                .upsert(profileData)
                .execute()
            
            print("Profile saved successfully: \(response)")
            return true
        } catch {
            print("Error saving profile: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Fetch all users for the current user's account
    @MainActor
    func fetchUsers() async -> [User]? {
        guard isAuthenticated, let userId = authUser?.id else { return nil }
        
        do {
            let stringUserId = userId.uuidString
            print("Fetching users for auth_user_id: \(stringUserId)")
            
            // First try with the expected column name
            let response = try await client
                .from("profiles")
                .select()
                .eq("authuserid", value: stringUserId)
                .order("createdat", ascending: false)
                .execute()
            
            print("User fetch response status: \(response.status)")
            
            let data = response.data
            
            // Custom key mapping for snake_case to camelCase
            let customKeyMapping: [String: String] = [
                "id": "id",
                "authuserid": "authUserId",
                "name": "name",
                "avatarsystemname": "avatarSystemName",
                "color": "color",
                "createdat": "createdAt",
                "updatedat": "updatedAt"
            ]
            
            let users = try decode(data: data, keyMapping: customKeyMapping, as: [UserModel].self)
            
            print("Decoded \(users.count) users from response")
            
            // Convert to app's User model
            return users.map { user in
                return User(
                    id: UUID(uuidString: user.id) ?? UUID(),
                    name: user.name,
                    avatarSystemName: user.avatarSystemName,
                    color: user.color
                )
            }
        } catch {
            print("Error fetching users: \(error)")
            return nil
        }
    }
    
    /// Update an existing task in Supabase
    @MainActor
    func updateTask(_ task: ChoreViewModel.ChoreTask) async -> Bool {
        guard isAuthenticated, let userId = authUser?.id else { return false }
        
        print("Updating task with ID: \(task.id) and user_id: \(userId)")
        
        do {
            // Create a dictionary with the right data types for Supabase
            var taskData: [String: AnyJSON] = [
                "name": AnyJSON(stringLiteral: task.name),
                "duedate": AnyJSON(stringLiteral: ISO8601DateFormatter().string(from: task.dueDate)),
                "iscompleted": AnyJSON(booleanLiteral: task.isCompleted),
                "repeatoption": AnyJSON(stringLiteral: task.repeatOption.rawValue)
                // Removed updatedat field that doesn't exist in the database
            ]
            
            // Only add optional fields if they have valid values
            if let assignedTo = task.assignedTo, !assignedTo.uuidString.isEmpty {
                taskData["assignedto"] = AnyJSON(stringLiteral: assignedTo.uuidString)
            } else {
                // Clear the assignedto field if no one is assigned
                taskData["assignedto"] = AnyJSON.null
            }
            
            if let notes = task.notes, !notes.isEmpty {
                taskData["notes"] = AnyJSON(stringLiteral: notes)
            }
            
            if let parentTaskId = task.parentTaskId, !parentTaskId.uuidString.isEmpty {
                taskData["parenttaskid"] = AnyJSON(stringLiteral: parentTaskId.uuidString)
            }
            
            print("Updating task with data: \(taskData)")
            
            // Use update instead of upsert/insert for existing tasks
            let response = try await client
                .from("tasks")
                .update(taskData)
                .eq("id", value: task.id.uuidString)
                .execute()
            
            print("Task update response: \(response)")
            return true
        } catch {
            print("Error updating task: \(error) - make sure the task exists in the database")
            return false
        }
    }
    
    // Helper function to decode JSON with custom key mapping
    private func decode<T: Decodable>(data: Data, keyMapping: [String: String], as type: T.Type) throws -> T {
        let jsonObj = try JSONSerialization.jsonObject(with: data)
        
        guard var jsonArray = jsonObj as? [[String: Any]] else {
            // If not an array, try as a single object
            if let jsonDict = jsonObj as? [String: Any] {
                let mappedDict = applyKeyMapping(to: jsonDict, using: keyMapping)
                let mappedData = try JSONSerialization.data(withJSONObject: mappedDict)
                return try JSONDecoder().decode(T.self, from: mappedData)
            }
            throw NSError(domain: "Decoding", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON structure"])
        }
        
        // Apply mapping to each dictionary in the array
        for i in 0..<jsonArray.count {
            jsonArray[i] = applyKeyMapping(to: jsonArray[i], using: keyMapping)
        }
        
        let mappedData = try JSONSerialization.data(withJSONObject: jsonArray)
        return try JSONDecoder().decode(T.self, from: mappedData)
    }
    
    // Helper function to map keys from database to model properties
    private func applyKeyMapping(to dict: [String: Any], using mapping: [String: String]) -> [String: Any] {
        var result = [String: Any]()
        
        for (key, value) in dict {
            if let mappedKey = mapping[key] {
                result[mappedKey] = value
            } else {
                result[key] = value
            }
        }
        
        return result
    }
}

// MARK: - Data Models for Supabase

/// Task model for Supabase database
struct TaskModel: Codable {
    let id: String
    let userId: String
    let name: String
    let dueDate: String
    let isCompleted: Bool
    let assignedTo: String?
    let notes: String?
    let repeatOption: String?
    let parentTaskId: String?
    let createdAt: String
}

/// User model for Supabase database
struct UserModel: Codable {
    let id: String
    let authUserId: String
    let name: String
    let avatarSystemName: String
    let color: String
    let createdAt: String
} 