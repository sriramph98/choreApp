import SwiftUI

struct TasksView: View {
    @EnvironmentObject var choreViewModel: ChoreViewModel
    @State private var showingAddTaskSheet = false
    @State private var selectedTask: ChoreViewModel.ChoreTask?
    @State private var showingPeopleSheet = false
    @Binding var showSettings: Bool
    @State private var showingSettings = false
    @State private var isRefreshing = false
    
    init(showSettings: Binding<Bool>) {
        self._showSettings = showSettings
    }
    
    var body: some View {
        ScrollView {
            RefreshControl(isRefreshing: $isRefreshing, coordinateSpaceName: "pullToRefresh") {
                Task {
                    await refreshData()
                }
            }
            
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
        .coordinateSpace(name: "pullToRefresh")
        .background(Color.clear)
        .sheet(isPresented: $showingAddTaskSheet) {
            AddChoreSheetView(isPresented: $showingAddTaskSheet, onAddChore: { choreName in
                // Just need to call the callback to satisfy the function signature
                // The actual task was added in the view's implementation
            }, title: "Add Homie Task", buttonText: "Add Task")
        }
        .sheet(item: $selectedTask) { task in
            TaskDetailView(task: task, onDismiss: {
                selectedTask = nil
                // Ensure view model is updated after sheet closes
                DispatchQueue.main.async {
                    choreViewModel.objectWillChange.send()
                }
            })
        }
        .sheet(isPresented: $showingPeopleSheet) {
            PeopleManagementView(isPresented: $showingPeopleSheet)
        }
        .sheet(isPresented: $showingSettings) {
            settingsSheet
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
    
    // Refresh data by reloading from Supabase
    private func refreshData() async {
        guard !choreViewModel.isOfflineMode else {
            // If offline, don't try to sync with server
            isRefreshing = false
            return
        }
        
        print("Manual refresh triggered - reloading data...")
        
        // If online and we have a current user, load tasks
        if choreViewModel.currentUser != nil {
            await choreViewModel.loadTasksForCurrentUser()
            
            // Make sure all tasks have household IDs
            await MainActor.run {
                choreViewModel.ensureTasksHaveHouseholdIds()
            }
        }
        
        // After refresh completes, update UI
        await MainActor.run {
            isRefreshing = false
            
            // Show a subtle haptic feedback to indicate the refresh completed
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }
    
    @ViewBuilder
    private func taskButton(for task: ChoreViewModel.ChoreTask, showDate: Bool = true) -> some View {
        Button {
            // Just set the selected task, the sheet will open automatically
            selectedTask = task
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
                    } else {
                        // Show "Unassigned" when no user is assigned
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill.questionmark")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Unassigned")
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
            // Include completed tasks, will show with strikethrough
            calendar.isDate(task.dueDate, inSameDayAs: today)
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
        // Include completed tasks, will show with strikethrough
        return upcomingTasks.filter { task in
            let taskDate = calendar.startOfDay(for: task.dueDate)
            let todayDate = calendar.startOfDay(for: today)
            
            return taskDate > todayDate && taskDate < endOfWeek
        }.sorted { $0.dueDate < $1.dueDate }
    }
    
    private var settingsSheet: some View {
        NavigationStack {
            List {
                Section(header: Text("Account Information")) {
                    if let currentUser = choreViewModel.currentUser {
                        // User avatar and name
                        HStack {
                            Image(systemName: currentUser.avatarSystemName)
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(currentUser.uiColor)
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(currentUser.name)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                Text(SupabaseManager.shared.authUser?.email ?? "No email")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.leading, 8)
                        }
                        .padding(.vertical, 8)
                        
                        // Account created
                        if let createdAt = SupabaseManager.shared.authUser?.createdAt {
                            HStack {
                                Text("Member Since")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(createdAt.formatted(date: .abbreviated, time: .omitted))
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                    } else {
                        Text("No user profile found")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Profile")) {
                    NavigationLink {
                        ProfileView()
                    } label: {
                        Label("Edit Profile", systemImage: "person.crop.circle")
                    }
                }
                
                Section(header: Text("App Settings")) {
                    NavigationLink {
                        Text("Notifications Settings")
                    } label: {
                        Label("Notifications", systemImage: "bell")
                    }
                    
                    NavigationLink {
                        Text("Theme Settings")
                    } label: {
                        Label("Theme", systemImage: "paintpalette")
                    }
                }
                
                Section(header: Text("Account Actions")) {
                    Button(action: {
                        Task {
                            await SupabaseManager.shared.signOut()
                        }
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(.red)
                            Text("Sign Out")
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Section(header: Text("About")) {
                    NavigationLink {
                        Text("Help & Support")
                    } label: {
                        Label("Help & Support", systemImage: "questionmark.circle")
                    }
                    
                    NavigationLink {
                        Text("Privacy Policy")
                    } label: {
                        Label("Privacy Policy", systemImage: "lock.shield")
                    }
                    
                    NavigationLink {
                        Text("Terms of Service")
                    } label: {
                        Label("Terms of Service", systemImage: "doc.text")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = false
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.gray)
                    }
                }
            }
            .onAppear {
                // Set the current user based on the authenticated user's ID
                if let authUser = SupabaseManager.shared.authUser {
                    // Find the user profile with the matching auth user ID
                    if let matchingUser = choreViewModel.users.first(where: { user in
                        // Compare the user's ID with the authenticated user's ID
                        user.id == authUser.id
                    }) {
                        // Set the found user as current user
                        choreViewModel.setCurrentUser(matchingUser)
                        print("Set current user to \(matchingUser.name) with ID \(matchingUser.id)")
                    } else {
                        print("No matching user found for auth ID: \(authUser.id)")
                    }
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
                .fill(Color.colorFromString(user.color))
            
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
    let onDismiss: () -> Void
    
    // State variables for all editable fields
    @State private var taskName: String
    @State private var isCompleted: Bool
    @State private var repeatOption: ChoreViewModel.RepeatOption
    @State private var dueDate: Date
    @State private var selectedUserId: UUID?
    @Environment(\.dismiss) private var dismiss
    
    init(task: ChoreViewModel.ChoreTask, onDismiss: @escaping () -> Void) {
        print("Initializing TaskDetailView for task: \(task.name)")
        self.task = task
        self.onDismiss = onDismiss
        
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
                    // Unassigned option
                    HStack {
                        Image(systemName: "person.fill.questionmark")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                            .frame(width: 30, height: 30)
                            .background(Color.gray.opacity(0.2))
                            .clipShape(Circle())
                        Text("Unassigned")
                            .font(.headline)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer()
                        if selectedUserId == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedUserId = nil
                    }
                    
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
                            onDismiss()
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
                            onDismiss()
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
                        dismiss()
                        onDismiss()
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
                        dismiss()
                        onDismiss()
                    }
                }
            }
            .onAppear {
                print("TaskDetailView appeared for task: \(task.name), ID: \(task.id)")
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

// Custom refresh control for SwiftUI
struct RefreshControl: View {
    @Binding var isRefreshing: Bool
    let coordinateSpaceName: String
    let onRefresh: () -> Void
    
    @State private var refreshStarted: Bool = false
    @State private var pullDistance: CGFloat = 0.0
    private let pullThreshold: CGFloat = 100.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .center) {
                if isRefreshing || pullDistance > pullThreshold {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.2)
                        .frame(width: 35, height: 35)
                } else if pullDistance > 0 {
                    // Show downward arrow that changes opacity based on pull distance
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                        .opacity(min(pullDistance / pullThreshold, 1.0))
                        .rotationEffect(.degrees(Double(pullDistance / pullThreshold) * 180))
                }
            }
            .frame(width: geometry.size.width)
            .offset(y: -pullDistance > 0 ? 0 : -pullDistance)
            .onChange(of: geometry.frame(in: .named(coordinateSpaceName)).minY) { oldValue, newValue in
                // Calculate pull distance based on scroll position
                pullDistance = max(0, newValue)
                
                // Detect when pull exceeds threshold and starts a refresh
                if newValue > pullThreshold && !refreshStarted && !isRefreshing {
                    refreshStarted = true
                    isRefreshing = true
                    onRefresh()
                }
                
                // Reset refresh tracking when scroll position returns to top
                if newValue <= 0 {
                    refreshStarted = false
                }
            }
        }
        .frame(height: max(0, pullDistance))
    }
}

#Preview {
    TasksView(showSettings: .constant(false))
        .environmentObject(ChoreViewModel())
} 