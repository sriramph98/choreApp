import SwiftUI

struct HomeView: View {
    @EnvironmentObject var choreViewModel: ChoreViewModel
    @State private var selectedTab = 0
    @State private var showSettings = false
    @State private var showHouseholdList = false
    @AppStorage("hasSelectedHousehold") private var hasSelectedHousehold = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                TasksView(showSettings: $showSettings)
                    .navigationTitle(choreViewModel.currentHousehold?.name ?? "Tasks")
                    .navigationBarTitleDisplayMode(.large)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                showHouseholdList = true
                            } label: {
                                HStack {
                                    Image(systemName: "house")
                                    Text(choreViewModel.currentHousehold?.name ?? "Home")
                                        .font(.subheadline)
                                    Image(systemName: "chevron.down")
                                        .font(.caption)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
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
        .sheet(isPresented: $showHouseholdList) {
            HouseholdListView()
                .environmentObject(choreViewModel)
                .onDisappear {
                    refreshAllData()
                }
        }
    }
    
    // Force a reload of task data to ensure UI is updated
    private func refreshAllData() {
        Task {
            // Re-fetch tasks with current household filter
            if let currentHousehold = choreViewModel.currentHousehold {
                print("Refreshing data for household: \(currentHousehold.name)")
                
                // First clear all existing tasks to avoid showing stale data
                await MainActor.run {
                    choreViewModel.tasks = []
                }
                
                // Fetch fresh data
                await choreViewModel.loadTasksForCurrentUser()
                
                // Ensure all tasks have the correct household ID
                await MainActor.run {
                    choreViewModel.ensureTasksHaveHouseholdIds()
                }
                
                // Refresh the task list with a short delay to ensure UI updates
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                await choreViewModel.loadTasksForCurrentUser()
            }
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
    @AppStorage("hasSelectedHousehold") private var hasSelectedHousehold = false
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
                
                Section(header: Text("Household")) {
                    if let currentHousehold = choreViewModel.currentHousehold {
                        HStack {
                            Text("Current Household")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(currentHousehold.name)
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        }
                        
                        NavigationLink {
                            HouseholdMembersView(household: currentHousehold)
                        } label: {
                            Label("Manage Members", systemImage: "person.2")
                        }
                        
                        Button {
                            // Reset household selection and close settings
                            hasSelectedHousehold = false
                            isPresented = false
                        } label: {
                            Label("Switch Household", systemImage: "house.circle")
                                .foregroundColor(.primary)
                        }
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
            .navigationTitle("Settings")
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
                // Set the current user based on the authenticated user's ID
                if !choreViewModel.isOfflineMode, let authUser = supabaseManager.authUser {
                    // Find the user profile with the matching auth user ID
                    if let matchingUser = choreViewModel.users.first(where: { user in
                        // Compare the user's ID with the authenticated user's ID
                        user.id == authUser.id
                    }) {
                        // Set the found user as current user
                        choreViewModel.setCurrentUser(matchingUser)
                        print("Set current user to \(matchingUser.name) with ID \(matchingUser.id)")
                    } else {
                        print("No matching user found for auth ID: \(authUser.id)")
                    }
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