import SwiftUI
import Combine
import Foundation
import AVFoundation
import UIKit

struct ConversationView: View {
    let chatUser: User

    @State private var messages: [Message] = []
    @ObservedObject private var networkService = NetworkService.shared
    @ObservedObject private var socketService = WebSocketService.shared
    @State private var cancellables = Set<AnyCancellable>()

    @State private var pendingMediaItems: [PendingMediaItem] = []
    @State private var showMediaComposer = false
    @State private var showUserProfile = false
    @State private var isInitialLoadDone = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { scrollView in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(messages, id: \.id) { message in
                            MessageRow(message: message, chatUser: chatUser)
                                .id(message.id)
                        }
                    }
                    .padding(.top, 8)
                }
                .onAppear {
                    setupBindings()
                    loadMessages()
                    setupWebSocket()

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        scrollToBottom(scrollView)
                    }
                }
                .onDisappear {
                    cancellables.removeAll()
                }
                .onChange(of: messages.count) { _ in
                    DispatchQueue.main.async {
                        withAnimation(.easeOut(duration: 0.25)) {
                            scrollToBottom(scrollView)
                        }
                    }
                }
            }

            Divider()

            MessageInputView(
                onSendText: { text in
                    sendTextMessage(text)
                },
                onAddMediaDraft: { items in
                    pendingMediaItems = items
                    showMediaComposer = true
                }
            )
        }
        .sheet(isPresented: $showMediaComposer) {
            MediaComposerSheet(initialItems: pendingMediaItems) { caption, items in
                sendMediaItems(items, caption: caption)
            }
        }
        .sheet(isPresented: $showUserProfile) {
            NavigationView {
                UserProfileView(user: chatUser)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button {
                    showUserProfile = true
                } label: {
                    HStack(spacing: 10) {
                        AvatarView(user: chatUser, size: 36)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(chatUser.name)
                                .font(.headline)
                                .foregroundColor(.primary)
                                .lineLimit(1)

                            Text("@\(chatUser.username)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func setupBindings() {
        guard cancellables.isEmpty else { return }

        socketService.receivedMessage
            .receive(on: DispatchQueue.main)
            .sink { receivedMessage in
                guard receivedMessage.from == chatUser.username || receivedMessage.to == chatUser.username else {
                    return
                }

                appendMessageIfNeeded(receivedMessage)
            }
            .store(in: &cancellables)

        socketService.messageDidChange
            .receive(on: DispatchQueue.main)
            .sink { _ in
                loadMessages()
            }
            .store(in: &cancellables)
    }

    private func loadMessages() {
        networkService.fetchHistory(with: chatUser.username) { result in
            switch result {
            case .success(let history):
                DispatchQueue.main.async {
                    let sorted = history.sorted { $0.date < $1.date }
                    self.messages = sorted
                    self.isInitialLoadDone = true
                }

            case .failure(let error):
                print("❌ Ошибка загрузки сообщений: \(error.localizedDescription)")
            }
        }
    }

    private func setupWebSocket() {
        guard let token = AuthManager.shared.token,
              let url = URL(string: "wss://messangerserver-1.onrender.com/socket?token=\(token)") else {
            return
        }

        socketService.connect(to: url)
    }

    private func sendTextMessage(_ text: String) {
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
        ) { result in
            switch result {
            case .success(let message):
                DispatchQueue.main.async {
                    appendMessageIfNeeded(message)
                }

            case .failure(let error):
                print("❌ Failed to send text: \(error.localizedDescription)")
            }
        }
    }

    private func sendMediaItems(_ items: [PendingMediaItem], caption: String) {
        guard !items.isEmpty else { return }

        if containsMixedTypes(items) {
            sendItemsSequentially(items, caption: caption)
            return
        }

        if items.count == 1, let item = items.first {
            sendSingleMediaItem(item, caption: caption)
            return
        }

        if items.allSatisfy({ $0.type == .image }) {
            sendGroupAttachments(items, caption: caption, groupType: .image)
            return
        }

        sendItemsSequentially(items, caption: caption)
    }

    private func containsMixedTypes(_ items: [PendingMediaItem]) -> Bool {
        let types = Set(items.map { $0.type.rawValue })
        return types.count > 1
    }

    private func sendItemsSequentially(_ items: [PendingMediaItem], caption: String) {
        guard !items.isEmpty else { return }

        for (index, item) in items.enumerated() {
            let text = index == 0 ? caption : ""
            sendSingleMediaItem(item, caption: text)
        }
    }

    private func sendSingleMediaItem(_ item: PendingMediaItem, caption: String) {
        switch item.type {
        case .image:
            guard let image = item.image,
                  let data = image.jpegData(compressionQuality: 0.85) else {
                print("❌ Не удалось подготовить изображение")
                return
            }

            let base64 = "image/jpeg;base64," + data.base64EncodedString()

            networkService.sendMessage(
                to: chatUser.username,
                text: caption,
                mediaType: .image,
                mediaData: base64,
                duration: nil,
                fileName: item.fileName.isEmpty ? "image.jpg" : item.fileName,
                fileSize: data.count
            ) { result in
                switch result {
                case .success(let message):
                    DispatchQueue.main.async {
                        appendMessageIfNeeded(message)
                    }

                case .failure(let error):
                    print("❌ Failed to send image: \(error.localizedDescription)")
                }
            }

        case .video:
            guard let videoURL = item.videoURL else {
                print("❌ Видео не найдено")
                return
            }

            let asset = AVAsset(url: videoURL)
            let seconds = CMTimeGetSeconds(asset.duration)
            let duration: Double? = (seconds.isFinite && !seconds.isNaN) ? seconds : nil

            networkService.sendMediaFile(
                to: chatUser.username,
                mediaType: .video,
                fileURL: videoURL,
                text: caption,
                duration: duration
            ) { result in
                switch result {
                case .success(let message):
                    DispatchQueue.main.async {
                        appendMessageIfNeeded(message)
                    }

                case .failure(let error):
                    print("❌ Failed to send video via /send-media: \(error.localizedDescription)")
                }
            }

        case .file:
            guard let fileURL = item.fileURL else {
                print("❌ Файл не найден")
                return
            }

            networkService.sendMediaFile(
                to: chatUser.username,
                mediaType: .file,
                fileURL: fileURL,
                text: caption,
                duration: nil
            ) { result in
                switch result {
                case .success(let message):
                    DispatchQueue.main.async {
                        appendMessageIfNeeded(message)
                    }

                case .failure(let error):
                    print("❌ Failed to send file via /send-media: \(error.localizedDescription)")
                }
            }

        default:
            print("❌ Неподдерживаемый тип вложения")
        }
    }

    private func sendGroupAttachments(_ items: [PendingMediaItem], caption: String, groupType: MediaType) {
        var attachments: [AttachmentPayload] = []

        for item in items {
            switch item.type {
            case .image:
                guard let image = item.image,
                      let data = image.jpegData(compressionQuality: 0.85) else { continue }

                let base64 = "image/jpeg;base64," + data.base64EncodedString()
                let payload = AttachmentPayload(
                    mediaData: base64,
                    fileName: item.fileName.isEmpty ? "image.jpg" : item.fileName,
                    fileSize: data.count
                )
                attachments.append(payload)

            default:
                continue
            }
        }

        guard !attachments.isEmpty else {
            print("❌ Нет валидных вложений для группы")
            return
        }

        networkService.sendAttachments(
            to: chatUser.username,
            text: caption,
            mediaType: groupType,
            attachments: attachments,
            duration: nil
        ) { result in
            switch result {
            case .success(let message):
                DispatchQueue.main.async {
                    appendMessageIfNeeded(message)
                }

            case .failure(let error):
                print("❌ Failed to send attachments group: \(error.localizedDescription)")
            }
        }
    }

    private func appendMessageIfNeeded(_ message: Message) {
        guard message.from == chatUser.username || message.to == chatUser.username else {
            return
        }

        if !messages.contains(where: { $0.id == message.id }) {
            messages.append(message)
            messages.sort { $0.date < $1.date }
        }
    }

    private func scrollToBottom(_ scrollView: ScrollViewProxy) {
        if let lastMessage = messages.last {
            scrollView.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }
}
