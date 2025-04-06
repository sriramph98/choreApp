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
    @Binding var isPresented: Bool
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    var body: some View {
        NavigationStack {
            List {
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