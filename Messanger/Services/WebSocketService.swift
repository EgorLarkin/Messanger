import Foundation
import Combine

final class WebSocketService: ObservableObject {
    static let shared = WebSocketService()

    @Published var receivedMessage = PassthroughSubject<Message, Never>()

    private var socket: URLSessionWebSocketTask?
    private var cancellables = Set<AnyCancellable>()

    private init() { }

    func connect(to url: URL) {
        let request = URLRequest(url: url)
        socket = URLSession.shared.webSocketTask(with: request)
        socket?.resume()
        receive()
    }

    private func receive() {
        socket?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                if case .string(let text) = message {
                    if let decodedMessage = try? JSONDecoder().decode(Message.self, from: Data(text.utf8)) {
                        self.receivedMessage.send(decodedMessage)
                    }
                }
                self.receive()

            case .failure(let error):
                print("WebSocket error: \(error)")
            }
        }
    }

    func disconnect() {
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
    }
}
