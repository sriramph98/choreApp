import Foundation
import SwiftUI

struct User: Identifiable, Codable {
    var id: UUID
    var name: String
    var avatarSystemName: String // System SF Symbol name
    var color: String
    
    // Will be used for UI
    var uiColor: Color {
        Color.colorFromString(color)
    }
    
    static var sampleUsers: [User] = [
        User(id: UUID(), name: "You", avatarSystemName: "person.circle.fill", color: "blue"),
        User(id: UUID(), name: "Partner", avatarSystemName: "person.circle.fill", color: "green"),
        User(id: UUID(), name: "Roommate", avatarSystemName: "person.circle.fill", color: "red")
    ]
}

struct Household: Identifiable, Codable {
    var id: UUID
    var name: String
    var creatorId: UUID
    var members: [UUID]
    var createdAt: Date
    
    init(id: UUID = UUID(), name: String, creatorId: UUID, members: [UUID] = [], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.creatorId = creatorId
        self.members = members
        self.createdAt = createdAt
    }
}