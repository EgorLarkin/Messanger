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
                    loadMessages()
                    setupWebSocket()

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        if let lastMessage = messages.last {
                            scrollView.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: messages.count) { _ in
                    if let lastMessage = messages.last {
                        withAnimation(.easeOut(duration: 0.25)) {
                            scrollView.scrollTo(lastMessage.id, anchor: .bottom)
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
            MediaComposerSheet(items: pendingMediaItems) { caption, items in
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

    private func loadMessages() {
        networkService.fetchHistory(with: chatUser.username) { result in
            switch result {
            case .success(let history):
                DispatchQueue.main.async {
                    self.messages = history.sorted { $0.date < $1.date }
                }
            case .failure(let error):
                print("❌ Ошибка загрузки сообщений: \(error)")
            }
        }
    }

    private func setupWebSocket() {
        guard let token = AuthManager.shared.token,
              let url = URL(string: "wss://messangerserver-1.onrender.com/socket?token=\(token)") else {
            return
        }

        socketService.connect(to: url)

        socketService.receivedMessage
            .receive(on: DispatchQueue.main)
            .sink { receivedMessage in
                guard receivedMessage.from == chatUser.username || receivedMessage.to == chatUser.username else {
                    return
                }

                if !messages.contains(where: { $0.id == receivedMessage.id }) {
                    messages.append(receivedMessage)
                    messages.sort { $0.date < $1.date }
                }
            }
            .store(in: &cancellables)
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
                print("❌ Failed to send text: \(error)")
            }
        }
    }

    private func sendMediaItems(_ items: [PendingMediaItem], caption: String) {
        guard !items.isEmpty else { return }

        if items.count == 1, let item = items.first {
            sendSingleMediaItem(item, caption: caption)
            return
        }

        sendGroupAttachments(items, caption: caption)
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
                    print("❌ Failed to send image: \(error)")
                }
            }

        case .video:
            guard let videoURL = item.videoURL,
                  let data = try? Data(contentsOf: videoURL) else {
                print("❌ Не удалось подготовить видео")
                return
            }

            let asset = AVAsset(url: videoURL)
            let seconds = CMTimeGetSeconds(asset.duration)
            let duration = seconds.isFinite && !seconds.isNaN ? seconds : nil
            let base64 = "video/mp4;base64," + data.base64EncodedString()

            networkService.sendMessage(
                to: chatUser.username,
                text: caption,
                mediaType: .video,
                mediaData: base64,
                duration: duration,
                fileName: item.fileName.isEmpty ? videoURL.lastPathComponent : item.fileName,
                fileSize: data.count
            ) { result in
                switch result {
                case .success(let message):
                    DispatchQueue.main.async {
                        appendMessageIfNeeded(message)
                    }
                case .failure(let error):
                    print("❌ Failed to send video: \(error)")
                }
            }

        default:
            print("❌ Неподдерживаемый тип вложения")
        }
    }

    private func sendGroupAttachments(_ items: [PendingMediaItem], caption: String) {
        var attachments: [AttachmentPayload] = []
        var groupType: MediaType = .image

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
                groupType = .image

            case .video:
                guard let videoURL = item.videoURL,
                      let data = try? Data(contentsOf: videoURL) else { continue }

                let base64 = "video/mp4;base64," + data.base64EncodedString()
                let payload = AttachmentPayload(
                    mediaData: base64,
                    fileName: item.fileName.isEmpty ? videoURL.lastPathComponent : item.fileName,
                    fileSize: data.count
                )
                attachments.append(payload)
                groupType = .video

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
                print("❌ Failed to send attachments group: \(error)")
            }
        }
    }

    private func appendMessageIfNeeded(_ message: Message) {
        if !messages.contains(where: { $0.id == message.id }) {
            messages.append(message)
            messages.sort { $0.date < $1.date }
        }
    }
}
