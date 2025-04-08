import SwiftUI

struct ChoreCalendarView: View {
    @EnvironmentObject var choreViewModel: ChoreViewModel
    @State private var selectedDate = Date()
    @State private var weekStart: Date = Date()
    @State private var showingDatePicker = false
    @State private var pickerDate = Date()
    @State private var selectedTask: ChoreViewModel.ChoreTask?
    
    let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            // Compact weekly calendar
            VStack {
                HStack {
                    Button(action: {
                        if let newDate = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: weekStart) {
                            weekStart = newDate
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    Text(monthFormatter.string(from: weekStart))
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(action: {
                        if let newDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: weekStart) {
                            weekStart = newDate
                        }
                    }) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal)
                
                HStack(spacing: 0) {
                    ForEach(getWeekDates(), id: \.self) { date in
                        Button(action: {
                            selectedDate = date
                        }) {
                            VStack {
                                Text(weekdays[Calendar.current.component(.weekday, from: date) - 1])
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("\(Calendar.current.component(.day, from: date))")
                                    .font(.system(size: 18, weight: .medium))
                                
                                // Indicator for selected date
                                if Calendar.current.isDate(date, inSameDayAs: selectedDate) {
                                    Circle()
                                        .fill(Color.blue)
                                        .frame(width: 6, height: 6)
                                } else {
                                    Circle()
                                        .fill(Color.clear)
                                        .frame(width: 6, height: 6)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Calendar.current.isDate(date, inSameDayAs: selectedDate) ? Color.blue.opacity(0.1) : Color.clear)
                            )
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
            .padding(.bottom)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            .padding(.horizontal)
            
            // Tasks list for selected date
            ScrollView {
                VStack(spacing: 16) {
                    let tasksForDay = choreViewModel.getTasksForDay(date: selectedDate)
                    
                    if tasksForDay.isEmpty {
                        Text("No tasks scheduled for this day")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        ForEach(tasksForDay) { task in
                            Button {
                                // Just set the selected task, the sheet will appear automatically
                                selectedTask = task
                            } label: {
                                HStack(spacing: 8) {
                                    // Left side: Task name
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(task.name)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                            .strikethrough(task.isCompleted, color: .gray)
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                            
                                        // Show repeat frequency text
                                        if task.repeatOption != .never {
                                            Text(repeatFrequencyText(task.repeatOption))
                                                .font(.caption2)
                                                .foregroundColor(.blue)
                                                .lineLimit(1)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    // Right side: Assigned person with fixed width
                                    if let assignedToId = task.assignedTo, 
                                       let user = choreViewModel.getUser(by: assignedToId) {
                                        HStack(spacing: 4) {
                                            UserInitialsView(user: user, size: 20)
                                                .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                                            Text(user.name)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                                .truncationMode(.tail)
                                        }
                                        .fixedSize(horizontal: true, vertical: false)
                                    }
                                }
                                .padding()
                                .background(Material.regularMaterial.opacity(task.isCompleted ? 0.7 : 1))
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical, 16)
            }
        }
        .onAppear {
            initializeWeekStart()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    // Only show Today button when today is not selected
                    if !Calendar.current.isDateInToday(selectedDate) {
                        Button {
                            goToToday()
                        } label: {
                            Text("Today")
                        }
                    }
                    
                    DatePicker("", selection: $pickerDate, displayedComponents: [.date])
                        .labelsHidden()
                        .onChange(of: pickerDate) { oldValue, newDate in
                            navigateToDate(newDate)
                        }
                }
            }
        }
        // Task detail sheet
        .sheet(item: $selectedTask) { task in
            TaskDetailView(task: task, onDismiss: {
                selectedTask = nil
                // Ensure view model is updated after sheet closes
                DispatchQueue.main.async {
                    choreViewModel.objectWillChange.send()
                }
            })
            .environmentObject(choreViewModel)
        }
    }
    
    private func initializeWeekStart() {
        let calendar = Calendar.current
        weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
    }
    
    private func getWeekDates() -> [Date] {
        let calendar = Calendar.current
        var weekDates: [Date] = []
        
        for dayOffset in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) {
                weekDates.append(date)
            }
        }
        
        return weekDates
    }
    
    private func goToToday() {
        let today = Date()
        navigateToDate(today)
    }
    
    private func navigateToDate(_ date: Date) {
        let calendar = Calendar.current
        
        // Update the selected date
        selectedDate = date
        
        // Find the start of the week containing the selected date
        weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)) ?? date
    }
    
    // Helper to display repeat frequency
    private func repeatFrequencyText(_ option: ChoreViewModel.RepeatOption) -> String {
        switch option {
        case .daily:
            return "Daily"
        case .weekly:
            return "Weekly"
        case .monthly:
            return "Monthly"
        case .yearly:
            return "Yearly"
        case .never:
            return ""
        }
    }
}

#Preview {
    ChoreCalendarView()
        .environmentObject(ChoreViewModel())
} 