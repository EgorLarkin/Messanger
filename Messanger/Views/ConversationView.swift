import SwiftUI
import Combine
import Foundation

struct ConversationView: View {
    let chatUser: User

    @StateObject private var viewModel: ConversationViewModel
    @ObservedObject private var socketService = WebSocketService()
    @State private var cancellables = Set<AnyCancellable>()

    init(chatUser: User) {
        self.chatUser = chatUser
        _viewModel = StateObject(wrappedValue: ConversationViewModel(chatUser: chatUser))
    }

    var body: some View {
        VStack {
            ScrollViewReader { scrollView in
                ScrollView {
                    ForEach(viewModel.messages, id: \.id) { message in
                        MessageRow(message: message, chatUser: chatUser)
                            .id(message.id)
                    }
                }
                .onChange(of: viewModel.messages) { _ in
                    if let first = viewModel.messages.first {
                        withAnimation {
                            scrollView.scrollTo(first.id, anchor: .top)
                        }
                    }
                }
            }

            MessageInputView(onSend: { text in
                sendMessage(text: text)
            })
        }
        .onAppear {
            setupWebSocket()
        }
    }

    private func setupWebSocket() {
        guard let url = URL(string: "wss://messangerserver-1.onrender.com/socket") else {
            return
        }

        socketService.connect(to: url)

        socketService.receivedMessage
            .sink { [weak viewModel] receivedMessage in
                viewModel?.appendFromWebSocket(receivedMessage)
            }
            .store(in: &cancellables)
    }

    private func sendMessage(text: String) {
        viewModel.sendMessage(text: text) { result in
            if case .failure(let error) = result {
                print("❌ Failed to send message: \(error)")
            }
        }
    }
}

extension Message: Equatable {
    static func == (lhs: Message, rhs: Message) -> Bool {
        lhs.id == rhs.id
    }
}
