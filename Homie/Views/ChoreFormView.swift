import SwiftUI

struct ChoreFormView: View {
    @EnvironmentObject var choreViewModel: ChoreViewModel
    @Binding var isPresented: Bool
    var existingTask: ChoreViewModel.ChoreTask?
    
    @State private var title = ""
    @State private var dueDate = Date()
    @State private var selectedUser: User?
    @State private var notes = ""
    
    init(isPresented: Binding<Bool>, existingTask: ChoreViewModel.ChoreTask? = nil) {
        self._isPresented = isPresented
        self.existingTask = existingTask
        
        if let task = existingTask {
            self._title = State(initialValue: task.name)
            self._dueDate = State(initialValue: task.dueDate)
            self._notes = State(initialValue: task.notes ?? "")
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Task Details") {
                    TextField("Title", text: $title)
                    
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date])
                    
                    TextField("Notes", text: $notes)
                        .frame(height: 100)
                }
                
                Section("Assign To") {
                    ForEach(choreViewModel.users) { user in
                        HStack {
                            UserInitialsView(user: user, size: 30)
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
            .navigationTitle(existingTask == nil ? "New Task" : "Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(existingTask == nil ? "Add" : "Save") {
                        if let existingTask = existingTask {
                            updateTask(id: existingTask.id)
                        } else {
                            addTask()
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let existingTask = existingTask, 
                   let assignedTo = existingTask.assignedTo, 
                   let user = choreViewModel.getUser(by: assignedTo) {
                    selectedUser = user
                }
            }
        }
    }
    
    private func addTask() {
        _ = choreViewModel.addTask(
            name: title.trimmingCharacters(in: .whitespacesAndNewlines),
            dueDate: dueDate,
            assignedTo: selectedUser?.id,
            notes: notes.isEmpty ? nil : notes
        )
        isPresented = false
    }
    
    private func updateTask(id: UUID) {
        choreViewModel.updateTask(
            id: id,
            name: title.trimmingCharacters(in: .whitespacesAndNewlines),
            dueDate: dueDate,
            isCompleted: nil,
            assignedTo: selectedUser?.id,
            notes: notes.isEmpty ? nil : notes
        )
        isPresented = false
    }
} 