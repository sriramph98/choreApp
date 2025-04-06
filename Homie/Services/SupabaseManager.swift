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
        
        self.client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey
        )
        
        // Check for existing session on init
        Task {
            await checkAndSetSession()
        }
    }
    
    // MARK: - Authentication Methods
    
    /// Check for existing session and set user if available
    @MainActor
    func checkAndSetSession() async {
        do {
            isLoading = true
            let session = try await client.auth.session
            self.authUser = session.user
            self.isAuthenticated = true
        } catch {
            self.authUser = nil
            self.isAuthenticated = false
        }
        isLoading = false
    }
    
    /// Sign in with email and password
    @MainActor
    func signIn(email: String, password: String) async -> Bool {
        isLoading = true
        authError = nil
        
        do {
            let authResponse = try await client.auth.signIn(
                email: email,
                password: password
            )
            
            self.authUser = authResponse.user
            self.isAuthenticated = true
            isLoading = false
            return true
        } catch {
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
            // Create a redirect URL using the app's bundle ID
            let bundleID = Bundle.main.bundleIdentifier ?? "com.chore.app"
            let redirectURLString = "\(bundleID)://auth-callback"
            
            // Create a URL from the string
            guard let redirectURL = URL(string: redirectURLString) else {
                self.authError = NSError(domain: "SupabaseManager", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Invalid redirect URL"])
                isLoading = false
                return false
            }
            
            _ = try await client.auth.signInWithOAuth(
                provider: provider,
                redirectTo: redirectURL
            )
            
            // This is a redirect-based auth so we'll need to handle differently
            // The actual user data would be set during checkAndSetSession after redirect
            
            isLoading = false
            return true
        } catch {
            self.authError = error
            isLoading = false
            return false
        }
    }
    
    /// Sign up with email and password
    @MainActor
    func signUp(email: String, password: String) async -> Bool {
        isLoading = true
        authError = nil
        
        do {
            let authResponse = try await client.auth.signUp(
                email: email,
                password: password
            )
            
            self.authUser = authResponse.user
            self.isAuthenticated = true
            isLoading = false
            return true
        } catch {
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
            let response = try await client
                .from("tasks")
                .select()
                .eq("user_id", value: userId)
                .execute()
            
            let data = response.data
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            let tasks = try decoder.decode([TaskModel].self, from: data)
            
            // Convert to app's ChoreTask model
            return tasks.map { task in
                return ChoreViewModel.ChoreTask(
                    id: UUID(uuidString: task.id) ?? UUID(),
                    name: task.name,
                    dueDate: ISO8601DateFormatter().date(from: task.dueDate) ?? Date(),
                    isCompleted: task.isCompleted,
                    assignedTo: UUID(uuidString: task.assignedTo ?? "") ?? nil,
                    notes: task.notes,
                    repeatOption: ChoreViewModel.RepeatOption(rawValue: task.repeatOption ?? "never") ?? .never,
                    parentTaskId: task.parentTaskId != nil ? UUID(uuidString: task.parentTaskId!) : nil
                )
            }
        } catch {
            print("Error fetching tasks: \(error)")
            return nil
        }
    }
    
    /// Save a task to Supabase
    @MainActor
    func saveTask(_ task: ChoreViewModel.ChoreTask) async -> Bool {
        guard isAuthenticated, let userId = authUser?.id else { return false }
        
        // Convert to TaskModel for database
        let taskModel = TaskModel(
            id: task.id.uuidString,
            userId: userId.uuidString,
            name: task.name,
            dueDate: ISO8601DateFormatter().string(from: task.dueDate),
            isCompleted: task.isCompleted,
            assignedTo: task.assignedTo?.uuidString,
            notes: task.notes,
            repeatOption: task.repeatOption.rawValue,
            parentTaskId: task.parentTaskId?.uuidString,
            createdAt: ISO8601DateFormatter().string(from: Date())
        )
        
        do {
            // Use the TaskModel directly since it's already Encodable
            _ = try await client
                .from("tasks")
                .upsert(taskModel)
                .execute()
            
            return true
        } catch {
            print("Error saving task: \(error)")
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
    
    /// Save a user profile to Supabase
    @MainActor
    func saveUserProfile(_ user: User) async -> Bool {
        guard isAuthenticated, let userId = authUser?.id else { return false }
        
        // Convert to UserModel for database
        let userModel = UserModel(
            id: user.id.uuidString,
            authUserId: userId.uuidString,
            name: user.name,
            avatarSystemName: user.avatarSystemName,
            color: user.color,
            createdAt: ISO8601DateFormatter().string(from: Date())
        )
        
        do {
            // Use the UserModel directly since it's already Encodable
            _ = try await client
                .from("profiles")
                .upsert(userModel)
                .execute()
            
            return true
        } catch {
            print("Error saving user: \(error)")
            return false
        }
    }
    
    /// Fetch all users for the current user's account
    @MainActor
    func fetchUsers() async -> [User]? {
        guard isAuthenticated, let userId = authUser?.id else { return nil }
        
        do {
            let stringUserId = userId
            let response = try await client
                .from("profiles")
                .select()
                .eq("auth_user_id", value: stringUserId)
                .execute()
            
            let data = response.data
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            let users = try decoder.decode([UserModel].self, from: data)
            
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