import SwiftUI

struct TasksView: View {
    @EnvironmentObject var choreViewModel: ChoreViewModel
    @State private var showingAddPersonSheet = false
    @State private var showingAddTaskSheet = false
    @State private var newPersonName = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // People Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("People")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    
                    ForEach(choreViewModel.users) { user in
                        HStack {
                            UserInitialsView(user: user)
                                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                            
                            Text(user.name)
                                .font(.headline)
                            
                            Spacer()
                            
                            Text("\(choreViewModel.tasksAssignedTo(userId: user.id).count) tasks")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Material.regularMaterial)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    Button(action: {
                        showingAddPersonSheet = true
                    }) {
                        Label("Add Person", systemImage: "person.badge.plus")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Material.regularMaterial)
                            .cornerRadius(12)
                            .padding(.horizontal)
                    }
                }
                .padding(.top)
                
                // Tasks Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tasks")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    
                    ForEach(choreViewModel.tasks) { task in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(task.name)
                                    .font(.headline)
                                
                                if let assignedTo = task.assignedTo, 
                                   let user = choreViewModel.getUser(by: assignedTo) {
                                    HStack {
                                        UserInitialsView(user: user, size: 24)
                                            .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                                        Text(user.name)
                                            .font(.caption)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            Text(task.dueDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Material.regularMaterial)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    Button(action: {
                        showingAddTaskSheet = true
                    }) {
                        Label("Add Task", systemImage: "plus.circle")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Material.regularMaterial)
                            .cornerRadius(12)
                            .padding(.horizontal)
                    }
                }
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 16)
        }
        .background(Color.clear)
        .sheet(isPresented: $showingAddPersonSheet) {
            AddPersonView(isPresented: $showingAddPersonSheet)
        }
        .sheet(isPresented: $showingAddTaskSheet) {
            ChoreFormView(isPresented: $showingAddTaskSheet)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddTaskSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }
}

struct UserInitialsView: View {
    let user: User
    var size: CGFloat = 36
    
    var initials: String {
        let components = user.name.components(separatedBy: " ")
        if components.count > 1 {
            if let first = components.first?.first, let last = components.last?.first {
                return "\(first)\(last)"
            }
        }
        return user.name.prefix(2).uppercased()
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(user.color))
            
            Text(initials)
                .font(.system(size: size * 0.4))
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
    }
}

struct AddPersonView: View {
    @EnvironmentObject var choreViewModel: ChoreViewModel
    @Binding var isPresented: Bool
    @State private var name = ""
    @State private var selectedColor = "blue"
    
    let colors = ["blue", "green", "red", "purple", "orange", "pink"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Person Details")) {
                    TextField("Name", text: $name)
                    
                    Picker("Color", selection: $selectedColor) {
                        ForEach(colors, id: \.self) { color in
                            Text(color.capitalized)
                                .foregroundColor(Color(color))
                        }
                    }
                }
                
                Section {
                    Button("Add Person") {
                        if !name.isEmpty {
                            choreViewModel.addUser(name: name, color: selectedColor)
                            isPresented = false
                        }
                    }
                    .disabled(name.isEmpty)
                }
            }
            .navigationTitle("Add Person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

#Preview {
    TasksView()
        .environmentObject(ChoreViewModel())
} 