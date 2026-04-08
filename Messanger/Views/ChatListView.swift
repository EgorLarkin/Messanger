import SwiftUI
import Combine

struct ChatListView: View {
    @State private var conversations: [Conversation] = []
    @State private var showingSearch = false
    @State private var isLoading = false
    @State private var selectedUserForNavigation: User?
    @State private var showConversation = false

    private let networkService = NetworkService.shared
    private let cacheKey = "cached_conversations"
    private let cacheTimestampKey = "cached_conversations_time"

    @ObservedObject private var socketService = WebSocketService.shared
    @State private var cancellables = Set<AnyCancellable>()

    var body: some View {
        NavigationView {
            VStack {
                if isLoading && conversations.isEmpty {
                    ProgressView("Загрузка...")
                } else if conversations.isEmpty {
                    emptyState
                } else {
                    chatList
                }
            }
            .navigationTitle("Чаты")
            .onAppear {
                loadData()
                setupWebSocket()
            }
            .onReceive(NotificationCenter.default.publisher(for: .userSelectedFromSearch)) { notification in
                if let user = notification.userInfo?["user"] as? User {
                    selectedUserForNavigation = user
                    showConversation = true
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink(destination: ProfileView()) {
                        Image(systemName: "person.crop.circle")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSearch = true }) {
                        Image(systemName: "magnifyingglass")
                    }
                }
            }
            .sheet(isPresented: $showingSearch) {
                SearchUserView()
            }
            .background(
                NavigationLink(
                    destination: ConversationView(
                        chatUser: selectedUserForNavigation ?? User(id: "", username: "", name: "", avatar: nil)
                    ),
                    isActive: $showConversation,
                    label: { EmptyView() }
                )
                .hidden()
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "message.badge")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("Нет активных чатов")
                .font(.headline)
                .foregroundColor(.gray)

            Text("Нажмите 🔍 чтобы найти пользователя")
                .font(.caption)
                .foregroundColor(.gray)

            Button(action: { showingSearch = true }) {
                Label("Найти пользователя", systemImage: "person.badge.plus")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: 200)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
        .padding()
    }

    private var chatList: some View {
        List {
            if !conversations.isEmpty {
                Section(header: Text("Ваши чаты")) {
                    ForEach(conversations) { conv in
                        NavigationLink(destination: ConversationView(chatUser: conv.user)) {
                            HStack {
                                AvatarView(user: conv.user, size: 45)

                                VStack(alignment: .leading) {
                                    HStack {
                                        Text(conv.user.name)
                                            .font(.headline)

                                        Spacer()

                                        Text(conv.formattedTime)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }

                                    Text(getLastMessagePreview(conv))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }

                                if conv.unreadCount > 0 {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 20, height: 20)
                                        .overlay(
                                            Text("\(conv.unreadCount)")
                                                .font(.caption2)
                                                .foregroundColor(.white)
                                        )
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Section(header: Text("Действия")) {
                    Button(action: { showingSearch = true }) {
                        Label("Найти нового пользователя", systemImage: "person.badge.plus")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .refreshable {
            loadData(force: true)
        }
    }

    private func getLastMessagePreview(_ conv: Conversation) -> String {
        switch conv.type {
        case .text:
            return conv.lastMessage
        case .image:
            return "📷 Фото"
        case .video:
            return "🎬 Видео"
        case .file:
            return "📎 Файл"
        case .voice:
            return "🎤 Голосовое"
        case .videoNote:
            return "⭕ Кружочек"
        case .mixed:
            return "📎 Вложения"
        }
    }

    private func setupWebSocket() {
        guard cancellables.isEmpty else { return }

        socketService.receivedMessage
            .receive(on: DispatchQueue.main)
            .sink { message in
                handleIncomingMessage(message)
            }
            .store(in: &cancellables)
    }

    private func handleIncomingMessage(_ message: Message) {
        let currentUsername = AuthManager.shared.currentUser?.username ?? ""
        let otherUsername = message.from == currentUsername ? message.to : message.from
        let isIncoming = message.from != currentUsername

        if let index = conversations.firstIndex(where: { $0.chatWith == otherUsername }) {
            let old = conversations[index]

            let updated = Conversation(
                chatWith: old.chatWith,
                lastMessage: message.displayText,
                timestamp: message.timestamp,
                unreadCount: isIncoming ? old.unreadCount + 1 : old.unreadCount,
                user: old.user,
                lastMessageType: message.mediaType
            )

            conversations.remove(at: index)
            conversations.insert(updated, at: 0)
            saveCache()
            return
        }

        createConversationLocally(for: message, otherUsername: otherUsername, isIncoming: isIncoming)
        loadData(force: true)
    }

    private func createConversationLocally(for message: Message, otherUsername: String, isIncoming: Bool) {
        let user = resolveUserForConversation(message: message, otherUsername: otherUsername)

        let newConversation = Conversation(
            chatWith: otherUsername,
            lastMessage: message.displayText,
            timestamp: message.timestamp,
            unreadCount: isIncoming ? 1 : 0,
            user: user,
            lastMessageType: message.mediaType
        )

        conversations.insert(newConversation, at: 0)
        deduplicateConversations()
        sortConversations()
        saveCache()
    }

    private func resolveUserForConversation(message: Message, otherUsername: String) -> User {
        if let existing = conversations.first(where: { $0.chatWith == otherUsername })?.user {
            return existing
        }

        if let currentUser = AuthManager.shared.currentUser {
            if message.from == currentUser.username {
                return User(
                    id: otherUsername,
                    username: otherUsername,
                    name: otherUsername,
                    avatar: nil
                )
            } else {
                return User(
                    id: message.from,
                    username: message.from,
                    name: message.from,
                    avatar: nil
                )
            }
        }

        return User(
            id: otherUsername,
            username: otherUsername,
            name: otherUsername,
            avatar: nil
        )
    }

    private func deduplicateConversations() {
        var seen = Set<String>()
        conversations = conversations.filter { conversation in
            if seen.contains(conversation.chatWith) {
                return false
            }
            seen.insert(conversation.chatWith)
            return true
        }
    }

    private func sortConversations() {
        conversations.sort { $0.date > $1.date }
    }

    private func saveCache() {
        if let encoded = try? JSONEncoder().encode(conversations) {
            UserDefaults.standard.set(encoded, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: cacheTimestampKey)
        }
    }

    private func loadData(force: Bool = false) {
        if !force,
           let cachedData = UserDefaults.standard.data(forKey: cacheKey),
           let cached = try? JSONDecoder().decode([Conversation].self, from: cachedData),
           let timestamp = UserDefaults.standard.object(forKey: cacheTimestampKey) as? Date,
           Date().timeIntervalSince(timestamp) < 300 {
            self.conversations = cached
            self.isLoading = false
            return
        }

        isLoading = true
        networkService.fetchConversations { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let convs):
                    self.conversations = convs.sorted { $0.date > $1.date }
                    self.saveCache()
                    self.isLoading = false

                case .failure(let error):
                    print("❌ Ошибка загрузки чатов: \(error)")
                    if let cachedData = UserDefaults.standard.data(forKey: self.cacheKey),
                       let cached = try? JSONDecoder().decode([Conversation].self, from: cachedData) {
                        self.conversations = cached
                    }
                    self.isLoading = false
                }
            }
        }
    }
}

extension Notification.Name {
    static let userSelectedFromSearch = Notification.Name("userSelectedFromSearch")
}
