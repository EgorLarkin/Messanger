import Foundation
import Combine

class WebSocketService: ObservableObject {
    static let shared = WebSocketService()

    let receivedMessage = PassthroughSubject<Message, Never>()

    private var socket: URLSessionWebSocketTask?

    func connect() {
        guard socket == nil else { return }
        guard let token = AuthManager.shared.token else { return }

        let urlString = "wss://messangerserver-1.onrender.com/socket?token=\(token)"
        guard let encodedURL = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: encodedURL) else {
            return
        }

        socket = URLSession.shared.webSocketTask(with: url)
        socket?.resume()
        receive()
    }

    private func receive() {
        socket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                if case .string(let text) = message,
                   let decodedMessage = try? JSONDecoder().decode(Message.self, from: Data(text.utf8)) {
                    DispatchQueue.main.async {
                        self?.receivedMessage.send(decodedMessage)
                    }
                }
                self?.receive()
            case .failure(let error):
                print("WebSocket error: \(error)")
                self?.socket = nil
            }
        }
    }

    func disconnect() {
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
    }
}
