import SwiftUI

struct HomeView: View {
    @EnvironmentObject var choreViewModel: ChoreViewModel
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationView {
                ChoreCalendarView()
                    .navigationTitle("Chore Calendar")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                // TODO: Add settings or profile menu
                            } label: {
                                Image(systemName: "person.circle")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
            }
            .tabItem {
                Label("Calendar", systemImage: "calendar")
            }
            .tag(0)
            
            NavigationView {
                ChatView()
            }
            .tabItem {
                Label("Chat", systemImage: "message")
            }
            .tag(1)
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(ChoreViewModel())
} 