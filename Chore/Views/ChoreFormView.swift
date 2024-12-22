import SwiftUI

struct ChoreFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var chores: [Chore]
    let users: [User]
    var existingChore: Chore?
    
    @State private var title = ""
    @State private var selectedDay: Chore.WeekDay
    @State private var selectedUser: User?
    
    init(chores: Binding<[Chore]>, users: [User], existingChore: Chore? = nil) {
        self._chores = chores
        self.users = users
        self.existingChore = existingChore
        self._title = State(initialValue: existingChore?.title ?? "")
        self._selectedDay = State(initialValue: existingChore?.day ?? .monday)
        self._selectedUser = State(initialValue: existingChore?.assignedTo)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Chore Details") {
                    TextField("Title", text: $title)
                    
                    Picker("Day", selection: $selectedDay) {
                        ForEach(Chore.WeekDay.allCases, id: \.self) { day in
                            Text(day.rawValue).tag(day)
                        }
                    }
                }
                
                Section("Assign To") {
                    ForEach(users) { user in
                        HStack {
                            UserAvatar(user: user)
                            Text(user.name)
                            Spacer()
                            if selectedUser?.id == user.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedUser = user
                        }
                    }
                }
            }
            .navigationTitle(existingChore == nil ? "New Chore" : "Edit Chore")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(existingChore == nil ? "Add" : "Save") {
                        if existingChore != nil {
                            updateChore()
                        } else {
                            addChore()
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func addChore() {
        let newChore = Chore(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            day: selectedDay,
            isCompleted: false,
            assignedTo: selectedUser
        )
        chores.append(newChore)
        dismiss()
    }
    
    private func updateChore() {
        guard let existingChore = existingChore,
              let index = chores.firstIndex(where: { $0.id == existingChore.id }) else { return }
        
        chores[index].title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        chores[index].day = selectedDay
        chores[index].assignedTo = selectedUser
        dismiss()
    }
} 