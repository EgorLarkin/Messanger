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
    @State private var isSendingMediaBatch = false

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
            .disabled(isSendingMediaBatch)
        }
        .sheet(isPresented: $showMediaComposer) {
            MediaComposerSheet(
                initialItems: pendingMediaItems,
                isSending: isSendingMediaBatch
            ) { caption, items in
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
        guard !isSendingMediaBatch else { return }

        isSendingMediaBatch = true

        let normalizedCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)

        if containsMixedTypes(items) {
            sendItemsSequentially(items, caption: normalizedCaption) { _ in
                DispatchQueue.main.async {
                    isSendingMediaBatch = false
                    showMediaComposer = false
                    pendingMediaItems = []
                }
            }
            return
        }

        if items.count == 1, let item = items.first {
            sendSingleMediaItem(item, caption: normalizedCaption) { _ in
                DispatchQueue.main.async {
                    isSendingMediaBatch = false
                    showMediaComposer = false
                    pendingMediaItems = []
                }
            }
            return
        }

        if items.allSatisfy({ $0.type == .image }) {
            sendGroupAttachments(items, caption: normalizedCaption, groupType: .image) { _ in
                DispatchQueue.main.async {
                    isSendingMediaBatch = false
                    showMediaComposer = false
                    pendingMediaItems = []
                }
            }
            return
        }

        if items.allSatisfy({ $0.type == .video }) {
            sendVideoGroup(items, caption: normalizedCaption) { _ in
                DispatchQueue.main.async {
                    isSendingMediaBatch = false
                    showMediaComposer = false
                    pendingMediaItems = []
                }
            }
            return
        }

        sendItemsSequentially(items, caption: normalizedCaption) { _ in
            DispatchQueue.main.async {
                isSendingMediaBatch = false
                showMediaComposer = false
                pendingMediaItems = []
            }
        }
    }

    private func containsMixedTypes(_ items: [PendingMediaItem]) -> Bool {
        let types = Set(items.map { $0.type.rawValue })
        return types.count > 1
    }

    private func sendItemsSequentially(
        _ items: [PendingMediaItem],
        caption: String,
        completion: @escaping (Bool) -> Void
    ) {
        guard !items.isEmpty else {
            completion(false)
            return
        }

        sendNextItem(items, index: 0, caption: caption, sentAny: false, completion: completion)
    }

    private func sendNextItem(
        _ items: [PendingMediaItem],
        index: Int,
        caption: String,
        sentAny: Bool,
        completion: @escaping (Bool) -> Void
    ) {
        guard index < items.count else {
            completion(sentAny)
            return
        }

        let item = items[index]
        let textForCurrentItem = index == 0 ? caption : ""

        sendSingleMediaItem(item, caption: textForCurrentItem) { success in
            DispatchQueue.main.async {
                if success {
                    sendNextItem(
                        items,
                        index: index + 1,
                        caption: caption,
                        sentAny: true,
                        completion: completion
                    )
                } else {
                    completion(sentAny)
                }
            }
        }
    }

    private func sendSingleMediaItem(
        _ item: PendingMediaItem,
        caption: String,
        completion: @escaping (Bool) -> Void
    ) {
        switch item.type {
        case .image:
            guard let image = item.image,
                  let data = image.jpegData(compressionQuality: 0.85) else {
                print("❌ Не удалось подготовить изображение")
                completion(false)
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
                        completion(true)
                    }
                case .failure(let error):
                    print("❌ Failed to send image: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        completion(false)
                    }
                }
            }

        case .video:
            guard let videoURL = item.videoURL else {
                print("❌ Видео не найдено")
                completion(false)
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
                        completion(true)
                    }
                case .failure(let error):
                    print("❌ Failed to send video via /send-media: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        completion(false)
                    }
                }
            }

        case .file:
            guard let fileURL = item.fileURL else {
                print("❌ Файл не найден")
                completion(false)
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
                        completion(true)
                    }
                case .failure(let error):
                    print("❌ Failed to send file via /send-media: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        completion(false)
                    }
                }
            }

        default:
            print("❌ Неподдерживаемый тип вложения")
            completion(false)
        }
    }

    private func sendGroupAttachments(
        _ items: [PendingMediaItem],
        caption: String,
        groupType: MediaType,
        completion: @escaping (Bool) -> Void
    ) {
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
            completion(false)
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
                    completion(true)
                }
            case .failure(let error):
                print("❌ Failed to send attachments group: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }

    private func sendVideoGroup(
        _ items: [PendingMediaItem],
        caption: String,
        completion: @escaping (Bool) -> Void
    ) {
        let urls = items.compactMap { $0.videoURL }
        guard urls.count == items.count, !urls.isEmpty else {
            print("❌ Не удалось собрать все videoURL для группы")
            completion(false)
            return
        }

        let durations: [Double?] = urls.map { url in
            let asset = AVAsset(url: url)
            let seconds = CMTimeGetSeconds(asset.duration)
            return (seconds.isFinite && !seconds.isNaN) ? seconds : nil
        }

        networkService.sendMediaFilesGroup(
            to: chatUser.username,
            mediaType: .video,
            fileURLs: urls,
            caption: caption,
            durations: durations
        ) { result in
            switch result {
            case .success(let message):
                DispatchQueue.main.async {
                    appendMessageIfNeeded(message)
                    completion(true)
                }
            case .failure(let error):
                print("❌ Failed to send video group via /send-media-group: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(false)
                }
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
