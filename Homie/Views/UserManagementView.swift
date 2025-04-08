import SwiftUI

struct UserManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var users: [User]
    @State private var newUserName = ""
    @State private var selectedColor = "blue"
    @State private var showingAlert = false
    
    private let availableColors = [
        "blue", "green", "purple", "red", "orange", 
        "pink", "cyan", "indigo", "mint"
    ]
    
    var body: some View {
        NavigationView {
            List {
                Section("Add New User") {
                    TextField("Name", text: $newUserName)
                    
                    HStack {
                        Text("Color")
                        Spacer()
                        ForEach(availableColors, id: \.self) { color in
                            Circle()
                                .fill(colorFromString(color))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle()
                                        .stroke(color == selectedColor ? Color.primary : Color.clear, lineWidth: 2)
                                )
                                .onTapGesture {
                                    selectedColor = color
                                }
                        }
                    }
                    
                    Button("Add User") {
                        addUser()
                    }
                    .disabled(newUserName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                
                Section("Current Users") {
                    ForEach(users) { user in
                        HStack {
                            Image(systemName: user.avatarSystemName)
                                .foregroundColor(colorFromString(user.color))
                            Text(user.name)
                            Spacer()
                        }
                    }
                    .onDelete(perform: deleteUsers)
                }
            }
            .navigationTitle("Manage Users")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func addUser() {
        let trimmedName = newUserName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        let newUser = User(
            name: trimmedName,
            avatarSystemName: "person.circle.fill",
            color: selectedColor
        )
        
        users.append(newUser)
        newUserName = ""
    }
    
    private func deleteUsers(at offsets: IndexSet) {
        users.remove(atOffsets: offsets)
    }
} 