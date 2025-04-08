import SwiftUI

struct HomeView: View {
    @EnvironmentObject var choreViewModel: ChoreViewModel
    @State private var selectedTab = 0
    @State private var showSettings = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                TasksView(showSettings: $showSettings)
                    .navigationTitle("Tasks")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label("Tasks", systemImage: "checklist")
            }
            .tag(0)
            
            NavigationStack {
                ChoreCalendarView()
                    .navigationTitle("Schedule")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label("Schedule", systemImage: "calendar")
            }
            .tag(1)
            
            NavigationStack {
                VStack(spacing: 16) {
                    Spacer()
                    
                    Image(systemName: "message.badge.circle")
                        .font(.system(size: 50))
                        .foregroundStyle(.secondary)
                        .padding()
                    
                    Text("Chat Feature Coming Soon")
                        .font(.title2)
                        .fontWeight(.medium)
                    
                    Text("This feature is currently in development")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom)
                    
                    Spacer()
                }
                .navigationTitle("Chat")
                .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label("Chat", systemImage: "message")
            }
            .tag(2)
            .disabled(true)
        }
        .tint(.blue)
        .sheet(isPresented: $showSettings) {
            SettingsView(isPresented: $showSettings)
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var choreViewModel: ChoreViewModel
    @StateObject private var supabaseManager = SupabaseManager.shared
    @Binding var isPresented: Bool
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasCompletedLogin") private var hasCompletedLogin = false
    @AppStorage("isInOfflineMode") private var isInOfflineMode = false
    @State private var showingLogoutAlert = false
    
    var body: some View {
        NavigationStack {
            List {
                // User profile section
                Section(header: Text("Account Information")) {
                    if let currentUser = choreViewModel.currentUser {
                        // User avatar and name
                        HStack {
                            Image(systemName: currentUser.avatarSystemName)
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(currentUser.uiColor)
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(currentUser.name)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                if choreViewModel.isOfflineMode {
                                    Text("Offline Mode")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text(supabaseManager.authUser?.email ?? "No email")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.leading, 8)
                        }
                        .padding(.vertical, 8)
                        
                        // User ID
                        HStack {
                            Text("User ID")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(currentUser.id.uuidString.prefix(8) + "...")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        
                        // Account type
                        HStack {
                            Text("Account Type")
                                .foregroundColor(.secondary)
                            Spacer()
                            if choreViewModel.isOfflineMode {
                                Text("Offline")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            } else {
                                Text(supabaseManager.authUser?.appMetadata["provider"]?.description ?? "Email")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                        
                        // Account created
                        if !choreViewModel.isOfflineMode, let createdAt = supabaseManager.authUser?.createdAt {
                            HStack {
                                Text("Member Since")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(createdAt.formatted(date: .abbreviated, time: .omitted))
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                        
                        // Tasks stats
                        HStack {
                            Text("Assigned Tasks")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(choreViewModel.tasksAssignedTo(userId: currentUser.id).count)")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    } else {
                        Text("No user profile found")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("People")) {
                    NavigationLink {
                        SettingsPeopleView()
                    } label: {
                        Label("Manage People", systemImage: "person.2")
                    }
                }
                
                Section(header: Text("App Settings")) {
                    Button {
                        // Reset onboarding
                        hasCompletedOnboarding = false
                        isPresented = false
                    } label: {
                        Label("Reset Onboarding", systemImage: "arrow.counterclockwise")
                            .foregroundColor(.primary)
                    }
                }
                
                Section(header: Text("Account")) {
                    Button {
                        showingLogoutAlert = true
                    } label: {
                        Text(choreViewModel.isOfflineMode ? "Exit Offline Mode" : "Log Out")
                            .foregroundColor(.red)
                    }
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Homie Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
            .alert(choreViewModel.isOfflineMode ? "Exit Offline Mode" : "Log Out", isPresented: $showingLogoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button(choreViewModel.isOfflineMode ? "Exit" : "Log Out", role: .destructive) {
                    Task {
                        if choreViewModel.isOfflineMode {
                            // Save offline data before exiting
                            choreViewModel.saveOfflineData()
                            choreViewModel.isOfflineMode = false
                            // Clear the offline mode flag in UserDefaults
                            isInOfflineMode = false
                        } else {
                            _ = await supabaseManager.signOut()
                            // Clear the saved user ID from UserDefaults
                            UserDefaults.standard.removeObject(forKey: "lastAuthenticatedUserId")
                        }
                        // Clear all data when logging out
                        await MainActor.run {
                            choreViewModel.tasks.removeAll()
                            choreViewModel.users.removeAll()
                            choreViewModel.customChores.removeAll()
                            choreViewModel.currentUser = nil
                            
                            // Log out the user
                            hasCompletedLogin = false
                            isPresented = false
                        }
                    }
                }
            } message: {
                Text(choreViewModel.isOfflineMode ? 
                     "Do you want to exit offline mode? Your data will be saved for next time." : 
                     "Are you sure you want to log out?")
            }
            .onAppear {
                // Set the current user based on the authenticated user
                if !choreViewModel.isOfflineMode,
                   let _ = supabaseManager.authUser,
                   let user = choreViewModel.users.first {
                    choreViewModel.setCurrentUser(user)
                }
            }
        }
    }
}

// Renamed to avoid conflict with the one in TasksView.swift
struct SettingsPeopleView: View {
    @EnvironmentObject var choreViewModel: ChoreViewModel
    @State private var showAddPersonSheet = false
    
    var body: some View {
        List {
            ForEach(choreViewModel.users) { user in
                HStack {
                    UserInitialsView(user: user, size: 40)
                    Text(user.name)
                        .font(.headline)
                    Spacer()
                }
            }
            
            Button {
                showAddPersonSheet = true
            } label: {
                Label("Add Person", systemImage: "person.badge.plus")
            }
        }
        .navigationTitle("Manage People")
        .sheet(isPresented: $showAddPersonSheet) {
            AddPersonView(isPresented: $showAddPersonSheet)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(ChoreViewModel())
} 