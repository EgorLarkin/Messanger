import Foundation
import Combine

final class ConversationViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    let chatUser: User
    private let networkService = NetworkService.shared

    init(chatUser: User) {
        self.chatUser = chatUser
        loadHistory()
    }

    func loadHistory() {
        isLoading = true
        errorMessage = nil

        networkService.fetchHistory(with: chatUser.username) { [weak self] (result: Result<[Message], Error>) in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.isLoading = false

                switch result {
                case .success(let messages):
                    self.messages = messages.sorted { $0.date < $1.date }
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    print("❌ Failed to load history: \(error)")
                }
            }
        }
    }

    func sendText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        networkService.sendMessage(
            to: chatUser.username,
            text: trimmed,
            mediaType: .text,
            mediaData: nil,
            duration: nil,
            fileName: nil,
            fileSize: nil
        ) { [weak self] (result: Result<Message, Error>) in
            guard let self = self else { return }

            DispatchQueue.main.async {
                switch result {
                case .success(let message):
                    if !self.messages.contains(where: { $0.id == message.id }) {
                        self.messages.append(message)
                        self.messages.sort { $0.date < $1.date }
                    }
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    print("❌ Failed to send text: \(error)")
                }
            }
        }
    }
}
