import SwiftUI

struct ChatListView: View {
    @State private var conversations: [Conversation] = []
    @State private var showingSearch = false
    @State private var isLoading = false
    @State private var selectedUserForNavigation: User?
    @State private var showConversation = false
    
    private let networkService = NetworkService.shared
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading && conversations.isEmpty {
                    ProgressView("Загрузка...")
                } else if conversations.isEmpty {
                    emptyState
                } else {
                    chatList
                }
            }
            .navigationTitle("Чаты")
            .onAppear { loadData() }
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
                            .font(.title2)
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
                    destination: ConversationView(chatUser: selectedUserForNavigation ?? User(id: "", username: "", name: "", avatar: nil)),
                    isActive: $showConversation,
                    label: { EmptyView() }
                )
                .hidden()
            )
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "message.badge").font(.system(size: 60)).foregroundColor(.gray)
            Text("Нет активных чатов").font(.headline).foregroundColor(.gray)
            Text("Нажмите 🔍 чтобы найти пользователя").font(.caption).foregroundColor(.gray)
            Button(action: { showingSearch = true }) {
                Label("Найти пользователя", systemImage: "person.badge.plus")
                    .font(.headline).foregroundColor(.white).padding().frame(maxWidth: 200)
                    .background(Color.blue).cornerRadius(10)
            }
        }.padding()
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
                                        Text(conv.user.name).font(.headline)
                                        Spacer()
                                        Text(conv.formattedTime).font(.caption).foregroundColor(.gray)
                                    }
                                    Text(conv.lastMessage).font(.subheadline).foregroundColor(.secondary).lineLimit(1)
                                }
                                if conv.unreadCount > 0 {
                                    Circle().fill(Color.red).frame(width: 20, height: 20)
                                        .overlay(Text("\(conv.unreadCount)").font(.caption2).foregroundColor(.white))
                                }
                            }.padding(.vertical, 4)
                        }
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
    
    private func loadData() {
        isLoading = true
        networkService.fetchConversations { result in
            switch result {
            case .success(let convs): self.conversations = convs; self.isLoading = false
            case .failure(let error): print("❌ Ошибка: \(error)"); self.isLoading = false
            }
        }
    }
}

extension Notification.Name {
    static let userSelectedFromSearch = Notification.Name("userSelectedFromSearch")
}
