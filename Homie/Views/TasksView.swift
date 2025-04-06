import SwiftUI

struct TasksView: View {
    @EnvironmentObject var choreViewModel: ChoreViewModel
    @State private var showingAddTaskSheet = false
    @State private var showingTaskDetailSheet = false
    @State private var showingPeopleSheet = false
    @State private var selectedTask: ChoreViewModel.ChoreTask?
    @Binding var showSettings: Bool
    
    init(showSettings: Binding<Bool>) {
        self._showSettings = showSettings
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Tasks Section
                VStack(alignment: .leading, spacing: 8) {
                    // Today's Tasks
                    HStack {
                        Text("Today")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        // Add today's date
                        Text(Date().formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                    
                    ForEach(getTodayTasks()) { task in
                        taskButton(for: task, showDate: false)
                    }
                    
                    if !getTodayTasks().isEmpty {
                        Divider()
                            .padding(.vertical, 8)
                            .padding(.horizontal)
                    }
                    
                    // Upcoming Tasks
                    Text("This Week")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    
                    ForEach(getUpcomingTasks()) { task in
                        taskButton(for: task, showDate: true)
                    }
                }
                .padding(.vertical, 16)
            }
            .padding(.horizontal, 16)
        }
        .background(Color.clear)
        .sheet(isPresented: $showingAddTaskSheet) {
            AddChoreSheetView(isPresented: $showingAddTaskSheet, onAddChore: { choreName in
                // Just need to call the callback to satisfy the function signature
                // The actual task was added in the view's implementation
            }, title: "Add Homie Task", buttonText: "Add Task")
        }
        .sheet(isPresented: $showingTaskDetailSheet, onDismiss: {
            // Reset selectedTask when the sheet is dismissed
            selectedTask = nil
        }) {
            if let task = selectedTask {
                // Force the ID here to ensure proper instantiation
                TaskDetailView(task: task, isPresented: $showingTaskDetailSheet)
                    .id("taskDetail-\(task.id)")
                    .onAppear {
                        // Ensure the view has all task data on first appearance
                        print("Task detail view appeared for: \(task.name)")
                    }
                    .onDisappear {
                        // Make sure UI updates when the sheet is dismissed
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            choreViewModel.objectWillChange.send()
                        }
                    }
            }
        }
        .sheet(isPresented: $showingPeopleSheet) {
            PeopleManagementView(isPresented: $showingPeopleSheet)
        }
        .toolbar {
            // Left side - Settings icon
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gear")
                        .foregroundStyle(.primary)
                }
            }
            
            // Right side - People and Add buttons only
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        showingPeopleSheet = true
                    } label: {
                        Image(systemName: "person.3")
                            .foregroundStyle(.primary)
                    }
                    
                    Button {
                        showingAddTaskSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func taskButton(for task: ChoreViewModel.ChoreTask, showDate: Bool = true) -> some View {
        Button {
            // Set the selected task first
            selectedTask = task
            
            // Then present the sheet with a slight delay to ensure the task is set
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                showingTaskDetailSheet = true
            }
        } label: {
            HStack(spacing: 8) {
                // Left side: Task name and assigned person
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .strikethrough(task.isCompleted, color: .gray)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    if let assignedTo = task.assignedTo, 
                       let user = choreViewModel.getUser(by: assignedTo) {
                        HStack(spacing: 4) {
                            UserInitialsView(user: user, size: 20)
                                .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                            Text(user.name)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Right side: Date and repeat info with fixed width
                if showDate {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(task.dueDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        // Show repeat frequency text
                        if task.repeatOption != .never {
                            Text(repeatFrequencyText(task.repeatOption))
                                .font(.caption2)
                                .foregroundColor(.blue)
                                .lineLimit(1)
                        }
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
            }
            .padding()
            .background(Material.regularMaterial.opacity(task.isCompleted ? 0.7 : 1))
            .cornerRadius(12)
            .padding(.horizontal)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                // Delete task
                choreViewModel.deleteTask(id: task.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                // Toggle completion state
                choreViewModel.updateTask(
                    id: task.id,
                    name: nil,
                    dueDate: nil,
                    isCompleted: !task.isCompleted,
                    assignedTo: nil,
                    notes: nil
                )
            } label: {
                Label(task.isCompleted ? "Undo" : "Done", systemImage: task.isCompleted ? "arrow.uturn.backward" : "checkmark")
            }
            .tint(.green)
        }
    }
    
    // Helper to display repeat frequency
    private func repeatFrequencyText(_ option: ChoreViewModel.RepeatOption) -> String {
        switch option {
        case .daily:
            return "Daily"
        case .weekly:
            return "Weekly"
        case .monthly:
            return "Monthly"
        case .yearly:
            return "Yearly"
        case .never:
            return ""
        }
    }
    
    private func getTodayTasks() -> [ChoreViewModel.ChoreTask] {
        let today = Date()
        let calendar = Calendar.current
        
        // Ensure we have all repeating tasks ready before filtering
        // This forces the system to generate repeating tasks as needed
        _ = choreViewModel.getUpcomingTasks(days: 60)
        
        return choreViewModel.tasks.filter { task in
            !task.isCompleted && calendar.isDate(task.dueDate, inSameDayAs: today)
        }
    }
    
    private func getUpcomingTasks() -> [ChoreViewModel.ChoreTask] {
        let today = Date()
        let calendar = Calendar.current
        
        // Calculate the end of the current week (next Sunday at midnight)
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        guard let startOfWeek = calendar.date(from: components) else { return [] }
        guard let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek) else { return [] }
        
        // Get up to 30 days of tasks to ensure we capture all repeating instances
        let upcomingTasks = choreViewModel.getUpcomingTasks(days: 30)
        
        // Filter tasks that are after today but within this week
        return upcomingTasks.filter { task in
            let taskDate = calendar.startOfDay(for: task.dueDate)
            let todayDate = calendar.startOfDay(for: today)
            
            return taskDate > todayDate && taskDate < endOfWeek
        }.sorted { $0.dueDate < $1.dueDate }
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

struct TaskDetailView: View {
    @EnvironmentObject var choreViewModel: ChoreViewModel
    let task: ChoreViewModel.ChoreTask
    @Binding var isPresented: Bool
    
    // State variables for all editable fields
    @State private var taskName: String
    @State private var isCompleted: Bool
    @State private var repeatOption: ChoreViewModel.RepeatOption
    @State private var dueDate: Date
    @State private var selectedUserId: UUID?
    
    init(task: ChoreViewModel.ChoreTask, isPresented: Binding<Bool>) {
        self.task = task
        self._isPresented = isPresented
        
        // Initialize all state variables
        self._taskName = State(initialValue: task.name)
        self._isCompleted = State(initialValue: task.isCompleted)
        self._repeatOption = State(initialValue: task.repeatOption)
        self._dueDate = State(initialValue: task.dueDate)
        self._selectedUserId = State(initialValue: task.assignedTo)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // Task name - now editable
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Task Name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("Task Name", text: $taskName)
                            .font(.headline)
                            .padding(.vertical, 4)
                    }
                    
                    // Due date - now editable
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date])
                    
                    // Repeat option picker
                    Picker("Repeats", selection: $repeatOption) {
                        Text("Never").tag(ChoreViewModel.RepeatOption.never)
                        Text("Every Day").tag(ChoreViewModel.RepeatOption.daily)
                        Text("Every Week").tag(ChoreViewModel.RepeatOption.weekly)
                        Text("Every Month").tag(ChoreViewModel.RepeatOption.monthly)
                        Text("Every Year").tag(ChoreViewModel.RepeatOption.yearly)
                    }
                    
                    // Completed toggle
                    Toggle("Completed", isOn: $isCompleted)
                }
                
                // Assigned to section - now editable
                Section(header: Text("Assign To")) {
                    ForEach(choreViewModel.users) { user in
                        HStack {
                            UserInitialsView(user: user, size: 30)
                            Text(user.name)
                                .font(.headline)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Spacer()
                            if selectedUserId == user.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedUserId = user.id
                        }
                    }
                }
                
                // Only show delete button for non-repeating tasks or parent repeating tasks
                if task.repeatOption == .never || task.parentTaskId == nil {
                    Section {
                        // Delete task button
                        Button(role: .destructive) {
                            choreViewModel.deleteTask(id: task.id)
                            isPresented = false
                        } label: {
                            HStack {
                                Spacer()
                                Label("Delete Task", systemImage: "trash")
                                Spacer()
                            }
                        }
                    }
                } else {
                    // For child repeat instances, offer to delete just this instance
                    Section {
                        Button(role: .destructive) {
                            choreViewModel.deleteTask(id: task.id)
                            isPresented = false
                        } label: {
                            HStack {
                                Spacer()
                                Label("Delete This Instance", systemImage: "trash")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Task Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        // Save all changes
                        choreViewModel.updateTask(
                            id: task.id,
                            name: taskName,
                            dueDate: dueDate,
                            isCompleted: isCompleted,
                            assignedTo: selectedUserId,
                            notes: nil,
                            repeatOption: repeatOption
                        )
                        isPresented = false
                    }
                }
            }
            .id(task.id) // Force view recreation when task changes
        }
    }
}

// Using the component from the onboarding flow
struct AddPersonView: View {
    @EnvironmentObject var choreViewModel: ChoreViewModel
    @Binding var isPresented: Bool
    @State private var name = ""
    @State private var selectedColor = "blue"
    
    let colors = ["blue", "green", "red", "purple", "orange", "pink"]
    
    var body: some View {
        NavigationStack {
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

struct PeopleManagementView: View {
    @EnvironmentObject var choreViewModel: ChoreViewModel
    @Binding var isPresented: Bool
    @State private var showAddPersonSheet = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(choreViewModel.users) { user in
                    HStack {
                        UserInitialsView(user: user, size: 40)
                        Text(user.name)
                            .font(.headline)
                        Spacer()
                        
                        Text("\(choreViewModel.tasksAssignedTo(userId: user.id).count) tasks")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                Button {
                    showAddPersonSheet = true
                } label: {
                    Label("Add Person", systemImage: "person.badge.plus")
                }
            }
            .navigationTitle("People")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
            .sheet(isPresented: $showAddPersonSheet) {
                AddPersonView(isPresented: $showAddPersonSheet)
            }
        }
    }
}

#Preview {
    TasksView(showSettings: .constant(false))
        .environmentObject(ChoreViewModel())
} 