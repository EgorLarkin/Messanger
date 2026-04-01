import Foundation
import SwiftUI
import Combine

class ConversationViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    let chatUser: User

    init(chatUser: User) {
        self.chatUser = chatUser
        loadMessages()
    }

    func loadMessages() {
        guard let currentUser = AuthManager.shared.currentUser else { return }

        isLoading = true
        NetworkService.shared.fetchHistory(user1: currentUser.username, user2: chatUser.username) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let messages):
                    self.messages = messages
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func sendMessage(text: String, completion: @escaping (Bool) -> Void) {
        guard let currentUser = AuthManager.shared.currentUser else {
            completion(false)
            return
        }

        let localId = UUID().uuidString
        let pendingMessage = Message(
            id: "local-\(localId)",
            from: currentUser.username,
            to: chatUser.username,
            text: text,
            mediaType: "text",
            mediaData: nil,
            fileId: nil,
            downloadUrl: nil,
            duration: nil,
            fileName: nil,
            fileSize: nil,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            localFilePath: nil,
            localId: localId,
            deliveryState: .sending
        )

        messages.append(pendingMessage)

        NetworkService.shared.sendMessage(to: chatUser.username, text: text) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let serverMessage):
                    self.replacePendingMessage(localId: localId, with: serverMessage)
                    completion(true)

                case .failure(let error):
                    self.markFailed(localId: localId)
                    self.errorMessage = error.localizedDescription
                    completion(false)
                }
            }
        }
    }

    func sendMedia(url: URL, type: MediaType, completion: @escaping (Bool) -> Void) {
        guard let currentUser = AuthManager.shared.currentUser else {
            completion(false)
            return
        }

        let localId = UUID().uuidString
        let pendingMessage = Message(
            id: "local-\(localId)",
            from: currentUser.username,
            to: chatUser.username,
            text: "",
            mediaType: type.rawValue,
            mediaData: nil,
            fileId: nil,
            downloadUrl: nil,
            duration: nil,
            fileName: url.lastPathComponent,
            fileSize: fileSize(at: url),
            timestamp: ISO8601DateFormatter().string(from: Date()),
            localFilePath: url.path,
            localId: localId,
            deliveryState: .sending
        )

        messages.append(pendingMessage)

        NetworkService.shared.sendMediaMessage(
            to: chatUser.username,
            fileURL: url,
            mediaType: type,
            text: ""
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(var serverMessage):
                    serverMessage.localFilePath = url.path
                    self.replacePendingMessage(localId: localId, with: serverMessage)
                    completion(true)

                case .failure(let error):
                    self.markFailed(localId: localId)
                    self.errorMessage = error.localizedDescription
                    completion(false)
                }
            }
        }
    }

    func appendFromWebSocket(_ message: Message) {
        if !messages.contains(where: { $0.id == message.id }) {
            messages.append(message)
            messages.sort { $0.date < $1.date }
        }
    }

    private func replacePendingMessage(localId: String, with serverMessage: Message) {
        if let index = messages.firstIndex(where: { $0.localId == localId }) {
            var updated = serverMessage
            updated.deliveryState = .sent
            updated.localId = localId

            if messages[index].type == .image || messages[index].type == .video {
                updated.localFilePath = messages[index].localFilePath
            }

            messages[index] = updated
        } else if !messages.contains(where: { $0.id == serverMessage.id }) {
            messages.append(serverMessage)
        }

        messages.sort { $0.date < $1.date }
    }

    private func markFailed(localId: String) {
        guard let index = messages.firstIndex(where: { $0.localId == localId }) else { return }
        messages[index].deliveryState = .failed
    }

    private func fileSize(at url: URL) -> Int? {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return values?.fileSize
    }
}
