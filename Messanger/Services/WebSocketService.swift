import Foundation
import Combine

final class WebSocketService: ObservableObject {
    static let shared = WebSocketService()

    let receivedMessage = PassthroughSubject<Message, Never>()
    let messageDidChange = PassthroughSubject<Void, Never>()

    private var socket: URLSessionWebSocketTask?
    private var isConnected = false

    private init() { }

    func connect(to url: URL) {
        disconnect()

        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: url)
        socket = task
        isConnected = true
        task.resume()

        listen()
    }

    private func listen() {
        guard isConnected, let socket = socket else { return }

        socket.receive { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let message):
                self.handle(message)
                self.listen()

            case .failure(let error):
                self.isConnected = false
                print("❌ WebSocket error: \(error.localizedDescription)")
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            guard let data = text.data(using: .utf8) else { return }
            handleData(data)

        case .data(let data):
            handleData(data)

        @unknown default:
            break
        }
    }

    private func handleData(_ data: Data) {
        let decoder = JSONDecoder()

        if let directMessage = try? decoder.decode(Message.self, from: data) {
            receivedMessage.send(directMessage)
            messageDidChange.send(())
            return
        }

        if let raw = try? decoder.decode(MessageData.self, from: data) {
            let mapped = mapMessageData(raw)
            receivedMessage.send(mapped)
            messageDidChange.send(())
            return
        }

        if let envelope = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let messageDict = envelope["message"] as? [String: Any],
           let parsed = parseMessageFromAny(messageDict) {
            receivedMessage.send(parsed)
            messageDidChange.send(())
            return
        }

        if let envelope = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let payload = envelope["data"] as? [String: Any],
               let parsed = parseMessageFromAny(payload) {
                receivedMessage.send(parsed)
                messageDidChange.send(())
                return
            }

            if let payload = envelope["payload"] as? [String: Any],
               let parsed = parseMessageFromAny(payload) {
                receivedMessage.send(parsed)
                messageDidChange.send(())
                return
            }

            let raw = String(data: data, encoding: .utf8) ?? "Unable to stringify websocket payload"
            print("⚠️ Unknown WebSocket payload: \(raw)")
            messageDidChange.send(())
            return
        }

        let raw = String(data: data, encoding: .utf8) ?? "Unable to stringify websocket payload"
        print("⚠️ Failed to decode WebSocket message: \(raw)")
        messageDidChange.send(())
    }

    private func mapMessageData(_ data: MessageData) -> Message {
        Message(
            id: data.id,
            from: data.from,
            to: data.to,
            text: data.text,
            mediaType: data.mediaType,
            mediaData: data.mediaData,
            attachments: data.attachments,
            duration: data.duration,
            fileName: data.fileName,
            fileSize: data.fileSize,
            timestamp: data.timestamp,
            fileId: data.fileId,
            downloadUrl: data.downloadUrl
        )
    }

    private func parseMessageFromAny(_ data: [String: Any]) -> Message? {
        guard
            let id = data["id"] as? String,
            let from = data["from"] as? String,
            let to = data["to"] as? String,
            let text = data["text"] as? String,
            let mediaType = data["mediaType"] as? String,
            let timestamp = data["timestamp"] as? String
        else {
            return nil
        }

        let mediaData = data["mediaData"] as? String
        let fileName = data["fileName"] as? String
        let fileId = data["fileId"] as? String
        let downloadUrl = data["downloadUrl"] as? String

        var duration: Double?
        if let value = data["duration"] as? Double {
            duration = value
        } else if let value = data["duration"] as? Int {
            duration = Double(value)
        }

        var fileSize: Int?
        if let size = data["fileSize"] as? Int {
            fileSize = size
        } else if let sizeDouble = data["fileSize"] as? Double {
            fileSize = Int(sizeDouble)
        }

        var attachments: [MessageAttachment]?
        if let rawAttachments = data["attachments"] as? [[String: Any]] {
            attachments = rawAttachments.compactMap { attachmentDict -> MessageAttachment? in
                guard let mediaData = attachmentDict["mediaData"] as? String else {
                    return nil
                }

                let fileName = attachmentDict["fileName"] as? String
                let downloadUrl = attachmentDict["downloadUrl"] as? String

                var fileSize: Int?
                if let size = attachmentDict["fileSize"] as? Int {
                    fileSize = size
                } else if let sizeDouble = attachmentDict["fileSize"] as? Double {
                    fileSize = Int(sizeDouble)
                }

                var attachmentDuration: Double?
                if let value = attachmentDict["duration"] as? Double {
                    attachmentDuration = value
                } else if let value = attachmentDict["duration"] as? Int {
                    attachmentDuration = Double(value)
                }

                return MessageAttachment(
                    mediaData: mediaData,
                    fileName: fileName,
                    fileSize: fileSize,
                    downloadUrl: downloadUrl,
                    duration: attachmentDuration
                )
            }
        }

        return Message(
            id: id,
            from: from,
            to: to,
            text: text,
            mediaType: mediaType,
            mediaData: mediaData,
            attachments: attachments,
            duration: duration,
            fileName: fileName,
            fileSize: fileSize,
            timestamp: timestamp,
            fileId: fileId,
            downloadUrl: downloadUrl
        )
    }

    func disconnect() {
        isConnected = false
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
    }
}
