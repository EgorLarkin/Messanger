import SwiftUI
import Combine

struct ConversationView: View {
    let chatUser: User
    @State private var messageText = ""
    @State private var messages: [Message] = []
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var timer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()
    
    private let networkService = NetworkService.shared
    
    var body: some View {
        VStack {
            if isLoading && messages.isEmpty {
                VStack {
                    ProgressView()
                    Text("Загрузка сообщений...")
                        .foregroundColor(.gray)
                        .font(.caption)
                }.padding()
            }
            
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(messages) { message in
                            MessageBubble(message: message, sender: chatUser)
                                .id(message.id)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
                .onAppear {
                    loadMessages()
                    scrollToBottom(proxy: proxy)
                }
                .onReceive(timer) { _ in
                    loadMessages()
                }
                .onChange(of: messages.count) { _ in
                    scrollToBottom(proxy: proxy)
                }
            }
            
            Divider()
            
            HStack {
                TextField("Сообщение", text: $messageText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(isLoading)
                    .onSubmit { sendMessage() }
                
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .font(.title2)
                        .foregroundColor(messageText.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .blue)
                }
                .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
            }.padding()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    AvatarView(user: chatUser, size: 32)
                    Text(chatUser.name)
                        .font(.headline)
                }
            }
        }
        .alert("Ошибка", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: { Text(errorMessage) }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastMessage = messages.last {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
        }
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isLoading = true
        let text = messageText
        messageText = ""
        
        networkService.sendMessage(to: chatUser.username, text: text) { result in
            isLoading = false
            switch result {
            case .success(let message):
                if !messages.contains(where: { $0.id == message.id }) {
                    messages.append(message)
                }
            case .failure(let error):
                errorMessage = error.localizedDescription
                showError = true
                messageText = text
            }
        }
    }
    
    private func loadMessages() {
        guard let current = AuthManager.shared.currentUser else {
            isLoading = false
            return
        }
        
        networkService.fetchHistory(user1: current.username, user2: chatUser.username) { result in
            switch result {
            case .success(let fetched):
                let sortedMessages = fetched.sorted { $0.date < $1.date }
                
                DispatchQueue.main.async {
                    if sortedMessages.count > messages.count {
                        let newMessages = sortedMessages.filter { msg in
                            msg.from != current.username && !messages.contains(where: { $0.id == msg.id })
                        }
                        for msg in newMessages {
                            NotificationService.shared.showMessageNotification(
                                from: chatUser.name,
                                text: msg.text,
                                chatId: chatUser.username
                            )
                        }
                    }
                    if sortedMessages.count != messages.count || sortedMessages.last?.id != messages.last?.id {
                        messages = sortedMessages
                    }
                }
            case .failure(let error):
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}
