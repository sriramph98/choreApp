import SwiftUI

struct ChoreCalendarView: View {
    @EnvironmentObject var choreViewModel: ChoreViewModel
    @State private var selectedDate = Date()
    @State private var weekStart: Date = Date()
    
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
            List {
                let tasksForDay = choreViewModel.getTasksForDay(date: selectedDate)
                
                if tasksForDay.isEmpty {
                    Text("No tasks scheduled for this day")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    ForEach(tasksForDay) { task in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(task.name)
                                    .font(.headline)
                                
                                if let notes = task.notes, !notes.isEmpty {
                                    Text(notes)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            
                            Spacer()
                            
                            // Display assigned person
                            if let assignedToId = task.assignedTo, 
                               let user = choreViewModel.getUser(by: assignedToId) {
                                UserInitialsView(user: user)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(PlainListStyle())
        }
        .onAppear {
            initializeWeekStart()
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
}

#Preview {
    ChoreCalendarView()
        .environmentObject(ChoreViewModel())
} 