import SwiftUI

struct ChoreCalendarView: View {
    @State private var selectedDay: Chore.WeekDay = .monday
    @State private var chores: [Chore] = [
        // Update sample chores with assigned users
        Chore(title: "Clean Kitchen", day: .monday, isCompleted: false, assignedTo: User.sampleUsers[0]),
        Chore(title: "Vacuum Living Room", day: .monday, isCompleted: true, assignedTo: User.sampleUsers[1]),
        Chore(title: "Do Laundry", day: .wednesday, isCompleted: false, assignedTo: User.sampleUsers[2]),
        Chore(title: "Water Plants", day: .friday, isCompleted: false, assignedTo: User.sampleUsers[0])
    ]
    @State private var users: [User] = User.sampleUsers
    @State private var showingUserManagement = false
    @State private var showingChoreForm = false
    @State private var choreToEdit: Chore?
    
    var body: some View {
        VStack(spacing: 20) {
            // Week day selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Chore.WeekDay.allCases, id: \.self) { day in
                        DayButton(day: day, isSelected: selectedDay == day) {
                            selectedDay = day
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            // Users ScrollView
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(users) { user in
                        UserAvatar(user: user)
                    }
                    
                    Button {
                        showingUserManagement = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal)
            }
            
            // Chores for selected day
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Text(selectedDay.rawValue.uppercased())
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Button {
                        showingChoreForm = true
                    } label: {
                        Image(systemName: "plus.circle")
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal)
                
                if choresByDay.isEmpty {
                    Text("No chores for this day")
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    ForEach(choresByDay) { chore in
                        ChoreRow(
                            chore: chore,
                            onToggle: { isCompleted in
                                if let index = chores.firstIndex(where: { $0.id == chore.id }) {
                                    chores[index].isCompleted = isCompleted
                                }
                            },
                            onEdit: {
                                choreToEdit = chore
                            }
                        )
                    }
                }
            }
            
            Spacer()
            
            // Add chore button
            Button {
                // TODO: Implement add chore functionality
            } label: {
                Label("Add Chore", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding()
        }
        .sheet(isPresented: $showingUserManagement) {
            UserManagementView(users: $users)
        }
        .sheet(isPresented: $showingChoreForm) {
            ChoreFormView(chores: $chores, users: users)
        }
        .sheet(item: $choreToEdit) { chore in
            ChoreFormView(chores: $chores, users: users, existingChore: chore)
        }
    }
    
    private var choresByDay: [Chore] {
        chores.filter { $0.day == selectedDay }
    }
}

struct DayButton: View {
    let day: Chore.WeekDay
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(day.rawValue)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(isSelected ? Color.blue : Color.clear)
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(8)
        }
    }
}

struct UserAvatar: View {
    let user: User
    
    var body: some View {
        VStack {
            Image(systemName: user.avatarSystemName)
                .font(.title2)
                .foregroundColor(Color(user.color))
            Text(user.name)
                .font(.caption)
        }
    }
}

// Update ChoreRow to show assigned user more prominently
struct ChoreRow: View {
    let chore: Chore
    let onToggle: (Bool) -> Void
    var onEdit: () -> Void
    
    var body: some View {
        HStack {
            Toggle("", isOn: Binding(
                get: { chore.isCompleted },
                set: { onToggle($0) }
            ))
            .labelsHidden()
            
            VStack(alignment: .leading) {
                Text(chore.title)
                    .strikethrough(chore.isCompleted)
                    .foregroundColor(chore.isCompleted ? .gray : .primary)
                
                if let user = chore.assignedTo {
                    HStack {
                        Image(systemName: user.avatarSystemName)
                            .foregroundColor(Color(user.color))
                        Text(user.name)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            Spacer()
            
            Button {
                onEdit()
            } label: {
                Image(systemName: "pencil.circle")
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal)
        .contentShape(Rectangle())
    }
} 