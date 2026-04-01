import SwiftUI
import Combine
import Foundation

struct ConversationView: View {
    let chatUser: User

    @StateObject private var viewModel: ConversationViewModel
    @ObservedObject private var networkService = NetworkService.shared
    @ObservedObject private var socketService = WebSocketService.shared

    @State private var cancellables = Set<AnyCancellable>()
    @State private var pendingMediaItems: [PendingMediaItem] = []
    @State private var showMediaComposer = false

    init(chatUser: User) {
        self.chatUser = chatUser
        _viewModel = StateObject(wrappedValue: ConversationViewModel(chatUser: chatUser))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { scrollView in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(sortedMessages, id: \.id) { message in
                            MessageRow(message: message, chatUser: chatUser)
                                .id(message.id)
                        }
                    }
                    .padding(.top, 8)
                }
                .onAppear {
                    setupWebSocket()

                    DispatchQueue.main.async {
                        if let lastMessage = sortedMessages.last {
                            scrollView.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: sortedMessages.count) { _ in
                    if let lastMessage = sortedMessages.last {
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
        .navigationTitle(chatUser.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var sortedMessages: [Message] {
        viewModel.messages.sorted { $0.date < $1.date }
    }

    private func setupWebSocket() {
        guard let url = URL(string: "wss://messangerserver-1.onrender.com/socket") else {
            return
        }

        socketService.connect(to: url)

        socketService.receivedMessage
            .sink { receivedMessage in
                guard receivedMessage.from == chatUser.username || receivedMessage.to == chatUser.username else {
                    return
                }

                if !viewModel.messages.contains(where: { $0.id == receivedMessage.id }) {
                    viewModel.messages.append(receivedMessage)
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
                    if !viewModel.messages.contains(where: { $0.id == message.id }) {
                        viewModel.messages.append(message)
                    }
                }

            case .failure(let error):
                print("❌ Failed to send text: \(error)")
            }
        }
    }

    private func sendMediaItems(_ items: [PendingMediaItem], caption: String) {
        for (index, item) in items.enumerated() {
            if let image = item.image,
               let data = image.jpegData(compressionQuality: 0.85) {

                let base64 = "image/jpeg;base64," + data.base64EncodedString()

                networkService.sendMessage(
                    to: chatUser.username,
                    text: index == 0 ? caption : "",
                    mediaType: .image,
                    mediaData: base64,
                    duration: nil,
                    fileName: "photo_\(UUID().uuidString.prefix(6)).jpg",
                    fileSize: data.count
                ) { result in
                    switch result {
                    case .success(let message):
                        DispatchQueue.main.async {
                            if !viewModel.messages.contains(where: { $0.id == message.id }) {
                                viewModel.messages.append(message)
                            }
                        }

                    case .failure(let error):
                        print("❌ Failed to send image: \(error)")
                    }
                }

            } else if let videoURL = item.videoURL {
                networkService.uploadMedia(
                    to: chatUser.username,
                    fileURL: videoURL,
                    mediaType: .video,
                    text: index == 0 ? caption : "",
                    duration: nil
                ) { result in
                    switch result {
                    case .success(let message):
                        DispatchQueue.main.async {
                            if !viewModel.messages.contains(where: { $0.id == message.id }) {
                                viewModel.messages.append(message)
                            }
                        }

                    case .failure(let error):
                        print("❌ Failed to send video: \(error)")
                    }
                }

            } else if let fileURL = item.fileURL {
                networkService.uploadMedia(
                    to: chatUser.username,
                    fileURL: fileURL,
                    mediaType: .file,
                    text: index == 0 ? caption : "",
                    duration: nil
                ) { result in
                    switch result {
                    case .success(let message):
                        DispatchQueue.main.async {
                            if !viewModel.messages.contains(where: { $0.id == message.id }) {
                                viewModel.messages.append(message)
                            }
                        }

                    case .failure(let error):
                        print("❌ Failed to send file: \(error)")
                    }
                }
            }
        }
    }
}
