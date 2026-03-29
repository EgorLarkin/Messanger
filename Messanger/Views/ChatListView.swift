import SwiftUI

struct ChatListView: View {
    @State private var conversations: [Conversation] = []
    @State private var allUsers: [User] = []
    @State private var showingSearch = false
    @State private var isLoading = false
    
    private let networkService = NetworkService.shared
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading && conversations.isEmpty {
                    ProgressView("Загрузка чатов...")
                } else if conversations.isEmpty {
                    emptyState
                } else {
                    chatList
                }
            }
            .navigationTitle("Чаты")
            .onAppear { loadData() }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSearch = true }) {
                        Image(systemName: "magnifyingglass")
                    }
                }
            }
            .sheet(isPresented: $showingSearch) {
                SearchUserView()
            }
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
        List(conversations) { conv in
            NavigationLink(destination: ConversationView(chatUser: conv.user)) {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 45))
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Text(conv.user.name)
                                .font(.headline)
                            Spacer()
                            Text(conv.formattedTime)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Text(conv.lastMessage)
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
    
    private func loadData() {
        isLoading = true
        
        networkService.fetchConversations { result in
            switch result {
            case .success(let convs):
                self.conversations = convs
                self.isLoading = false
            case .failure(let error):
                print("❌ Ошибка загрузки чатов: \(error)")
                self.isLoading = false
            }
        }
        
        networkService.fetchUsers { result in
            if case .success(let users) = result {
                self.allUsers = users.filter {
                    $0.username != AuthManager.shared.currentUser?.username
                }
            }
        }
    }
}
