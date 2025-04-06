import SwiftUI

struct HomeView: View {
    @EnvironmentObject var choreViewModel: ChoreViewModel
    @State private var selectedTab = 0
    @State private var showSettings = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationView {
                TasksView()
                    .navigationTitle("Tasks")
                    .navigationBarTitleDisplayMode(.large)
                    .toolbar(content: {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showSettings = true
                            } label: {
                                Image(systemName: "gear")
                                    .foregroundStyle(.primary)
                            }
                        }
                    })
                    .background(Color.clear) // Clear background to let the HomeImage show through
            }
            .tabItem {
                Label("Tasks", systemImage: "checklist")
            }
            .tag(0)
            
            NavigationView {
                ChoreCalendarView()
                    .navigationTitle("Schedule")
                    .navigationBarTitleDisplayMode(.large)
                    .background(Color.clear) // Clear background
            }
            .tabItem {
                Label("Schedule", systemImage: "calendar")
            }
            .tag(1)
            
            NavigationView {
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
                .background(Color.clear) // Clear background
            }
            .tabItem {
                Label("Chat", systemImage: "message")
            }
            .tag(2)
            .disabled(true)
        }
        .tint(.blue) // Use tint instead of accentColor
        // Transparent tab bar with blur
        .onAppear {
            // Create a transparent tab bar with blur
            let tabBarAppearance = UITabBarAppearance()
            tabBarAppearance.configureWithTransparentBackground()
            
            // Add blur effect
            tabBarAppearance.backgroundEffect = UIBlurEffect(style: .systemMaterial)
            
            // Customize tab bar items
            let itemAppearance = UITabBarItemAppearance()
            tabBarAppearance.stackedLayoutAppearance = itemAppearance
            
            UITabBar.appearance().standardAppearance = tabBarAppearance
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
            
            // Transparent navigation bar with blur
            let navigationBarAppearance = UINavigationBarAppearance()
            navigationBarAppearance.configureWithTransparentBackground()
            navigationBarAppearance.backgroundEffect = UIBlurEffect(style: .systemMaterial)
            navigationBarAppearance.titleTextAttributes = [.foregroundColor: UIColor.label]
            navigationBarAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]

            UINavigationBar.appearance().standardAppearance = navigationBarAppearance
            UINavigationBar.appearance().compactAppearance = navigationBarAppearance
            UINavigationBar.appearance().scrollEdgeAppearance = navigationBarAppearance
        }
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
        NavigationView {
            List {
                Section(header: Text("People")) {
                    NavigationLink {
                        PeopleManagementView()
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
            .navigationBarItems(trailing: Button("Done") {
                isPresented = false
            })
        }
    }
}

struct PeopleManagementView: View {
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
            AddPersonSheetView(isPresented: $showAddPersonSheet)
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