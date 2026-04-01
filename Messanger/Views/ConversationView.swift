import SwiftUI
import Combine
import UIKit

struct ConversationView: View {
    let chatUser: User

    @StateObject private var viewModel: ConversationViewModel
    @State private var cancellables = Set<AnyCancellable>()

    init(chatUser: User) {
        self.chatUser = chatUser
        _viewModel = StateObject(wrappedValue: ConversationViewModel(chatUser: chatUser))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(viewModel.messages) { message in
                            MessageRow(message: message, chatUser: chatUser)
                                .id(message.id)
                        }

                        Color.clear
                            .frame(height: 1)
                            .id("BOTTOM")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .onAppear {
                    scrollToBottom(proxy, animated: false)
                    setupWebSocket()
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    scrollToBottom(proxy, animated: true)
                }
            }

            Divider()

            MessageInputView { text in
                viewModel.sendMessage(text: text) { _ in }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
        }
        .navigationTitle(chatUser.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool) {
        DispatchQueue.main.async {
            if animated {
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo("BOTTOM", anchor: .bottom)
                }
            } else {
                proxy.scrollTo("BOTTOM", anchor: .bottom)
            }
        }
    }

    private func setupWebSocket() {
        WebSocketService.shared.connect()

        WebSocketService.shared.receivedMessage
            .sink { receivedMessage in
                if receivedMessage.from == chatUser.username || receivedMessage.to == chatUser.username {
                    viewModel.appendFromWebSocket(receivedMessage)
                }
            }
            .store(in: &cancellables)
    }
}
