import SwiftUI
import Combine

struct ConversationView: View {
    let chatUser: User
    @State private var messageText = ""
    @State private var messages: [Message] = []
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    private let networkService = NetworkService.shared
    
    // ✅ Таймер через Timer.publish (работает со SwiftUI)
    @State private var timer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack {
            // Индикатор загрузки (только при первом входе)
            if isLoading && messages.isEmpty {
                VStack {
                    ProgressView()
                    Text("Загрузка сообщений...")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
                .padding()
            }
            
            // Список сообщений
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
                .onAppear {
                    loadMessages()
                }
                .onReceive(timer) { _ in
                    loadMessages()
                }
                .onChange(of: messages.count) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
            }
            
            Divider()
            
            // Поле ввода сообщения
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
            }
            .padding()
        }
        .navigationTitle(chatUser.name)
        .alert("Ошибка", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Прокрутка
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastMessage = messages.last {
            withAnimation {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
    
    // MARK: - Отправка сообщения
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        isLoading = true
        let text = messageText
        messageText = ""
        
        networkService.sendMessage(to: chatUser.username, text: text) { result in
            isLoading = false
            switch result {
            case .success(let message):
                // Добавляем сообщение сразу, не ждём опроса
                if !messages.contains(where: { $0.id == message.id }) {
                    messages.append(message)
                }
            case .failure(let error):
                errorMessage = error.localizedDescription
                showError = true
                messageText = text // Возвращаем текст при ошибке
            }
        }
    }
    
    // MARK: - Загрузка истории
    
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
                    // 🔔 Проверка на НОВЫЕ сообщения от собеседника
                    if sortedMessages.count > self.messages.count {
                        let newMessages = sortedMessages.filter { msg in
                            msg.from != current.username &&
                            !self.messages.contains(where: { $0.id == msg.id })
                        }
                        
                        // Показать уведомление для каждого нового сообщения
                        for msg in newMessages {
                            NotificationService.shared.showMessageNotification(
                                from: self.chatUser.name,
                                text: msg.text,
                                chatId: self.chatUser.username
                            )
                        }
                    }
                    
                    // ✅ ИСПРАВЛЕННОЕ СРАВНЕНИЕ (без Equatable)
                    if sortedMessages.count != self.messages.count ||
                       sortedMessages.last?.id != self.messages.last?.id {
                        self.messages = sortedMessages
                    }
                    self.isLoading = false
                }
            case .failure(let error):
                self.errorMessage = error.localizedDescription
                self.showError = true
                self.isLoading = false
            }
        }
    }
}
