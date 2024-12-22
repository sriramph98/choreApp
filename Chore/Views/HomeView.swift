import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Welcome to Chore Manager!")
                    .font(.title)
                    .padding()
                
                Text("Start managing your tasks")
                    .foregroundColor(.gray)
            }
            .navigationTitle("Home")
        }
    }
}

#Preview {
    HomeView()
} 