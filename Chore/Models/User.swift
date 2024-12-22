import Foundation

struct User: Identifiable {
    let id = UUID()
    var name: String
    var avatarSystemName: String
    var color: String // Store as a string to make it easier to persist
    
    static let sampleUsers = [
        User(name: "You", avatarSystemName: "person.circle.fill", color: "blue"),
        User(name: "John", avatarSystemName: "person.circle.fill", color: "green"),
        User(name: "Sarah", avatarSystemName: "person.circle.fill", color: "purple")
    ]
} 