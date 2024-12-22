import Foundation

struct Chore: Identifiable {
    let id = UUID()
    var title: String
    var day: WeekDay
    var isCompleted: Bool
    var assignedTo: User?
    
    enum WeekDay: String, CaseIterable {
        case monday = "Mon"
        case tuesday = "Tue"
        case wednesday = "Wed"
        case thursday = "Thu"
        case friday = "Fri"
        case saturday = "Sat"
        case sunday = "Sun"
    }
} 