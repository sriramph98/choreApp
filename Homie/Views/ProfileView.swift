import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var choreViewModel: ChoreViewModel
    @StateObject private var supabaseManager = SupabaseManager.shared
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Profile Information")) {
                    if let currentUser = choreViewModel.currentUser {
                        HStack {
                            Image(systemName: currentUser.avatarSystemName)
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(currentUser.uiColor)
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(currentUser.name)
                                    .font(.headline)
                                Text(supabaseManager.authUser?.email ?? "No email")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.leading, 8)
                        }
                        .padding(.vertical, 8)
                    } else {
                        Text("No user profile found")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Account Actions")) {
                    Button(action: {
                        Task {
                            await supabaseManager.signOut()
                        }
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                        }
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            // Set the current user based on the authenticated user
            if let authUser = supabaseManager.authUser,
               let user = choreViewModel.users.first(where: { $0.id == authUser.id }) {
                choreViewModel.setCurrentUser(user)
            }
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(ChoreViewModel())
} 