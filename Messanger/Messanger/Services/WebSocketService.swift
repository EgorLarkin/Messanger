import Foundation
import Combine

class WebSocketService: ObservableObject {
    @Published var receivedMessage = PassthroughSubject<Message, Never>()
    
    private var socket: URLSessionWebSocketTask?
    private var cancellables = Set<AnyCancellable>()
    
    func connect(to url: URL) {
        let request = URLRequest(url: url)
        socket = URLSession.shared.webSocketTask(with: request)
        receive()
        socket?.resume()
    }
    
    private func receive() {
        socket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                if case .string(let text) = message {
                    if let decodedMessage = try? JSONDecoder().decode(Message.self, from: Data(text.utf8)) {
                        self?.receivedMessage.send(decodedMessage)
                    }
                }
                self?.receive()
            case .failure(let error):
                print("WebSocket error: \(error)")
            }
        }
    }
    
    func disconnect() {
        socket?.cancel(with: .goingAway, reason: nil)
    }
}
