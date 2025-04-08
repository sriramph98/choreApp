import SwiftUI

struct HouseholdListView: View {
    @EnvironmentObject var choreViewModel: ChoreViewModel
    @State private var showingAddHouseholdSheet = false
    @State private var isLoading = false
    @AppStorage("hasSelectedHousehold") private var hasSelectedHousehold = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                if isLoading {
                    LoadingView()
                } else {
                    if choreViewModel.households.isEmpty {
                        EmptyHouseholdView(showingAddHouseholdSheet: $showingAddHouseholdSheet)
                    } else {
                        ScrollView {
                            VStack(spacing: 16) {
                                ForEach(choreViewModel.households) { household in
                                    HouseholdCard(household: household) {
                                        // Handle selection
                                        Task {
                                            isLoading = true
                                            await choreViewModel.switchToHousehold(household)
                                            isLoading = false
                                            hasSelectedHousehold = true
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 16)
                        }
                    }
                }
            }
            .navigationTitle("Households")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddHouseholdSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddHouseholdSheet) {
                CreateHouseholdView(isPresented: $showingAddHouseholdSheet)
            }
            .onAppear {
                loadHouseholds()
            }
        }
    }
    
    private func loadHouseholds() {
        Task {
            isLoading = true
            await choreViewModel.fetchHouseholds()
            
            // If we have a household in the view model but none from server,
            // let's create a default one for data migration
            if choreViewModel.households.isEmpty && choreViewModel.currentUser != nil {
                let _ = await choreViewModel.createDefaultHouseholdFromExistingData()
            }
            
            isLoading = false
        }
    }
}

struct HouseholdCard: View {
    let household: Household
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(household.name)
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text("Created \(household.createdAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(household.members.count) member\(household.members.count != 1 ? "s" : "")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.blue)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EmptyHouseholdView: View {
    @Binding var showingAddHouseholdSheet: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "house.circle")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("Welcome to Homie!")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Get started by creating your first household.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)
            
            Button {
                showingAddHouseholdSheet = true
            } label: {
                Text("Create Household")
                    .fontWeight(.medium)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
        }
        .padding()
    }
}

struct CreateHouseholdView: View {
    @EnvironmentObject var choreViewModel: ChoreViewModel
    @Binding var isPresented: Bool
    @State private var householdName = ""
    @State private var isCreating = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Household Details")) {
                    TextField("Household Name", text: $householdName)
                        .autocapitalization(.words)
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
                
                Section {
                    Button {
                        createHousehold()
                    } label: {
                        if isCreating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Create Household")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .disabled(isCreating || householdName.isEmpty)
                }
            }
            .navigationTitle("New Household")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    private func createHousehold() {
        guard !householdName.isEmpty else { return }
        
        errorMessage = nil
        isCreating = true
        
        Task {
            let success = await choreViewModel.createHousehold(name: householdName)
            
            await MainActor.run {
                isCreating = false
                
                if success {
                    isPresented = false
                } else {
                    errorMessage = "Failed to create household. Please try again."
                }
            }
        }
    }
}

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.5)
            
            Text("Loading...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
}

struct HouseholdMembersView: View {
    @EnvironmentObject var choreViewModel: ChoreViewModel
    let household: Household
    @State private var showingInviteSheet = false
    
    var body: some View {
        List {
            Section(header: Text("Members")) {
                ForEach(choreViewModel.users.filter { user in
                    household.members.contains(user.id)
                }) { user in
                    HStack {
                        UserInitialsView(user: user, size: 40)
                        VStack(alignment: .leading) {
                            Text(user.name)
                                .font(.headline)
                            
                            if user.id == household.creatorId {
                                Text("Owner")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        Spacer()
                        
                        // Number of assigned tasks
                        Text("\(choreViewModel.tasksAssignedTo(userId: user.id).count) tasks")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            
            Section {
                Button {
                    showingInviteSheet = true
                } label: {
                    Label("Invite Member", systemImage: "person.badge.plus")
                }
            }
        }
        .navigationTitle("Household Members")
        .sheet(isPresented: $showingInviteSheet) {
            InviteHouseholdMemberView(isPresented: $showingInviteSheet, household: household)
        }
    }
}

struct InviteHouseholdMemberView: View {
    @EnvironmentObject var choreViewModel: ChoreViewModel
    @Binding var isPresented: Bool
    let household: Household
    @State private var inviteEmail = ""
    @State private var isInviting = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Invite by Email")) {
                    TextField("Email Address", text: $inviteEmail)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled(true)
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
                
                if let successMessage = successMessage {
                    Section {
                        Text(successMessage)
                            .foregroundColor(.green)
                    }
                }
                
                Section {
                    Button {
                        inviteMember()
                    } label: {
                        if isInviting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Send Invitation")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .disabled(isInviting || inviteEmail.isEmpty)
                }
                
                Section(header: Text("Or Add Existing Person")) {
                    ForEach(choreViewModel.users.filter { user in
                        !household.members.contains(user.id)
                    }) { user in
                        Button {
                            addExistingUser(user)
                        } label: {
                            HStack {
                                UserInitialsView(user: user, size: 30)
                                Text(user.name)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Invite to Household")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    private func inviteMember() {
        guard !inviteEmail.isEmpty else { return }
        
        errorMessage = nil
        successMessage = nil
        isInviting = true
        
        // In a real app, this would send an invitation email
        // For now, we'll just simulate success
        Task {
            // Simulate network delay
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            await MainActor.run {
                isInviting = false
                successMessage = "Invitation sent to \(inviteEmail)"
                inviteEmail = ""
            }
        }
    }
    
    private func addExistingUser(_ user: User) {
        Task {
            isInviting = true
            
            let success = await choreViewModel.addUserToHousehold(
                userId: user.id,
                householdId: household.id
            )
            
            await MainActor.run {
                isInviting = false
                
                if success {
                    // Refresh households to update members
                    Task {
                        await choreViewModel.fetchHouseholds()
                        isPresented = false
                    }
                } else {
                    errorMessage = "Failed to add user to household."
                }
            }
        }
    }
}

#Preview {
    HouseholdListView()
        .environmentObject(ChoreViewModel())
} 