import Foundation

@MainActor
class ChoreViewModel: ObservableObject {
    @Published var tasks: [ChoreTask] = []
    @Published var users: [User] = []
    @Published var customChores: [String] = []
    @Published var currentUser: User?
    @Published var isOfflineMode = false
    @Published var offlineUserData: (name: String, id: UUID)? = nil
    @Published var households: [Household] = []
    @Published var currentHousehold: Household?
    private let supabaseManager = SupabaseManager.shared
    private var lastSyncTime: Date = Date().addingTimeInterval(-3600) // Start with 1 hour ago
    
    enum RepeatOption: String, Codable {
        case never
        case daily
        case weekly
        case monthly
        case yearly
    }
    
    struct ChoreTask: Identifiable, Codable {
        var id: UUID
        var name: String
        var dueDate: Date
        var isCompleted: Bool
        var assignedTo: UUID?
        var notes: String?
        var repeatOption: RepeatOption = .never
        var parentTaskId: UUID? // Reference to the original task for repeating tasks
        var householdId: UUID? // Reference to the household this task belongs to
        
        init(id: UUID = UUID(), name: String, dueDate: Date, isCompleted: Bool, assignedTo: UUID?, notes: String? = nil, repeatOption: RepeatOption = .never, parentTaskId: UUID? = nil, householdId: UUID? = nil) {
            self.id = id
            self.name = name
            self.dueDate = dueDate
            self.isCompleted = isCompleted
            self.assignedTo = assignedTo
            self.notes = notes
            self.repeatOption = repeatOption
            self.parentTaskId = parentTaskId
            self.householdId = householdId
        }
    }
    
    // Sample data - replace with actual data source later
    init() {
        // Add some sample users
        users = User.sampleUsers
        
        // Add some sample tasks
        tasks = [
            ChoreTask(name: "Dishes", dueDate: Date(), isCompleted: false, assignedTo: users[1].id, repeatOption: .daily),
            ChoreTask(name: "Laundry", dueDate: Date().addingTimeInterval(86400), isCompleted: false, assignedTo: users[2].id, repeatOption: .weekly),
            ChoreTask(name: "Vacuum", dueDate: Date().addingTimeInterval(172800), isCompleted: false, assignedTo: users[0].id)
        ]
        
        // Try to fetch tasks from Supabase if we're authenticated
        if supabaseManager.isAuthenticated {
            Task {
                await syncTasksFromSupabase()
            }
        }
    }
    
    // Pull changes from server and update local data
    private func pullChangesFromServer() async {
        print("Pulling changes from server since \(lastSyncTime)")
        let currentSyncTime = Date()
        
        // Always sync users since they're lightweight
        if let latestUsers = await supabaseManager.fetchUsers() {
            await MainActor.run {
                updateLocalUsers(with: latestUsers)
            }
        }
        
        // For tasks, only get ones that changed since last sync
        if let modifiedTasks = await supabaseManager.fetchTasksModifiedSince(lastSyncTime) {
            if !modifiedTasks.isEmpty {
                print("Found \(modifiedTasks.count) modified tasks since last sync")
                await MainActor.run {
                    updateModifiedTasks(with: modifiedTasks)
                }
            } else {
                print("No tasks modified since last sync")
            }
        }
        
        // Update the sync timestamp for the next sync
        lastSyncTime = currentSyncTime
    }
    
    // Update only modified tasks to reduce data transfer and processing
    private func updateModifiedTasks(with modifiedTasks: [ChoreTask]) {
        // Efficiently update modified tasks by using a dictionary lookup
        var tasksDict = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
        
        for modifiedTask in modifiedTasks {
            // Replace or add the modified task
            tasksDict[modifiedTask.id] = modifiedTask
        }
        
        // Convert back to array
        tasks = Array(tasksDict.values)
    }
    
    // Full sync when needed (first login, manual sync request)
    func fullSync() async {
        guard !isOfflineMode, supabaseManager.isAuthenticated else { return }
        
        print("Performing full sync of all data")
        
        // Get all users
        if let allUsers = await supabaseManager.fetchUsers() {
            await MainActor.run {
                updateLocalUsers(with: allUsers)
            }
        }
        
        // Get all tasks
        if let allTasks = await supabaseManager.fetchTasks() {
            await MainActor.run {
                tasks = allTasks
                print("Full sync completed with \(tasks.count) tasks")
            }
        }
        
        // Reset the last sync time
        lastSyncTime = Date()
    }
    
    // Manually trigger a sync (can be called when returning to foreground or after making changes)
    func manualSync() async {
        guard !isOfflineMode, supabaseManager.isAuthenticated else { return }
        
        print("Manual sync requested")
        await pullChangesFromServer()
    }
    
    // Update local users with server data while preserving unsaved changes
    private func updateLocalUsers(with serverUsers: [User]) {
        // Find users that only exist locally
        let localOnlyUsers = users.filter { localUser in
            !serverUsers.contains { $0.id == localUser.id }
        }
        
        // Update existing users and add new ones from server
        for serverUser in serverUsers {
            if let index = users.firstIndex(where: { $0.id == serverUser.id }) {
                // Update existing user with server data
                users[index] = serverUser
            } else {
                // Add new user from server
                users.append(serverUser)
            }
        }
        
        // Add back any local-only users
        for localUser in localOnlyUsers {
            if !users.contains(where: { $0.id == localUser.id }) {
                users.append(localUser)
            }
        }
        
        // Ensure current user is still set properly
        if let currentUserId = currentUser?.id, let updatedUser = users.first(where: { $0.id == currentUserId }) {
            currentUser = updatedUser
        }
    }
    
    // Update local tasks with server data while preserving unsaved changes
    private func updateLocalTasks(with serverTasks: [ChoreTask]) {
        // Track task IDs that have been modified locally but not yet saved to server
        let localOnlyTasks = tasks.filter { localTask in
            !serverTasks.contains { $0.id == localTask.id }
        }
        
        // Replace tasks with server data
        var updatedTasks = serverTasks
        
        // Keep any local-only tasks
        for localTask in localOnlyTasks {
            updatedTasks.append(localTask)
        }
        
        tasks = updatedTasks
    }
    
    // Task management functions
    func addTask(name: String, dueDate: Date, isCompleted: Bool = false, assignedTo: UUID? = nil, notes: String? = nil, repeatOption: RepeatOption = .never, householdId: UUID? = nil) -> ChoreTask {
        // Create a new task
        let task = ChoreTask(
            id: UUID(),
            name: name,
            dueDate: dueDate,
            isCompleted: isCompleted,
            assignedTo: assignedTo,
            notes: notes,
            repeatOption: repeatOption,
            parentTaskId: nil,
            householdId: householdId ?? currentHousehold?.id
        )
        
        // Add the task to our array and save it
        tasks.append(task)
        
        // Generate future tasks if repeating
        if repeatOption != .never {
            generateFutureOccurrences(for: task)
        }
        
        // If connected to Supabase, save the task
        if supabaseManager.isAuthenticated {
            Task {
                await saveTaskToSupabase(task)
            }
        } else {
            // Save task locally
            saveOfflineTasks()
        }
        
        return task
    }
    
    // Generate future occurrences of a repeating task
    private func generateFutureOccurrences(for task: ChoreTask) {
        let calendar = Calendar.current
        var currentDate = task.dueDate
        var generatedTasks = [task]  // Include the original task in checks
        var newTasks: [ChoreTask] = []
        
        for _ in 0..<10 {
            // Calculate the next due date based on repeat option
            guard let nextDate = calculateNextDueDate(from: currentDate, option: task.repeatOption) else {
                continue
            }
            
            // Check if this date already exists among generated tasks
            let dateExists = generatedTasks.contains { existingTask in
                calendar.isDate(existingTask.dueDate, inSameDayAs: nextDate)
            }
            
            if !dateExists {
                // Create a new task for this occurrence
                let newOccurrence = ChoreTask(
                    name: task.name,
                    dueDate: nextDate,
                    isCompleted: false,
                    assignedTo: task.assignedTo,
                    notes: task.notes,
                    repeatOption: task.repeatOption,
                    parentTaskId: task.id,
                    householdId: task.householdId // Use same household as parent task
                )
                
                newTasks.append(newOccurrence)
                generatedTasks.append(newOccurrence)
            }
            
            currentDate = nextDate
        }
        
        // Add all new tasks at once
        if !newTasks.isEmpty {
            tasks.append(contentsOf: newTasks)
        }
    }
    
    // Calculate the next due date based on repeat option
    private func calculateNextDueDate(from date: Date, option: RepeatOption) -> Date? {
        let calendar = Calendar.current
        
        switch option {
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: date)
        case .weekly:
            return calendar.date(byAdding: .day, value: 7, to: date)
        case .monthly:
            // Get the same day of the next month
            var components = DateComponents()
            components.month = 1
            return calendar.date(byAdding: components, to: date)
        case .yearly:
            var components = DateComponents()
            components.year = 1
            return calendar.date(byAdding: components, to: date)
        case .never:
            return nil
        }
    }
    
    func updateTask(id: UUID, name: String? = nil, dueDate: Date? = nil, isCompleted: Bool? = nil, assignedTo: UUID? = nil, notes: String? = nil, repeatOption: RepeatOption? = nil) {
        if let index = tasks.firstIndex(where: { $0.id == id }) {
            var task = tasks[index]
            
            // Update properties if new values are provided
            if let name = name {
                task.name = name
            }
            
            if let dueDate = dueDate {
                task.dueDate = dueDate
            }
            
            if let isCompleted = isCompleted {
                task.isCompleted = isCompleted
            }
            
            if assignedTo != task.assignedTo {
                task.assignedTo = assignedTo
            }
            
            if let notes = notes {
                task.notes = notes
            }
            
            if let repeatOption = repeatOption {
                task.repeatOption = repeatOption
            }
            
            // Ensure household ID is set (if missing and we have a current household)
            if task.householdId == nil {
                task.householdId = currentHousehold?.id
            }
            
            // Update the task in our array
            tasks[index] = task
            
            // Save to Supabase if authenticated and not in offline mode
            if supabaseManager.isAuthenticated && !isOfflineMode {
                Task {
                    // Try to update the task, which is more appropriate for existing tasks
                    let success = await supabaseManager.updateTask(task)
                    if !success {
                        // If update fails (perhaps task doesn't exist yet), try saving it
                        _ = await supabaseManager.saveTask(task)
                    }
                    
                    // Force a sync after updating a task to ensure changes appear on other devices
                    await manualSync()
                }
            }
            
            // If the task has a parent and repeat settings changed, update future occurrences
            if let parentTaskId = task.parentTaskId, let originalTask = tasks.first(where: { $0.id == parentTaskId }) {
                if repeatOption != nil {
                    updateAllFutureOccurrences(originalTask: originalTask, startingFrom: task)
                }
            }
        }
    }
    
    private func updateAllFutureOccurrences(originalTask: ChoreTask, startingFrom task: ChoreTask) {
        let now = Date()
        
        Task { @MainActor in
            for i in 0..<self.tasks.count {
                if self.tasks[i].parentTaskId == originalTask.id && self.tasks[i].dueDate > now {
                    // Copy updated fields to future occurrences
                    self.tasks[i].name = task.name
                    self.tasks[i].assignedTo = task.assignedTo
                    self.tasks[i].notes = task.notes
                    self.tasks[i].repeatOption = task.repeatOption
                    
                    // Also save to Supabase
                    if supabaseManager.isAuthenticated && !isOfflineMode {
                        // Add await to fix the unused result warning
                        _ = await supabaseManager.updateTask(self.tasks[i])
                    }
                }
            }
        }
    }
    
    private func recalculateFutureDueDates(fromTaskId id: UUID) {
        // Find the original task
        guard let originalTask = tasks.first(where: { $0.id == id }) else { return }
        
        // Remove all future occurrences
        removeAllFutureOccurrences(fromTaskId: id)
        
        // Generate new occurrences based on the updated original task
        generateFutureOccurrences(for: originalTask)
    }
    
    private func removeAllFutureOccurrences(fromTaskId id: UUID) {
        let now = Date()
        // Remove all future occurrences of this task in one operation
        tasks.removeAll { $0.parentTaskId == id && $0.dueDate > now }
    }
    
    private func createNextRepeatingTask(from task: ChoreTask) {
        guard let nextDate = calculateNextDueDate(from: task.dueDate, option: task.repeatOption) else { return }
        
        // Create the next occurrence
        let newTask = ChoreTask(
            name: task.name,
            dueDate: nextDate,
            isCompleted: false,
            assignedTo: task.assignedTo,
            notes: task.notes,
            repeatOption: task.repeatOption,
            parentTaskId: task.id,
            householdId: task.householdId // Keep same household as parent
        )
        
        tasks.append(newTask)
    }
    
    func deleteTask(id: UUID) {
        // Get the task before removing it
        guard let task = tasks.first(where: { $0.id == id }) else { return }
        
        // Use MainActor.run instead of DispatchQueue.main.async for actor isolation
        Task { @MainActor in
            // Make a local copy of child tasks if needed
            var childTasksToDelete: [ChoreTask] = []
            
            // If this is a parent repeating task, also delete all its instances
            if task.repeatOption != .never && task.parentTaskId == nil {
                // Find all child instances
                childTasksToDelete = self.tasks.filter { $0.parentTaskId == id }
                
                // Remove all child instances
                self.tasks.removeAll { $0.parentTaskId == id }
                
                // Delete child tasks from Supabase if authenticated and not in offline mode
                if self.supabaseManager.isAuthenticated && !self.isOfflineMode {
                    for childTask in childTasksToDelete {
                        Task {
                            await self.deleteTaskFromSupabase(childTask.id)
                        }
                    }
                }
            }
            
            // Remove the task itself
            self.tasks.removeAll { $0.id == id }
            
            // Delete from Supabase if authenticated and not in offline mode
            if self.supabaseManager.isAuthenticated && !self.isOfflineMode {
                Task {
                    await self.deleteTaskFromSupabase(id)
                    
                    // Force a sync after deleting a task to ensure changes appear on other devices
                    await self.manualSync()
                }
            }
        }
    }
    
    // Custom chores management
    func addCustomChore(_ choreName: String) {
        if !customChores.contains(choreName) {
            customChores.append(choreName)
            
            // Also add it as a task with a random assignment
            let randomUser = users.randomElement()
            let _ = addTask(
                name: choreName,
                dueDate: Date().addingTimeInterval(Double.random(in: 0...7) * 86400),
                assignedTo: randomUser?.id
            )
        }
    }
    
    // User management functions
    func addUser(name: String, color: String, addToCurrentHousehold: Bool = true) {
        let newUser = User(id: UUID(), name: name, avatarSystemName: "person.circle.fill", color: color)
        
        // Check if user with same name already exists
        guard !users.contains(where: { $0.name.lowercased() == name.lowercased() }) else {
            return
        }
        
        users.append(newUser)
        
        // If we have a current user and we're online, save to Supabase
        if supabaseManager.isAuthenticated && !isOfflineMode {
            Task {
                _ = await supabaseManager.saveUserProfile(newUser)
                
                // If we have a current household, also add this user to it
                if addToCurrentHousehold, let currentHousehold = currentHousehold {
                    _ = await addUserToHousehold(userId: newUser.id, householdId: currentHousehold.id)
                }
            }
        }
    }
    
    func getUser(by id: UUID) -> User? {
        return users.first { $0.id == id }
    }
    
    func tasksAssignedTo(userId: UUID) -> [ChoreTask] {
        return tasks.filter { $0.assignedTo == userId }
    }
    
    /// Clears all data and reloads it for the specified user
    func switchToProfile(userId: UUID) async {
        print("Switching to profile: \(userId)")
        
        // Clear any existing data
        tasks = []
        users = []
        customChores = []
        currentUser = nil
        households = []
        currentHousehold = nil
        
        // Disable offline mode since we're switching to a profile
        isOfflineMode = false
        UserDefaults.standard.set(false, forKey: "isInOfflineMode")
        
        // Fetch users for the specified auth user ID
        if let supaUsers = await supabaseManager.fetchUsers() {
            // Process users on the main thread
            await MainActor.run {
                // Add users
                users.append(contentsOf: supaUsers)
                
                // Set current user based on the matched user
                if let currentUserMatch = users.first(where: { $0.id == userId }) {
                    currentUser = currentUserMatch
                } else if let firstUser = users.first {
                    // Fall back to the first user if we can't find one with matching ID
                    currentUser = firstUser
                }
                
                print("Switched to profile: \(userId)")
                
                // Now that we have users, fetch households for this user
                Task {
                    await fetchHouseholds()
                    
                    // After fetching households, load tasks for the selected household
                    if let firstHousehold = households.first {
                        await switchToHousehold(firstHousehold)
                    } else {
                        // If no households, load tasks for the user (without household filter)
                        await loadTasksForCurrentUser()
                    }
                }
            }
        } else {
            print("No users found for authUserId: \(userId)")
        }
    }
    
    // Make this method public for refresh functionality
    func loadTasksForCurrentUser() async {
        // Fetch all tasks for the current user without filtering by household in the database
        if let supaTasks = await supabaseManager.fetchTasks() {
            await MainActor.run {
                if let currentHousehold = currentHousehold {
                    // Filter tasks for the current household in memory
                    let filteredTasks = supaTasks.filter { task in
                        // If no household ID on the task, include it in all households for now
                        // until the database schema is updated
                        task.householdId == nil || task.householdId == currentHousehold.id
                    }
                    tasks = filteredTasks
                    print("Loaded \(tasks.count) tasks for current household \(currentHousehold.name) - filtered in memory")
                } else {
                    // No household filter needed
                    tasks = supaTasks
                    print("Loaded \(tasks.count) tasks for current user (no household filter)")
                }
            }
        }
    }
    
    // Calendar and schedule functions
    func getTasksForDay(date: Date) -> [ChoreTask] {
        let calendar = Calendar.current
        let householdId = currentHousehold?.id
        
        return tasks.filter { task in
            // First match the date
            let dateMatches = calendar.isDate(task.dueDate, inSameDayAs: date)
            
            // Then check if the task belongs to the current household or has no household
            let householdMatches = householdId == nil || task.householdId == nil || task.householdId == householdId
            
            return dateMatches && householdMatches
        }
    }
    
    func getTasksForWeek(startingFrom date: Date) -> [Date: [ChoreTask]] {
        let calendar = Calendar.current
        var result = [Date: [ChoreTask]]()
        
        // Get the start of the week containing the given date
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)) else {
            return result
        }
        
        // Create entries for each day of the week
        for dayOffset in 0..<7 {
            guard let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else {
                continue
            }
            
            // Find tasks for this day
            let dayTasks = getTasksForDay(date: dayDate)
            result[dayDate] = dayTasks
        }
        
        return result
    }
    
    // This function now returns tasks for today and the upcoming period
    func getUpcomingTasks(days: Int = 30) -> [ChoreTask] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let endDate = calendar.date(byAdding: .day, value: days, to: today) ?? today
        let householdId = currentHousehold?.id
        
        // Make sure we have enough future instances of repeating tasks
        ensureRepeatingTasksExist(until: endDate)
        
        return tasks.filter { task in
            // Filter for tasks that are due after today but before the end date
            let taskDate = calendar.startOfDay(for: task.dueDate)
            let dateMatches = taskDate >= today && taskDate <= endDate
            
            // Filter for tasks in the current household
            let householdMatches = householdId == nil || task.householdId == nil || task.householdId == householdId
            
            return dateMatches && !task.isCompleted && householdMatches
        }.sorted { $0.dueDate < $1.dueDate }
    }
    
    // Make sure we have enough instances of repeating tasks for the upcoming period
    private func ensureRepeatingTasksExist(until endDate: Date) {
        // Find all parent repeating tasks (tasks with repeatOption != never and no parentTaskId)
        let parentTasks = tasks.filter { $0.repeatOption != .never && $0.parentTaskId == nil }
        var newTasks: [ChoreTask] = []
        
        for parentTask in parentTasks {
            // Get all instances of this repeating task
            let allInstances = tasks.filter { $0.id == parentTask.id || $0.parentTaskId == parentTask.id }
            
            // Find the latest date among all instances
            if let latestDate = allInstances.map({ $0.dueDate }).max() {
                var currentDate = latestDate
                
                // Create instances until we reach the end date
                while currentDate < endDate {
                    if let nextDate = calculateNextDueDate(from: currentDate, option: parentTask.repeatOption) {
                        // Check if this date already exists in all instances
                        let calendar = Calendar.current
                        let dateExists = allInstances.contains { instance in
                            calendar.isDate(instance.dueDate, inSameDayAs: nextDate)
                        }
                        
                        if !dateExists {
                            let newTask = ChoreTask(
                                name: parentTask.name,
                                dueDate: nextDate,
                                isCompleted: false,
                                assignedTo: parentTask.assignedTo,
                                notes: parentTask.notes,
                                repeatOption: parentTask.repeatOption,
                                parentTaskId: parentTask.id,
                                householdId: parentTask.householdId
                            )
                            newTasks.append(newTask)
                        }
                        
                        currentDate = nextDate
                    } else {
                        break
                    }
                }
            }
        }
        
        // Add all new tasks at once after the loop to avoid publishing during view updates
        if !newTasks.isEmpty {
            tasks.append(contentsOf: newTasks)
        }
    }
    
    // Supabase sync functions
    func syncTasksFromSupabase() async {
        if let supaTasks = await supabaseManager.fetchTasks() {
            // Use MainActor.run instead of DispatchQueue.main.async for actor isolation
            await MainActor.run {
                // Only replace tasks from the database, keeping any local ones
                // that haven't been synced yet
                let existingIds = Set(supaTasks.map { $0.id })
                let localOnlyTasks = self.tasks.filter { !existingIds.contains($0.id) }
                
                // Merge the lists
                self.tasks = supaTasks + localOnlyTasks
            }
        }
    }
    
    private func saveTaskToSupabase(_ task: ChoreTask) async {
        // Create a temporary copy of the task without the householdId
        // since the column doesn't exist in the database yet
        var taskToSave = task
        
        // Store the householdId in memory, but don't send it to Supabase yet
        if taskToSave.householdId == nil, let currentHousehold = currentHousehold {
            taskToSave.householdId = currentHousehold.id
            print("Task \(task.id) assigned to household \(currentHousehold.id) in memory only")
        } else if taskToSave.householdId != nil {
            print("Task \(task.id) has household \(taskToSave.householdId!) in memory only")
        }
        
        _ = await supabaseManager.saveTask(taskToSave)
    }
    
    private func deleteTaskFromSupabase(_ taskId: UUID) async {
        _ = await supabaseManager.deleteTask(id: taskId)
    }
    
    // User management with Supabase
    func syncUsersFromSupabase() async {
        if let supaUsers = await supabaseManager.fetchUsers() {
            // Use MainActor.run instead of DispatchQueue.main.async for actor isolation
            await MainActor.run {
                // Add any new users from Supabase
                for user in supaUsers {
                    if !self.users.contains(where: { $0.id == user.id }) {
                        self.users.append(user)
                    }
                }
            }
        }
    }
    
    func setCurrentUser(_ user: User) {
        // Use Task to avoid publishing changes from view updates
        Task { @MainActor in
            currentUser = user
        }
    }
    
    // Offline mode persistence
    func saveOfflineUser(_ name: String, id: UUID) {
        offlineUserData = (name: name, id: id)
        
        // Store data in UserDefaults for persistence
        let defaults = UserDefaults.standard
        defaults.set(name, forKey: "offlineUserName")
        defaults.set(id.uuidString, forKey: "offlineUserId")
    }
    
    func loadOfflineUser() -> (name: String, id: UUID)? {
        if let offlineData = offlineUserData {
            return offlineData
        }
        
        // Try to load from UserDefaults
        let defaults = UserDefaults.standard
        if let name = defaults.string(forKey: "offlineUserName"),
           let idString = defaults.string(forKey: "offlineUserId"),
           let id = UUID(uuidString: idString) {
            offlineUserData = (name: name, id: id)
            return offlineUserData
        }
        
        return nil
    }
    
    // Save tasks to UserDefaults for offline use
    private func saveOfflineTasks() {
        let defaults = UserDefaults.standard
        if let tasksData = try? JSONEncoder().encode(tasks) {
            defaults.set(tasksData, forKey: "offlineTasks")
        }
    }
    
    // Save offline tasks and users to UserDefaults
    func saveOfflineData() {
        let defaults = UserDefaults.standard
        
        // Save tasks
        if let tasksData = try? JSONEncoder().encode(tasks) {
            defaults.set(tasksData, forKey: "offlineTasks")
        }
        
        // Save users
        if let usersData = try? JSONEncoder().encode(users) {
            defaults.set(usersData, forKey: "offlineUsers")
        }
        
        // Save custom chores
        defaults.set(customChores, forKey: "offlineCustomChores")
    }
    
    // Load offline data from UserDefaults
    func loadOfflineData() {
        let defaults = UserDefaults.standard
        
        // Load tasks
        if let tasksData = defaults.data(forKey: "offlineTasks"),
           let loadedTasks = try? JSONDecoder().decode([ChoreTask].self, from: tasksData) {
            tasks = loadedTasks
        }
        
        // Load users
        if let usersData = defaults.data(forKey: "offlineUsers"),
           let loadedUsers = try? JSONDecoder().decode([User].self, from: usersData) {
            users = loadedUsers
            
            // Restore current user
            if let offlineData = loadOfflineUser(),
               let user = users.first(where: { $0.id == offlineData.id }) {
                currentUser = user
            }
        }
        
        // Load custom chores
        if let loadedChores = defaults.stringArray(forKey: "offlineCustomChores") {
            customChores = loadedChores
        }
    }
    
    // MARK: - Household Management
    
    /// Fetch all households for the current user
    func fetchHouseholds() async {
        if let fetchedHouseholds = await supabaseManager.fetchHouseholds() {
            await MainActor.run {
                self.households = fetchedHouseholds
                
                // If we have households but no current one is set, use the first one
                if !fetchedHouseholds.isEmpty && currentHousehold == nil {
                    currentHousehold = fetchedHouseholds.first
                }
                
                print("Fetched \(fetchedHouseholds.count) households")
            }
        }
    }
    
    /// Create a new household
    func createHousehold(name: String) async -> Bool {
        // Ensure we have the current user and they're authenticated
        guard let currentUser = currentUser, supabaseManager.isAuthenticated else { return false }
        
        print("Creating household '\(name)' for user \(currentUser.id)")
        
        let newHousehold = Household(
            name: name,
            creatorId: currentUser.id,
            members: [currentUser.id]
        )
        
        let success = await supabaseManager.createHousehold(newHousehold)
        
        if success {
            // If created successfully, fetch all households to get the server-created one
            await fetchHouseholds()
            return true
        }
        
        return false
    }
    
    /// Switch to a specific household
    func switchToHousehold(_ household: Household) async {
        // Save previous household ID to detect changes
        let previousHouseholdId = currentHousehold?.id
        
        // Set the current household
        await MainActor.run {
            currentHousehold = household
            
            // Clear existing tasks first to ensure UI shows loading state
            if previousHouseholdId != household.id {
                tasks = []
            }
        }
        
        print("Switching to household: \(household.name) with ID: \(household.id)")
        
        // Fetch all tasks for the user and filter in memory
        if let allTasks = await supabaseManager.fetchTasks() {
            await MainActor.run {
                // Filter tasks for this household only (or tasks with no household)
                let filteredTasks = allTasks.filter { task in
                    // Include tasks with no household ID or matching household ID
                    task.householdId == nil || task.householdId == household.id
                }
                
                self.tasks = filteredTasks
                print("Loaded \(filteredTasks.count) tasks for household \(household.name)")
                
                // Make sure repeating tasks are generated
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: Date())
                let endDate = calendar.date(byAdding: .month, value: 3, to: today) ?? today
                ensureRepeatingTasksExist(until: endDate)
            }
        }
        
        // Save household selection to UserDefaults
        UserDefaults.standard.set(true, forKey: "hasSelectedHousehold")
        
        // Update UI with the appropriate household members
        await loadMembersForCurrentHousehold()
    }
    
    /// Load members for the current household
    private func loadMembersForCurrentHousehold() async {
        guard let currentHousehold = currentHousehold else { return }
        
        // Fetch all users first
        if let allUsers = await supabaseManager.fetchUsers() {
            await MainActor.run {
                // Convert household members array to a Set for faster lookup
                let memberIds = Set(currentHousehold.members.map { $0.uuidString.lowercased() })
                
                // Update users list with only household members and the current user
                users = allUsers.filter { user in
                    memberIds.contains(user.id.uuidString.lowercased()) || 
                    (currentUser != nil && user.id == currentUser!.id)
                }
                
                print("Loaded \(users.count) members for household \(currentHousehold.name)")
            }
        }
    }
    
    /// Add a user to a household
    func addUserToHousehold(userId: UUID, householdId: UUID) async -> Bool {
        return await supabaseManager.addUserToHousehold(userId: userId, householdId: householdId)
    }
    
    /// Check if the user has any households
    func hasHouseholds() -> Bool {
        return !households.isEmpty
    }
    
    /// Create a default household from existing data (for migration)
    func createDefaultHouseholdFromExistingData() async -> Bool {
        guard let currentUser = currentUser, !tasks.isEmpty else { return false }
        
        let defaultName = "My Home"
        let newHousehold = Household(
            name: defaultName,
            creatorId: currentUser.id,
            members: [currentUser.id]
        )
        
        let success = await supabaseManager.createHousehold(newHousehold)
        
        if success {
            // If created successfully, fetch all households to get the server-created one
            await fetchHouseholds()
            
            // If we have a household now, associate existing tasks with it
            if let firstHousehold = households.first {
                // Update local tasks with household ID
                for i in 0..<tasks.count {
                    if tasks[i].householdId == nil {
                        tasks[i].householdId = firstHousehold.id
                        
                        // Also update in the database if authenticated
                        if supabaseManager.isAuthenticated && !isOfflineMode {
                            Task {
                                _ = await supabaseManager.updateTask(tasks[i])
                            }
                        }
                    }
                }
                
                // Switch to the new household to load everything properly
                await switchToHousehold(firstHousehold)
            }
            
            return true
        }
        
        return false
    }
} 