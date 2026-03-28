import Foundation
import Combine

class ConversationViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let chatUser: User
    private let networkService = NetworkService.shared
    private var updateTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    init(chatUser: User) {
        self.chatUser = chatUser
        startAutoUpdate()
    }
    
    deinit {
        stopAutoUpdate()
    }
    
    private func startAutoUpdate() {
        loadMessages()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.loadMessages()
        }
    }
    
    private func stopAutoUpdate() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    func loadMessages() {
        guard let current = AuthManager.shared.currentUser else { return }
        
        networkService.fetchHistory(user1: current.username, user2: chatUser.username) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let fetched):
                    let sortedMessages = fetched.sorted { $0.date < $1.date }
                    if self?.messages.count != sortedMessages.count {
                        self?.messages = sortedMessages
                    }
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func sendMessage(text: String, completion: @escaping (Result<Message, Error>) -> Void) {
        networkService.sendMessage(to: chatUser.username, text: text) { [weak self] result in
            switch result {
            case .success(let message):
                if !(self?.messages.contains(where: { $0.id == message.id }) ?? true) {
                    self?.messages.append(message)
                }
                completion(.success(message))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
