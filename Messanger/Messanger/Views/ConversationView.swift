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
    @State private var showUserProfile = false

    init(chatUser: User) {
        self.chatUser = chatUser
        _viewModel = StateObject(wrappedValue: ConversationViewModel(chatUser: chatUser))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { scrollView in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(viewModel.messages, id: \.id) { message in
                            MessageRow(message: message, chatUser: chatUser)
                                .id(message.id)
                        }
                    }
                    .padding(.top, 8)
                }
                .onAppear {
                    setupWebSocket()

                    DispatchQueue.main.async {
                        if let lastMessage = viewModel.messages.last {
                            scrollView.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: viewModel.messages.count) { _ in
                    if let lastMessage = viewModel.messages.last {
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

                if !viewModel.messages.contains(where: { $0.id == receivedMessage.id }) {
                    viewModel.messages.append(receivedMessage)
                    viewModel.messages.sort { $0.date < $1.date }
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
                        viewModel.messages.sort { $0.date < $1.date }
                    }
                }

            case .failure(let error):
                print("❌ Failed to send text: \(error)")
            }
        }
    }

    private func sendMediaItems(_ items: [PendingMediaItem], caption: String) {
        for (index, item) in items.enumerated() {
            switch item.kind {
            case .image:
                guard let image = item.image,
                      let data = image.jpegData(compressionQuality: 0.85) else { continue }

                let base64 = "image/jpeg;base64," + data.base64EncodedString()

                networkService.sendMessage(
                    to: chatUser.username,
                    text: index == 0 ? caption : "",
                    mediaType: .image,
                    mediaData: base64,
                    duration: nil,
                    fileName: item.fileName,
                    fileSize: data.count
                ) { result in
                    switch result {
                    case .success(let message):
                        DispatchQueue.main.async {
                            if !viewModel.messages.contains(where: { $0.id == message.id }) {
                                viewModel.messages.append(message)
                                viewModel.messages.sort { $0.date < $1.date }
                            }
                        }

                    case .failure(let error):
                        print("❌ Failed to send image: \(error)")
                    }
                }

            case .video:
                guard let videoURL = item.videoURL,
                      let data = try? Data(contentsOf: videoURL) else { continue }

                let base64 = "video/mp4;base64," + data.base64EncodedString()

                networkService.sendMessage(
                    to: chatUser.username,
                    text: index == 0 ? caption : "",
                    mediaType: .video,
                    mediaData: base64,
                    duration: nil,
                    fileName: item.fileName,
                    fileSize: data.count
                ) { result in
                    switch result {
                    case .success(let message):
                        DispatchQueue.main.async {
                            if !viewModel.messages.contains(where: { $0.id == message.id }) {
                                viewModel.messages.append(message)
                                viewModel.messages.sort { $0.date < $1.date }
                            }
                        }

                    case .failure(let error):
                        print("❌ Failed to send video: \(error)")
                    }
                }
            }
        }
    }
}
