import Foundation

@MainActor
class ChoreViewModel: ObservableObject {
    // MARK: - Properties
    
    /// Published state for all tasks
    @Published var tasks: [ChoreTask] = []
    
    /// Published state for users
    @Published var users: [User] = []
    
    /// Published state for custom chore templates
    @Published var customChores: [String] = []
    
    /// Currently signed-in user
    @Published var currentUser: User?
    
    /// Current households
    @Published var households: [Household] = []
    
    /// Currently selected household
    @Published var currentHousehold: Household?
    
    /// Offline mode flag
    @Published var isOfflineMode: Bool = UserDefaults.standard.bool(forKey: "isInOfflineMode")
    
    /// Offline user data for when operating without Supabase connection
    @Published var offlineUserData: (name: String, id: UUID)? = nil
    
    /// Last sync time
    var lastSyncTime = Date().addingTimeInterval(-86400) // Start by fetching last day's changes
    
    /// Check if the user is authenticated
    var isAuthenticated: Bool {
        return supabaseManager.isAuthenticated
    }
    
    // Private properties
    private let supabaseManager = SupabaseManager.shared
    
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
        // Ensure the task has a household ID (use current household)
        let taskHouseholdId = householdId ?? currentHousehold?.id
        
        if taskHouseholdId == nil {
            print("WARNING: Creating task without household ID. This task won't appear in any household view.")
        } else if currentHousehold != nil && taskHouseholdId != currentHousehold!.id {
            print("NOTE: Creating task for a different household than the current one.")
        }
        
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
            // Always use the provided householdId or currentHousehold.id
            householdId: taskHouseholdId
        )
        
        print("Created task \(task.id) with household ID: \(task.householdId?.uuidString ?? "nil") (Task: \(name))")
        
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
            saveTasksToUserDefaults()
        }
        
        return task
    }
    
    // Generate future occurrences of a repeating task
    private func generateFutureOccurrences(for task: ChoreTask) {
        let calendar = Calendar.current
        var currentDate = task.dueDate
        var generatedTasks = [task]  // Include the original task in checks
        var newTasks: [ChoreTask] = []
        
        // Ensure the parent task has a valid household ID to pass to children
        let taskHouseholdId = task.householdId ?? currentHousehold?.id
        
        if taskHouseholdId == nil {
            print("WARNING: Generating future occurrences for task without household ID. These tasks won't appear in any household view.")
        }
        
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
                    householdId: taskHouseholdId // Use same household as parent task
                )
                
                newTasks.append(newOccurrence)
                generatedTasks.append(newOccurrence)
            }
            
            currentDate = nextDate
        }
        
        // Add all new tasks at once
        if !newTasks.isEmpty {
            tasks.append(contentsOf: newTasks)
            
            // Save the new tasks to Supabase
            if supabaseManager.isAuthenticated {
                for newTask in newTasks {
                    Task {
                        await saveTaskToSupabase(newTask)
                    }
                }
            }
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
            // IMPORTANT: Only set householdId if it's currently nil, don't change existing assignments
            if task.householdId == nil {
                task.householdId = currentHousehold?.id
                print("Task \(task.id) (\(task.name)) was missing household ID, assigned to current household: \(currentHousehold?.id.uuidString ?? "nil")")
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
                    // Use Task to call the async method
                    Task {
                        await updateAllFutureOccurrences(originalTask: originalTask, startingFrom: task)
                    }
                }
            }
        }
    }
    
    private func updateAllFutureOccurrences(originalTask: ChoreTask, startingFrom task: ChoreTask) async {
        let now = Date()
        
        // No need to use Task since this method is now async
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
    @MainActor
    func loadTasksForCurrentUser() async {
        print("Loading tasks for current user")
        
        // Check if we have a current user
        guard let currentUser = self.currentUser else {
            print("No current user to load tasks for")
            return
        }
        
        print("Current user: \(currentUser.name) (ID: \(currentUser.id.uuidString))")
        
        // Get the current household ID if available
        let householdId = self.currentHousehold?.id
        if let householdId = householdId {
            print("Current household ID: \(householdId.uuidString)")
        } else {
            print("No current household ID available")
        }
        
        // Fetch tasks from Supabase
        if let fetchedTasks = await supabaseManager.fetchTasks(householdId: householdId) {
            print("Fetched \(fetchedTasks.count) tasks from Supabase")
            
            await MainActor.run {
                // Clear existing tasks
                self.tasks.removeAll()
                
                // If we have a current household, only show tasks for this household
                if let currentHouseholdId = self.currentHousehold?.id {
                    // Filter tasks by the current household ID
                    self.tasks = fetchedTasks.filter { task in
                        task.householdId == currentHouseholdId
                    }
                    print("Filtered to \(self.tasks.count) tasks for household \(currentHouseholdId)")
                } else {
                    // If no household selected, show all tasks
                    self.tasks = fetchedTasks
                }
                
                // Ensure at least 7 days of repeating tasks exist
                ensureRepeatingTasksExist()
                
                // Save tasks for offline access
                saveTasksToUserDefaults()
            }
        } else {
            print("Failed to fetch tasks from Supabase, attempting to load from offline storage")
            
            // If fetching fails, try to load from offline storage
            await MainActor.run {
                loadOfflineData()
            }
        }
    }
    
    // Calendar and schedule functions
    func getTasksForDay(date: Date) -> [ChoreTask] {
        let calendar = Calendar.current
        guard let householdId = currentHousehold?.id else {
            // If no household is selected, return no tasks
            return []
        }
        
        return tasks.filter { task in
            // First match the date
            let dateMatches = calendar.isDate(task.dueDate, inSameDayAs: date)
            
            // Then check if the task belongs ONLY to the current household
            let householdMatches = task.householdId == householdId
            
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
        
        guard let householdId = currentHousehold?.id else {
            // If no household is selected, return no tasks
            return []
        }
        
        // Make sure we have enough future instances of repeating tasks
        ensureRepeatingTasksExist(until: endDate)
        
        return tasks.filter { task in
            // Filter for tasks that are due after today but before the end date
            let taskDate = calendar.startOfDay(for: task.dueDate)
            let dateMatches = taskDate >= today && taskDate <= endDate
            
            // Filter ONLY for tasks in the current household
            let householdMatches = task.householdId == householdId
            
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
    
    // Convenience method to ensure repeating tasks exist for a specified number of days
    private func ensureRepeatingTasksExist(days: Int = 7) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let endDate = calendar.date(byAdding: .day, value: days, to: today) ?? today
        
        // Use the existing method with a calculated end date
        ensureRepeatingTasksExist(until: endDate)
    }
    
    // Supabase sync functions
    @MainActor
    func syncTasksFromSupabase() async {
        if let supaTasks = await supabaseManager.fetchTasks() {
            // Only replace tasks from the database, keeping any local ones
            // that haven't been synced yet
            let existingIds = Set(supaTasks.map { $0.id })
            let localOnlyTasks = self.tasks.filter { !existingIds.contains($0.id) }
            
            // Merge the lists
            self.tasks = supaTasks + localOnlyTasks
        }
    }
    
    private func saveTaskToSupabase(_ task: ChoreTask) async {
        if isOfflineMode {
            print("In offline mode - skipping Supabase save and storing locally")
            if let index = tasks.firstIndex(where: { $0.id == task.id }) {
                await MainActor.run {
                    tasks[index] = task
                    saveOfflineData()
                }
            } else {
                await MainActor.run {
                    tasks.append(task)
                    saveOfflineData()
                }
            }
        } else {
            // Use the original Supabase saving logic
            _ = await supabaseManager.saveTask(task)
        }
    }
    
    private func deleteTaskFromSupabase(_ taskId: UUID) async {
        if isOfflineMode {
            print("In offline mode - removing task locally")
            if let index = tasks.firstIndex(where: { $0.id == taskId }) {
                await MainActor.run {
                    tasks.remove(at: index)
                    saveOfflineData()
                }
            }
        } else {
            // Use the original Supabase deletion logic
            _ = await supabaseManager.deleteTask(id: taskId)
        }
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
    private func saveTasksToUserDefaults() {
        let defaults = UserDefaults.standard
        if let tasksData = try? JSONEncoder().encode(tasks) {
            defaults.set(tasksData, forKey: "offlineTasks")
        }
    }
    
    // Save offline tasks and users to UserDefaults
    func saveOfflineData() {
        print("Saving offline data")
        
        // Save users to UserDefaults
        do {
            let encodedUsers = try JSONEncoder().encode(self.users)
            UserDefaults.standard.set(encodedUsers, forKey: "offlineUsers")
            print("Saved \(self.users.count) users to offline storage")
        } catch {
            print("Error encoding users for offline storage: \(error)")
        }
        
        // Save tasks to UserDefaults
        do {
            let encodedTasks = try JSONEncoder().encode(self.tasks)
            UserDefaults.standard.set(encodedTasks, forKey: "offlineTasks")
            print("Saved \(self.tasks.count) tasks to offline storage")
        } catch {
            print("Error encoding tasks for offline storage: \(error)")
        }
    }
    
    // Load offline data from UserDefaults
    func loadOfflineData() {
        print("Loading offline data")
        
        // Clear any existing data
        self.tasks = []
        self.users = []
        self.customChores = []
        self.currentUser = nil
        self.households = []
        self.currentHousehold = nil
        
        // Load users from UserDefaults
        if let userData = UserDefaults.standard.data(forKey: "offlineUsers") {
            do {
                let decodedUsers = try JSONDecoder().decode([User].self, from: userData)
                self.users = decodedUsers
                print("Loaded \(decodedUsers.count) offline users")
                
                // Set current user if available
                if let firstUser = decodedUsers.first {
                    self.currentUser = firstUser
                    print("Set current user to: \(firstUser.name)")
                }
            } catch {
                print("Error decoding offline users: \(error)")
            }
        }
        
        // Load tasks from UserDefaults
        if let taskData = UserDefaults.standard.data(forKey: "offlineTasks") {
            do {
                let decodedTasks = try JSONDecoder().decode([ChoreTask].self, from: taskData)
                self.tasks = decodedTasks
                print("Loaded \(decodedTasks.count) offline tasks")
            } catch {
                print("Error decoding offline tasks: \(error)")
            }
        }
        
        // Create a default household for offline mode if none exists
        if self.households.isEmpty {
            let defaultHousehold = Household(
                id: UUID(),
                name: "Default Household",
                creatorId: self.currentUser?.id ?? UUID(),
                members: [self.currentUser?.id ?? UUID()].compactMap { $0 },
                createdAt: Date()
            )
            self.households = [defaultHousehold]
            self.currentHousehold = defaultHousehold
            print("Created default offline household")
        }
        
        // Ensure repeating tasks exist
        ensureRepeatingTasksExist()
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
        guard let currentUser = currentUser else { 
            print("Cannot create household: No current user")
            return false 
        }
        
        if !supabaseManager.isAuthenticated {
            print("Cannot create household: User not authenticated with Supabase")
            return false
        }
        
        print("Creating household '\(name)' for user \(currentUser.id)")
        
        let newHousehold = Household(
            name: name,
            creatorId: currentUser.id,
            members: [currentUser.id]
        )
        
        // First check if the households table exists in Supabase
        do {
            // Try to check if the households table exists by making a simple query
            let client = supabaseManager.client
            let testResponse = try await client
                .from("households")
                .select("id")
                .limit(1)
                .execute()
            
            print("Households table check response status: \(testResponse.status)")
            
            // If response is 404, the table likely doesn't exist
            if testResponse.status == 404 {
                print("ERROR: The 'households' table doesn't exist in your Supabase database.")
                print("Please run the create_households_table.sql migration script in the Migrations folder.")
                return false
            }
        } catch {
            print("Error checking households table: \(error)")
            // Continue anyway, as the create call will also fail if the table doesn't exist
        }
        
        // Now attempt to create the household
        let success = await supabaseManager.createHousehold(newHousehold)
        
        if success {
            print("Successfully created household in Supabase")
            
            // Add a small delay before fetching to allow Supabase to process the insertion
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
            
            // If created successfully, fetch all households to get the server-created one
            await fetchHouseholds()
            
            // Verify the household was actually created
            let hasHousehold = await MainActor.run {
                return households.contains { household in
                    household.name == name && household.creatorId == currentUser.id
                }
            }
            
            if hasHousehold {
                print("Successfully verified household creation")
                return true
            } else {
                print("WARNING: Household was reportedly created but isn't showing up in the fetched households list")
            }
            
            return true
        } else {
            print("Failed to create household in Supabase")
            return false
        }
    }
    
    /// Switch to a specific household
    @MainActor
    func switchToHousehold(_ household: Household) async {
        print("Switching to household: \(household.name)")
        
        // Clear existing tasks and users
        self.tasks.removeAll()
        
        // Store current user before clearing users
        let currentUserBackup = self.currentUser
        
        // Clear users except for the current user (which we'll restore)
        self.users.removeAll()
        
        // Set the current household
        self.currentHousehold = household
        
        // Load ONLY users that belong to this household
        await loadMembersForCurrentHousehold()
        
        // Restore current user if they were removed
        if self.users.first(where: { $0.id == currentUserBackup?.id }) == nil,
           let currentUserBackup = currentUserBackup {
            self.users.append(currentUserBackup)
        }
        
        // Fetch tasks ONLY for this household
        if let fetchedTasks = await supabaseManager.fetchTasksForHousehold(householdId: household.id) {
            // Filter tasks to ensure they belong to this household - DO NOT modify household IDs
            let filteredTasks = fetchedTasks.filter { task in
                task.householdId == household.id
            }
            
            self.tasks = filteredTasks
            print("Loaded \(filteredTasks.count) tasks for household: \(household.name)")
            
            // Ensure repeating tasks exist for the next 7 days
            ensureRepeatingTasksExist(days: 7)
            
            // Save tasks for offline access
            saveTasksToUserDefaults()
        } else {
            print("Failed to fetch tasks for household: \(household.name). Loading from cache if available.")
            loadOfflineData()
        }
        
        // Save the current household selection to UserDefaults
        saveCurrentHouseholdToUserDefaults()
    }
    
    /// Load members for the current household
    private func loadMembersForCurrentHousehold() async {
        guard let currentHousehold = currentHousehold else { 
            print("No current household selected, can't load members")
            return 
        }
        
        print("Loading members for household: \(currentHousehold.name)")
        
        // Fetch all users first
        if let allUsers = await supabaseManager.fetchUsers() {
            await MainActor.run {
                // Convert household members array to a Set for faster lookup
                let memberIds = Set(currentHousehold.members.map { $0.uuidString.lowercased() })
                
                // Update users list with ONLY household members
                // Do NOT include the current user if they're not part of this household
                let householdMembers = allUsers.filter { user in
                    memberIds.contains(user.id.uuidString.lowercased())
                }
                
                // Set the users array to contain ONLY members of this household
                self.users = householdMembers
                
                print("Loaded \(self.users.count) members for household \(currentHousehold.name)")
            }
        }
    }
    
    /// Add a user to a household
    func addUserToHousehold(userId: UUID, householdId: UUID) async -> Bool {
        return await supabaseManager.addUserToHousehold(userId: userId, householdId: householdId)
    }
    
    /// Count tasks for a specific household
    func tasksCountForHousehold(_ householdId: UUID) -> Int {
        return tasks.filter { task in
            // Only count tasks explicitly assigned to this household
            task.householdId == householdId
        }.count
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
    
    /// Assign current household ID to any unassigned tasks
    func ensureTasksHaveHouseholdIds() {
        guard let currentHousehold = currentHousehold else { return }
        
        var tasksUpdated = false
        
        // Look for tasks without a householdId and assign the current one
        // ONLY assign household ID to tasks that don't have one
        for i in 0..<tasks.count {
            if tasks[i].householdId == nil {
                tasks[i].householdId = currentHousehold.id
                tasksUpdated = true
                
                print("Assigned household ID \(currentHousehold.id) to previously unassigned task: \(tasks[i].name)")
                
                // If connected to Supabase, save the updated task
                if supabaseManager.isAuthenticated {
                    Task {
                        await saveTaskToSupabase(tasks[i])
                    }
                }
            }
        }
        
        if tasksUpdated {
            print("Updated household ID for unassigned tasks")
            if !supabaseManager.isAuthenticated {
                // Save task locally if not connected to Supabase
                saveTasksToUserDefaults()
            }
        }
    }
    
    // Save current household to UserDefaults
    private func saveCurrentHouseholdToUserDefaults() {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "hasSelectedHousehold")
        
        // Save the current household ID
        if let householdId = currentHousehold?.id {
            defaults.set(householdId.uuidString, forKey: "currentHouseholdId")
        }
    }
    
    // Add a user in offline mode
    func addOfflineUser(name: String) {
        let newUser = User(
            id: UUID(),
            name: name,
            avatarSystemName: "person.circle.fill",
            color: "gray"
        )
        
        self.users.append(newUser)
        self.currentUser = newUser
        self.saveOfflineData()
        print("Added offline user: \(name)")
    }
} 