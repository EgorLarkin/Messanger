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
                guard let self = self else { return }

                switch result {
                case .success(let fetched):
                    let sortedMessages = fetched.sorted { lhs, rhs in
                        if lhs.date != rhs.date {
                            return lhs.date < rhs.date
                        }
                        return lhs.id < rhs.id
                    }

                    let currentIds = self.messages.map { $0.id }
                    let fetchedIds = sortedMessages.map { $0.id }

                    if currentIds != fetchedIds {
                        self.messages = sortedMessages
                    }

                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func sendMessage(text: String, completion: @escaping (Result<Message, Error>) -> Void) {
        networkService.sendMessage(to: chatUser.username, text: text) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }

                switch result {
                case .success(let message):
                    self.appendIfNeeded(message)
                    completion(.success(message))

                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    func appendFromWebSocket(_ message: Message) {
        DispatchQueue.main.async {
            self.appendIfNeeded(message)
        }
    }

    private func appendIfNeeded(_ message: Message) {
        guard !messages.contains(where: { $0.id == message.id }) else { return }

        messages.append(message)
        messages.sort { lhs, rhs in
            if lhs.date != rhs.date {
                return lhs.date < rhs.date
            }
            return lhs.id < rhs.id
        }
    }
}
