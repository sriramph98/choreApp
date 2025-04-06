import Foundation

class ChoreViewModel: ObservableObject {
    @Published var tasks: [ChoreTask] = []
    @Published var users: [User] = []
    @Published var customChores: [String] = []
    
    struct ChoreTask: Identifiable {
        let id = UUID()
        var name: String
        var dueDate: Date
        var isCompleted: Bool
        var assignedTo: UUID?
        var notes: String?
    }
    
    // Sample data - replace with actual data source later
    init() {
        // Add some sample users
        users = User.sampleUsers
        
        // Add some sample tasks
        tasks = [
            ChoreTask(name: "Dishes", dueDate: Date(), isCompleted: false, assignedTo: users[1].id),
            ChoreTask(name: "Laundry", dueDate: Date().addingTimeInterval(86400), isCompleted: false, assignedTo: users[2].id),
            ChoreTask(name: "Vacuum", dueDate: Date().addingTimeInterval(172800), isCompleted: false, assignedTo: users[0].id)
        ]
    }
    
    // Task management functions
    func addTask(name: String, dueDate: Date, assignedTo: UUID?, notes: String? = nil) {
        let newTask = ChoreTask(name: name, dueDate: dueDate, isCompleted: false, assignedTo: assignedTo, notes: notes)
        tasks.append(newTask)
    }
    
    func updateTask(id: UUID, name: String?, dueDate: Date?, isCompleted: Bool?, assignedTo: UUID?, notes: String?) {
        if let index = tasks.firstIndex(where: { $0.id == id }) {
            var task = tasks[index]
            
            if let name = name {
                task.name = name
            }
            
            if let dueDate = dueDate {
                task.dueDate = dueDate
            }
            
            if let isCompleted = isCompleted {
                task.isCompleted = isCompleted
            }
            
            if let assignedTo = assignedTo {
                task.assignedTo = assignedTo
            }
            
            if let notes = notes {
                task.notes = notes
            }
            
            tasks[index] = task
        }
    }
    
    func deleteTask(id: UUID) {
        tasks.removeAll { $0.id == id }
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
    
    func getUpcomingTasks() -> [ChoreTask] {
        let today = Date()
        return tasks.filter { $0.dueDate > today }
            .sorted { $0.dueDate < $1.dueDate }
    }
} 