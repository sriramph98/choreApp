import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var choreViewModel: ChoreViewModel
    @State private var currentStep = 0
    @State private var showAddPersonSheet = false
    @State private var showAddChoreSheet = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    // Common chores that will be used in both the main view and AddChoresView
    let commonChores = [
        "Dishes", "Laundry", "Vacuum", "Take Out Trash", 
        "Clean Bathroom", "Mop Floors", "Yard Work", "Groceries"
    ]
    
    var body: some View {
        VStack {
            // Header with progress
            HStack {
                Text(currentStep == 0 ? "Add People" : "Add Chores")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text("\(currentStep + 1)/2")
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            .padding()
            
            if currentStep == 0 {
                AddPeopleView(showAddPersonSheet: $showAddPersonSheet)
            } else {
                AddChoresView(showAddChoreSheet: $showAddChoreSheet, commonChores: commonChores)
            }
            
            // Bottom navigation
            HStack {
                if currentStep > 0 {
                    Button {
                        withAnimation {
                            currentStep -= 1
                        }
                    } label: {
                        Text("Back")
                            .frame(width: UIScreen.main.bounds.width * 0.25 - 20)
                            .padding()
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .cornerRadius(10)
                    }
                }
                
                if currentStep == 0 {
                    Button {
                        withAnimation {
                            currentStep += 1
                        }
                    } label: {
                        Text("Next")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(choreViewModel.users.count < 2 ? Color.gray.opacity(0.5) : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(choreViewModel.users.count < 2)
                } else {
                    Button {
                        hasCompletedOnboarding = true
                    } label: {
                        Text("Start Using App")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(choreViewModel.tasks.isEmpty ? Color.gray.opacity(0.5) : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(choreViewModel.tasks.isEmpty)
                }
            }
            .padding()
        }
        .sheet(isPresented: $showAddPersonSheet) {
            AddPersonSheetView(isPresented: $showAddPersonSheet)
        }
        .sheet(isPresented: $showAddChoreSheet) {
            AddChoreSheetView(isPresented: $showAddChoreSheet, onAddChore: { choreName in
                // Add to custom chores if not already in common chores
                if !commonChores.contains(choreName) && !choreViewModel.customChores.contains(choreName) {
                    choreViewModel.addCustomChore(choreName)
                }
            })
        }
        .onAppear {
            // Add the current user
            if choreViewModel.users.isEmpty {
                let username = ProcessInfo.processInfo.fullUserName
                choreViewModel.addUser(name: username.isEmpty ? "You" : username, color: "blue")
            }
        }
    }
    
    // View for the first step: adding people
    struct AddPeopleView: View {
        @EnvironmentObject var choreViewModel: ChoreViewModel
        @Binding var showAddPersonSheet: Bool
        
        var body: some View {
            VStack(spacing: 20) {
                Text("Who will be doing chores?")
                    .font(.headline)
                
                // Add Person button at the top
                Button {
                    showAddPersonSheet = true
                } label: {
                    HStack {
                        Image(systemName: "person.badge.plus")
                        Text("Add Person")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                
                // Separator
                Divider()
                    .padding(.vertical, 8)
                
                // Show existing people
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(choreViewModel.users) { user in
                            HStack {
                                UserInitialsView(user: user, size: 40)
                                
                                Text(user.name)
                                    .font(.headline)
                                
                                Spacer()
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                    }
                    .padding()
                }
                
                if choreViewModel.users.count < 2 {
                    Text("Add at least 2 people to continue")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // View for the second step: adding chores
    struct AddChoresView: View {
        @EnvironmentObject var choreViewModel: ChoreViewModel
        @Binding var showAddChoreSheet: Bool
        @State private var selectedChores: [String] = []
        
        let commonChores: [String]
        
        var body: some View {
            VStack(spacing: 20) {
                Text("What chores need to be done?")
                    .font(.headline)
                
                // Selected chores at top as chips
                VStack(alignment: .leading) {
                    Text("Your Chores")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    if selectedChores.isEmpty {
                        Text("Tap chores below to add them")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(selectedChores, id: \.self) { chore in
                                    ChoreChip(
                                        title: chore,
                                        isSelected: true,
                                        action: {
                                            // Remove from selected chores
                                            selectedChores.removeAll { $0 == chore }
                                            
                                            // Remove from tasks
                                            if let taskToRemove = choreViewModel.tasks.first(where: { $0.name == chore }) {
                                                choreViewModel.deleteTask(id: taskToRemove.id)
                                            }
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                        }
                    }
                }
                
                Divider()
                    .padding(.vertical, 8)
                
                // Common chores as chips
                VStack(alignment: .leading) {
                    Text("Preset Chores")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    // Add Custom Chore button moved above the chips
                    Button {
                        showAddChoreSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Add Custom Chore")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 10) {
                            // Show all common chores
                            ForEach(commonChores + choreViewModel.customChores, id: \.self) { chore in
                                if !selectedChores.contains(chore) {
                                    ChoreChip(
                                        title: chore,
                                        isSelected: false,
                                        action: {
                                            // Add to selected chores
                                            selectedChores.append(chore)
                                            
                                            // Add to view model with a random assignment
                                            if !choreViewModel.tasks.contains(where: { $0.name == chore }) {
                                                let randomUser = choreViewModel.users.randomElement()
                                                _ = choreViewModel.addTask(
                                                    name: chore,
                                                    dueDate: Date().addingTimeInterval(Double.random(in: 0...7) * 86400),
                                                    assignedTo: randomUser?.id
                                                )
                                            }
                                        }
                                    )
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .onAppear {
                // Synchronize selectedChores with the tasks from the view model
                selectedChores = choreViewModel.tasks.map { $0.name }
            }
        }
    }
}

struct ChoreChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.blue.opacity(0.2) : Color(.systemGray6))
                )
                .foregroundColor(isSelected ? .blue : .primary)
        }
    }
}

// Helper for getting the user's name
extension ProcessInfo {
    var fullUserName: String {
        return NSFullUserName()
    }
}

struct AddPersonSheetView: View {
    @EnvironmentObject var choreViewModel: ChoreViewModel
    @Binding var isPresented: Bool
    @State private var name = ""
    @State private var selectedColor = "blue"
    
    let colors = ["blue", "green", "red", "purple", "orange", "pink"]
    
    var body: some View {
        NavigationStack {
            VStack {
                // Avatar placeholder (in a real app, would allow image selection)
                ZStack {
                    Circle()
                        .fill(Color(selectedColor))
                        .frame(width: 120, height: 120)
                    
                    Text(name.prefix(2).uppercased())
                        .font(.system(size: 40))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .padding(.top, 30)
                
                // Color selection
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(colors, id: \.self) { color in
                            Circle()
                                .fill(Color(color))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: selectedColor == color ? 3 : 0)
                                        .padding(2)
                                )
                                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                                .onTapGesture {
                                    selectedColor = color
                                }
                        }
                    }
                    .padding()
                }
                
                // Name field
                TextField("Name", text: $name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                // Add button
                Button {
                    if !name.isEmpty {
                        choreViewModel.addUser(name: name, color: selectedColor)
                        isPresented = false
                    }
                } label: {
                    Text("Add Person")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(name.isEmpty ? Color.gray.opacity(0.5) : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(name.isEmpty)
                
                Spacer()
            }
            .navigationTitle("Welcome to Homie")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

struct AddChoreSheetView: View {
    @EnvironmentObject var choreViewModel: ChoreViewModel
    @Binding var isPresented: Bool
    @State private var choreName = ""
    @State private var selectedUserId: UUID?
    @State private var dueDate = Date()
    @State private var repeatOption = ChoreViewModel.RepeatOption.never
    let onAddChore: (String) -> Void
    var title: String = "Add Custom Chore"
    var buttonText: String = "Add Chore"
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Chore Details")) {
                    TextField("Chore Name", text: $choreName)
                    
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date])
                    
                    Picker("Repeat", selection: $repeatOption) {
                        Text("Never").tag(ChoreViewModel.RepeatOption.never)
                        Text("Every Day").tag(ChoreViewModel.RepeatOption.daily)
                        Text("Every Week").tag(ChoreViewModel.RepeatOption.weekly)
                        Text("Every Month").tag(ChoreViewModel.RepeatOption.monthly)
                        Text("Every Year").tag(ChoreViewModel.RepeatOption.yearly)
                    }
                }
                
                Section(header: Text("Assign To")) {
                    ForEach(choreViewModel.users) { user in
                        HStack {
                            UserInitialsView(user: user, size: 30)
                            Text(user.name)
                            Spacer()
                            if selectedUserId == user.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedUserId = user.id
                        }
                    }
                }
            }
            .navigationTitle("Welcome to Homie")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if !choreName.isEmpty {
                            // Call the provided callback with the chore name
                            onAddChore(choreName)
                            
                            // Also add it as a task with the selected assignment
                            _ = choreViewModel.addTask(
                                name: choreName,
                                dueDate: dueDate,
                                assignedTo: selectedUserId,
                                repeatOption: repeatOption
                            )
                            
                            isPresented = false
                        }
                    }
                    .disabled(choreName.isEmpty)
                }
            }
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(ChoreViewModel())
} 