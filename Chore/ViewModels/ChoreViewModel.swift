import Foundation

class ChoreViewModel: ObservableObject {
    @Published var tasks: [ChoreTask] = []
    @Published var assignments: [ChoreAssignment] = []
    
    struct ChoreTask: Identifiable {
        let id = UUID()
        let name: String
        let dueDate: Date
        var isCompleted: Bool
        var assignedTo: String?
    }
    
    struct ChoreAssignment {
        let taskId: UUID
        let assignedTo: String
        let completedAt: Date?
    }
    
    // Sample data - replace with actual data source later
    init() {
        // Add some sample tasks
        tasks = [
            ChoreTask(name: "Dishes", dueDate: Date(), isCompleted: false, assignedTo: "Alex"),
            ChoreTask(name: "Laundry", dueDate: Date().addingTimeInterval(86400), isCompleted: false, assignedTo: "Sarah"),
            ChoreTask(name: "Vacuum", dueDate: Date().addingTimeInterval(172800), isCompleted: false, assignedTo: "Mike")
        ]
    }
    
    func getTasksForToday() -> [ChoreTask] {
        let calendar = Calendar.current
        return tasks.filter { task in
            calendar.isDate(task.dueDate, inSameDayAs: Date())
        }
    }
    
    func getUpcomingTasks() -> [ChoreTask] {
        let today = Date()
        return tasks.filter { $0.dueDate > today }
            .sorted { $0.dueDate < $1.dueDate }
    }
    
    func getAssignedPerson(for task: String) -> String? {
        return tasks.first { $0.name.lowercased() == task.lowercased() }?.assignedTo
    }
} 