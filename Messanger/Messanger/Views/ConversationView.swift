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
                    }
                }
                .onChange(of: viewModel.messages) { _ in
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            scrollView.scrollTo(lastMessage.id, anchor: .bottom)
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
                guard let viewModel = viewModel else { return }
                if !viewModel.messages.contains(where: { $0.id == receivedMessage.id }) {
                    viewModel.messages.append(receivedMessage)
                }
            }
            .store(in: &cancellables)
    }

    private func sendMessage(text: String) {
        viewModel.sendMessage(text: text) { result in
            switch result {
            case .success:
                break
            case .failure(let error):
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
