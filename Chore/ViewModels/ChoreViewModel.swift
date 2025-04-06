import Foundation

class ChoreViewModel: ObservableObject {
    @Published var tasks: [ChoreTask] = []
    @Published var users: [User] = []
    @Published var customChores: [String] = []
    
    enum RepeatOption: String, Codable {
        case never
        case daily
        case weekly
        case monthly
        case yearly
    }
    
    struct ChoreTask: Identifiable {
        let id = UUID()
        var name: String
        var dueDate: Date
        var isCompleted: Bool
        var assignedTo: UUID?
        var notes: String?
        var repeatOption: RepeatOption = .never
        var parentTaskId: UUID? // Reference to the original task for repeating tasks
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
    }
    
    // Task management functions
    func addTask(name: String, dueDate: Date, assignedTo: UUID?, notes: String? = nil, repeatOption: RepeatOption = .never) {
        let newTask = ChoreTask(name: name, dueDate: dueDate, isCompleted: false, assignedTo: assignedTo, notes: notes, repeatOption: repeatOption)
        tasks.append(newTask)
        
        // If this is a repeating task, generate the next few occurrences in advance
        if repeatOption != .never {
            // Generate 10 occurrences to ensure we have enough for the visible future
            generateFutureOccurrences(for: newTask, count: 10)
        }
    }
    
    // Generate future occurrences of a repeating task
    private func generateFutureOccurrences(for task: ChoreTask, count: Int) {
        let calendar = Calendar.current
        var currentDate = task.dueDate
        var generatedTasks = [task]  // Include the original task in checks
        var newTasks: [ChoreTask] = []
        
        for _ in 0..<count {
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
                    parentTaskId: task.id
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
    
    func updateTask(id: UUID, name: String?, dueDate: Date?, isCompleted: Bool?, assignedTo: UUID?, notes: String?, repeatOption: RepeatOption? = nil) {
        if let index = tasks.firstIndex(where: { $0.id == id }) {
            var task = tasks[index]
            let originalIsCompleted = task.isCompleted
            
            if let name = name {
                task.name = name
                
                // If name changes, update all future occurrences
                if task.repeatOption != .never {
                    updateAllFutureOccurrences(fromTaskId: id, updateField: "name", value: name)
                }
            }
            
            if let dueDate = dueDate {
                task.dueDate = dueDate
                
                // If due date changes, update all future occurrences
                if task.repeatOption != .never {
                    recalculateFutureDueDates(fromTaskId: id)
                }
            }
            
            if let isCompleted = isCompleted {
                task.isCompleted = isCompleted
                
                // If task is marked as completed and it's a repeating task,
                // ensure future occurrences exist
                if isCompleted != originalIsCompleted && isCompleted && task.repeatOption != .never {
                    let futureTasks = tasks.filter { $0.parentTaskId == task.id || $0.id == task.id }
                    let incompleteFutureTasks = futureTasks.filter { !$0.isCompleted }
                    
                    // If we don't have at least 3 incomplete future tasks, generate more
                    if incompleteFutureTasks.count < 3 {
                        let lastTask = incompleteFutureTasks.sorted(by: { $0.dueDate > $1.dueDate }).first ?? task
                        let additionalNeeded = 3 - incompleteFutureTasks.count
                        
                        // Generate additional occurrences based on the last one
                        var lastDate = lastTask.dueDate
                        for _ in 0..<additionalNeeded {
                            if let nextDate = calculateNextDueDate(from: lastDate, option: task.repeatOption) {
                                let newOccurrence = ChoreTask(
                                    name: task.name,
                                    dueDate: nextDate,
                                    isCompleted: false,
                                    assignedTo: task.assignedTo,
                                    notes: task.notes,
                                    repeatOption: task.repeatOption,
                                    parentTaskId: task.id
                                )
                                tasks.append(newOccurrence)
                                lastDate = nextDate
                            }
                        }
                    }
                }
            }
            
            if let assignedTo = assignedTo {
                task.assignedTo = assignedTo
                
                // If assignment changes, update all future occurrences
                if task.repeatOption != .never {
                    updateAllFutureOccurrences(fromTaskId: id, updateField: "assignedTo", value: assignedTo)
                }
            }
            
            if let notes = notes {
                task.notes = notes
                
                // If notes change, update all future occurrences
                if task.repeatOption != .never {
                    updateAllFutureOccurrences(fromTaskId: id, updateField: "notes", value: notes)
                }
            }
            
            if let repeatOption = repeatOption {
                let originalRepeatOption = task.repeatOption
                task.repeatOption = repeatOption
                
                // Handle change in repeat option
                if repeatOption != originalRepeatOption {
                    // If changed from non-repeating to repeating, generate future occurrences
                    if originalRepeatOption == .never && repeatOption != .never {
                        generateFutureOccurrences(for: task, count: 3)
                    }
                    
                    // If changed from repeating to non-repeating, remove future occurrences
                    if originalRepeatOption != .never && repeatOption == .never {
                        removeAllFutureOccurrences(fromTaskId: id)
                    }
                    
                    // If changed repeating frequency, recalculate future occurrences
                    if originalRepeatOption != .never && repeatOption != .never && originalRepeatOption != repeatOption {
                        recalculateFutureDueDates(fromTaskId: id)
                    }
                }
            }
            
            tasks[index] = task
        }
    }
    
    private func updateAllFutureOccurrences(fromTaskId id: UUID, updateField: String, value: Any) {
        let now = Date()
        
        for i in 0..<tasks.count {
            if tasks[i].parentTaskId == id && tasks[i].dueDate > now {
                // Only update future occurrences, not past ones
                switch updateField {
                case "name":
                    if let name = value as? String {
                        tasks[i].name = name
                    }
                case "assignedTo":
                    if let assignedTo = value as? UUID {
                        tasks[i].assignedTo = assignedTo
                    }
                case "notes":
                    if let notes = value as? String {
                        tasks[i].notes = notes
                    }
                default:
                    break
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
        generateFutureOccurrences(for: originalTask, count: 3)
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
            parentTaskId: task.id
        )
        
        tasks.append(newTask)
    }
    
    func deleteTask(id: UUID) {
        // Get the task before removing it
        if let task = tasks.first(where: { $0.id == id }) {
            // If this is a parent repeating task, also delete all its instances
            if task.repeatOption != .never && task.parentTaskId == nil {
                // Remove all child instances
                tasks.removeAll { $0.parentTaskId == id }
            }
            
            // Remove the task itself
            tasks.removeAll { $0.id == id }
        }
    }
    
    // Custom chores management
    func addCustomChore(_ choreName: String) {
        if !customChores.contains(choreName) {
            customChores.append(choreName)
            
            // Also add it as a task with a random assignment
            let randomUser = users.randomElement()
            addTask(
                name: choreName,
                dueDate: Date().addingTimeInterval(Double.random(in: 0...7) * 86400),
                assignedTo: randomUser?.id
            )
        }
    }
    
    // User management functions
    func addUser(name: String, color: String) {
        let newUser = User(name: name, avatarSystemName: "person.circle.fill", color: color)
        users.append(newUser)
    }
    
    func getUser(by id: UUID) -> User? {
        return users.first { $0.id == id }
    }
    
    func tasksAssignedTo(userId: UUID) -> [ChoreTask] {
        return tasks.filter { $0.assignedTo == userId }
    }
    
    // Calendar and schedule functions
    func getTasksForDay(date: Date) -> [ChoreTask] {
        let calendar = Calendar.current
        return tasks.filter { task in
            calendar.isDate(task.dueDate, inSameDayAs: date)
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
        
        // Make sure we have enough future instances of repeating tasks
        ensureRepeatingTasksExist(until: endDate)
        
        return tasks.filter { task in
            // Filter for tasks that are due after today but before the end date
            let taskDate = calendar.startOfDay(for: task.dueDate)
            return taskDate >= today && taskDate <= endDate && !task.isCompleted
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
                                parentTaskId: parentTask.id
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
} 