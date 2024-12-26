import SwiftUI

struct ChatView: View {
    @State private var userInput = ""
    @State private var chatHistory: [ChatMessage] = []
    @EnvironmentObject var choreViewModel: ChoreViewModel
    @FocusState private var isFocused: Bool
    @State private var isTyping = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Chat messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(chatHistory) { message in
                                MessageBubble(message: message)
                            }
                            if isTyping {
                                TypingBubble()
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                    .onChange(of: chatHistory.count) { oldCount, newCount in
                        withAnimation {
                            proxy.scrollTo(chatHistory.last?.id, anchor: .bottom)
                        }
                    }
                }
                
                Divider()
                
                // Message input
                HStack(alignment: .bottom) {
                    TextField("Message", text: $userInput, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .focused($isFocused)
                        .lineLimit(1...5)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(userInput.isEmpty ? Color(.systemGray) : Color(.systemBlue))
                    }
                    .disabled(userInput.isEmpty)
                    .padding(.trailing)
                    .padding(.bottom, 8)
                }
                .background(Color(.systemBackground))
            }
            .navigationTitle("Homie")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            addWelcomeMessage()
        }
    }
    
    private func addWelcomeMessage() {
        let welcomeMessage = ChatMessage(
            content: "Hi! I'm Homie, your chore assistant. How can I help you today?",
            isUser: false,
            timestamp: Date()
        )
        chatHistory.append(welcomeMessage)
    }
    
    private func sendMessage() {
        guard !userInput.isEmpty else { return }
        
        let userMessage = ChatMessage(
            content: userInput,
            isUser: true,
            timestamp: Date()
        )
        chatHistory.append(userMessage)
        let currentInput = userInput
        userInput = ""
        
        isTyping = true
        
        // Simulate AI thinking delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isTyping = false
            let response = processQuery(currentInput)
            let assistantMessage = ChatMessage(
                content: response,
                isUser: false,
                timestamp: Date()
            )
            chatHistory.append(assistantMessage)
        }
    }
    
    private func processQuery(_ query: String) -> String {
        let lowercasedQuery = query.lowercased()
        
        if lowercasedQuery.contains("who") && lowercasedQuery.contains("did") {
            if lowercasedQuery.contains("dishes") {
                return checkTaskCompletion(task: "dishes")
            } else if lowercasedQuery.contains("laundry") {
                return checkTaskCompletion(task: "laundry")
            } else if lowercasedQuery.contains("vacuum") {
                return checkTaskCompletion(task: "vacuum")
            }
        }
        
        if lowercasedQuery.contains("next") || lowercasedQuery.contains("upcoming") {
            return getUpcomingTasks()
        }
        
        if lowercasedQuery.contains("today") {
            return getTodaysTasks()
        }
        
        return """
            I can help you with:
            • Checking who did specific chores
            • Viewing today's tasks
            • Checking upcoming chores
            • Finding out who's responsible for what
            
            Just ask me what you'd like to know!
            """
    }
    
    private func checkTaskCompletion(task: String) -> String {
        // TODO: Integrate with ChoreViewModel
        return "Let me check... According to the records, Sarah completed the \(task) at 2:30 PM today! 🎉"
    }
    
    private func getUpcomingTasks() -> String {
        // TODO: Integrate with ChoreViewModel
        return "Here are the upcoming tasks:\n• Kitchen cleaning (Tomorrow)\n• Laundry (Wednesday)\n• Vacuum (Thursday)"
    }
    
    private func getTodaysTasks() -> String {
        // TODO: Integrate with ChoreViewModel
        return "Today's tasks:\n• Dishes (Assigned to Alex)\n• Take out trash (Assigned to Sarah)\n• Wipe counters (Assigned to Mike)"
    }
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date
}

struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .bottom) {
            if message.isUser { Spacer(minLength: 60) }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 2) {
                Text(message.content)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(message.isUser ? Color(.systemBlue) : Color(.systemGray5))
                    .foregroundColor(message.isUser ? .white : Color(.label))
                    .clipShape(MessageBubbleShape(isUser: message.isUser))
                
                Text(formatTime(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
            
            if !message.isUser { Spacer(minLength: 60) }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct TypingBubble: View {
    @State private var dotsOpacity: [Double] = [1, 1, 1]
    
    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .frame(width: 6, height: 6)
                        .opacity(dotsOpacity[index])
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray5))
            .clipShape(MessageBubbleShape(isUser: false))
            
            Spacer(minLength: 60)
        }
        .onAppear {
            animateDots()
        }
    }
    
    private func animateDots() {
        let animation = Animation
            .easeInOut(duration: 0.4)
            .repeatForever(autoreverses: true)
        
        for i in 0..<3 {
            withAnimation(animation.delay(Double(i) * 0.2)) {
                dotsOpacity[i] = 0.3
            }
        }
    }
}

struct MessageBubbleShape: Shape {
    let isUser: Bool
    
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 16
        var path = Path()
        
        let corners: UIRectCorner = [
            .topLeft,
            .topRight,
            isUser ? .bottomLeft : .bottomRight
        ]
        
        let cornerRadii = CGSize(width: radius, height: radius)
        path = Path(UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: cornerRadii
        ).cgPath)
        
        return path
    }
}

#if DEBUG
struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        ChatView()
            .environmentObject(ChoreViewModel())
    }
}
#endif

#Preview {
    ChatView()
} 