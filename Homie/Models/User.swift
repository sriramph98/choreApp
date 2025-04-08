import Foundation
import SwiftUI

struct User: Identifiable, Codable {
    var id: UUID
    var name: String
    var avatarSystemName: String
    var color: String // Store as a string to make it easier to persist
    
    // Computed property to get SwiftUI Color from string
    var uiColor: Color {
        switch color.lowercased() {
        case "red":
            return .red
        case "blue":
            return .blue
        case "green":
            return .green
        case "orange":
            return .orange
        case "purple":
            return .purple
        case "pink":
            return .pink
        default:
            return .blue
        }
    }
    
    init(id: UUID = UUID(), name: String, avatarSystemName: String, color: String) {
        self.id = id
        self.name = name
        self.avatarSystemName = avatarSystemName
        self.color = color
    }
    
    static let sampleUsers = [
        User(name: "You", avatarSystemName: "person.circle.fill", color: "blue"),
        User(name: "John", avatarSystemName: "person.circle.fill", color: "green"),
        User(name: "Sarah", avatarSystemName: "person.circle.fill", color: "purple")
    ]
} 