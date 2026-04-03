import Foundation
import Combine

final class NetworkService: ObservableObject {
    static let shared = NetworkService()

    private let baseURL = "https://messangerserver-1.onrender.com"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }

    private var jsonDecoder: JSONDecoder { JSONDecoder() }
    private var jsonEncoder: JSONEncoder { JSONEncoder() }

    private func makeURL(_ path: String) -> URL? {
        URL(string: baseURL + path)
    }

    private func authorizedRequest(
        url: URL,
        method: String = "GET",
        body: Data? = nil
    ) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = AuthManager.shared.token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = body
        return request
    }

    private func performDecodableRequest<T: Decodable>(
        _ request: URLRequest,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "NetworkService", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Invalid server response"
                    ])))
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "NetworkService", code: -2, userInfo: [
                        NSLocalizedDescriptionKey: "Empty response data"
                    ])))
                }
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let serverText = String(data: data, encoding: .utf8) ?? "Unknown server error"
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "NetworkService", code: httpResponse.statusCode, userInfo: [
                        NSLocalizedDescriptionKey: serverText
                    ])))
                }
                return
            }

            do {
                let decoded = try self.jsonDecoder.decode(T.self, from: data)
                DispatchQueue.main.async { completion(.success(decoded)) }
            } catch {
                let raw = String(data: data, encoding: .utf8) ?? "Unable to decode response"
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "NetworkService", code: -3, userInfo: [
                        NSLocalizedDescriptionKey: "Decoding error: \(error.localizedDescription)\nResponse: \(raw)"
                    ])))
                }
            }
        }.resume()
    }

    private func mapMessage(_ data: MessageData) -> Message {
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

    // MARK: - Auth

    func register(
        username: String,
        password: String,
        name: String,
        completion: @escaping (Result<AuthResponse, Error>) -> Void
    ) {
        guard let url = makeURL("/auth/register") else {
            completion(.failure(NSError(domain: "NetworkService", code: -10, userInfo: [
                NSLocalizedDescriptionKey: "Invalid register URL"
            ])))
            return
        }

        let payload: [String: String] = [
            "username": username,
            "password": password,
            "name": name
        ]

        do {
            let body = try JSONSerialization.data(withJSONObject: payload)
            let request = authorizedRequest(url: url, method: "POST", body: body)
            performDecodableRequest(request, completion: completion)
        } catch {
            completion(.failure(error))
        }
    }

    func login(
        username: String,
        password: String,
        completion: @escaping (Result<AuthResponse, Error>) -> Void
    ) {
        guard let url = makeURL("/auth/login") else {
            completion(.failure(NSError(domain: "NetworkService", code: -11, userInfo: [
                NSLocalizedDescriptionKey: "Invalid login URL"
            ])))
            return
        }

        let payload: [String: String] = [
            "username": username,
            "password": password
        ]

        do {
            let body = try JSONSerialization.data(withJSONObject: payload)
            let request = authorizedRequest(url: url, method: "POST", body: body)
            performDecodableRequest(request, completion: completion)
        } catch {
            completion(.failure(error))
        }
    }

    // MARK: - Users / Profile

    func searchUsers(
        query: String,
        completion: @escaping (Result<[User], Error>) -> Void
    ) {
        guard var components = URLComponents(string: baseURL + "/users/search") else {
            completion(.failure(NSError(domain: "NetworkService", code: -20, userInfo: [
                NSLocalizedDescriptionKey: "Invalid search URL"
            ])))
            return
        }

        components.queryItems = [URLQueryItem(name: "q", value: query)]

        guard let url = components.url else {
            completion(.failure(NSError(domain: "NetworkService", code: -21, userInfo: [
                NSLocalizedDescriptionKey: "Failed to build search URL"
            ])))
            return
        }

        let request = authorizedRequest(url: url)

        performDecodableRequest(request) { (result: Result<SearchResponse, Error>) in
            switch result {
            case .success(let response):
                completion(.success(response.users))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func fetchProfile(
        completion: @escaping (Result<User, Error>) -> Void
    ) {
        guard let url = makeURL("/auth/verify") else {
            completion(.failure(NSError(domain: "NetworkService", code: -22, userInfo: [
                NSLocalizedDescriptionKey: "Invalid profile URL"
            ])))
            return
        }

        let request = authorizedRequest(url: url)

        performDecodableRequest(request) { (result: Result<ProfileVerifyResponse, Error>) in
            switch result {
            case .success(let response):
                if let user = response.user {
                    AuthManager.shared.currentUser = user
                    completion(.success(user))
                } else {
                    completion(.failure(NSError(domain: "NetworkService", code: -23, userInfo: [
                        NSLocalizedDescriptionKey: "Profile not found"
                    ])))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func updateProfile(
        name: String,
        completion: @escaping (Result<User, Error>) -> Void
    ) {
        guard let url = makeURL("/profile") else {
            completion(.failure(NSError(domain: "NetworkService", code: -24, userInfo: [
                NSLocalizedDescriptionKey: "Invalid update profile URL"
            ])))
            return
        }

        do {
            let body = try jsonEncoder.encode(ProfileUpdateRequest(name: name))
            let request = authorizedRequest(url: url, method: "PUT", body: body)

            performDecodableRequest(request) { (result: Result<ProfileUpdateResponse, Error>) in
                switch result {
                case .success(let response):
                    if response.success, let user = response.user {
                        AuthManager.shared.currentUser = user
                        completion(.success(user))
                    } else {
                        completion(.failure(NSError(domain: "NetworkService", code: -25, userInfo: [
                            NSLocalizedDescriptionKey: response.error ?? "Failed to update profile"
                        ])))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }

    func uploadAvatar(
        avatarBase64: String,
        completion: @escaping (Result<User, Error>) -> Void
    ) {
        guard let url = makeURL("/profile/avatar") else {
            completion(.failure(NSError(domain: "NetworkService", code: -26, userInfo: [
                NSLocalizedDescriptionKey: "Invalid avatar upload URL"
            ])))
            return
        }

        let payload: [String: String] = [ "avatar": avatarBase64 ]

        do {
            let body = try JSONSerialization.data(withJSONObject: payload)
            let request = authorizedRequest(url: url, method: "PUT", body: body)

            performDecodableRequest(request) { (result: Result<ProfileUpdateResponse, Error>) in
                switch result {
                case .success(let response):
                    if response.success, let user = response.user {
                        AuthManager.shared.currentUser = user
                        completion(.success(user))
                    } else {
                        completion(.failure(NSError(domain: "NetworkService", code: -27, userInfo: [
                            NSLocalizedDescriptionKey: response.error ?? "Failed to upload avatar"
                        ])))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }

    func deleteAccount(
        completion: @escaping (Result<Bool, Error>) -> Void
    ) {
        guard let url = makeURL("/profile") else {
            completion(.failure(NSError(domain: "NetworkService", code: -28, userInfo: [
                NSLocalizedDescriptionKey: "Invalid delete account URL"
            ])))
            return
        }

        let request = authorizedRequest(url: url, method: "DELETE")

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "NetworkService", code: -29, userInfo: [
                        NSLocalizedDescriptionKey: "Invalid server response"
                    ])))
                }
                return
            }

            let ok = (200...299).contains(httpResponse.statusCode)

            if ok {
                DispatchQueue.main.async { completion(.success(true)) }
            } else {
                let serverText = data.flatMap { String(data: $0, encoding: .utf8) } ?? "Delete failed"
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "NetworkService", code: httpResponse.statusCode, userInfo: [
                        NSLocalizedDescriptionKey: serverText
                    ])))
                }
            }
        }.resume()
    }

    func fetchConversations(
        completion: @escaping (Result<[Conversation], Error>) -> Void
    ) {
        guard let url = makeURL("/conversations") else {
            completion(.failure(NSError(domain: "NetworkService", code: -30, userInfo: [
                NSLocalizedDescriptionKey: "Invalid conversations URL"
            ])))
            return
        }

        let request = authorizedRequest(url: url)

        performDecodableRequest(request) { (result: Result<ConversationsResponse, Error>) in
            switch result {
            case .success(let response):
                completion(.success(response.conversations))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - Messages

    func fetchMessages(
        with username: String,
        completion: @escaping (Result<[Message], Error>) -> Void
    ) {
        guard let currentUser = AuthManager.shared.currentUser else {
            completion(.failure(NSError(domain: "NetworkService", code: -31, userInfo: [
                NSLocalizedDescriptionKey: "Not authenticated"
            ])))
            return
        }

        guard let u1 = currentUser.username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let u2 = username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = makeURL("/history/\(u1)/\(u2)") else {
            completion(.failure(NSError(domain: "NetworkService", code: -32, userInfo: [
                NSLocalizedDescriptionKey: "Invalid history URL"
            ])))
            return
        }

        let request = authorizedRequest(url: url)

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "NetworkService", code: -33, userInfo: [
                        NSLocalizedDescriptionKey: "Empty history response"
                    ])))
                }
                return
            }

            do {
                let decoded = try self.jsonDecoder.decode(HistoryResponse.self, from: data)

                let messages = decoded.messages
                    .map(self.mapMessage)
                    .sorted { $0.date < $1.date }

                DispatchQueue.main.async {
                    completion(.success(messages))
                }
            } catch {
                let raw = String(data: data, encoding: .utf8) ?? "Unable to decode response"
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "NetworkService", code: -34, userInfo: [
                        NSLocalizedDescriptionKey: "Decoding error: \(error.localizedDescription)\nResponse: \(raw)"
                    ])))
                }
            }
        }.resume()
    }

    func fetchHistory(
        with username: String,
        completion: @escaping (Result<[Message], Error>) -> Void
    ) {
        fetchMessages(with: username, completion: completion)
    }

    func sendMessage(
        to username: String,
        text: String,
        mediaType: MediaType,
        mediaData: String?,
        duration: Double?,
        fileName: String?,
        fileSize: Int?,
        completion: @escaping (Result<Message, Error>) -> Void
    ) {
        guard let url = makeURL("/send") else {
            completion(.failure(NSError(domain: "NetworkService", code: -40, userInfo: [
                NSLocalizedDescriptionKey: "Invalid send message URL"
            ])))
            return
        }

        let requestBody = MessageRequest(
            to: username,
            text: text,
            mediaType: mediaType == .text && mediaData == nil ? nil : mediaType.rawValue,
            mediaData: mediaData,
            duration: duration,
            fileName: fileName,
            fileSize: fileSize,
            attachments: nil
        )

        do {
            let body = try jsonEncoder.encode(requestBody)
            let request = authorizedRequest(url: url, method: "POST", body: body)

            performDecodableRequest(request) { (result: Result<MessageResponse, Error>) in
                switch result {
                case .success(let response):
                    guard response.success, let messageData = response.message else {
                        completion(.failure(NSError(domain: "NetworkService", code: -41, userInfo: [
                            NSLocalizedDescriptionKey: response.error ?? "Failed to send message"
                        ])))
                        return
                    }
                    completion(.success(self.mapMessage(messageData)))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }

    func sendAttachments(
        to username: String,
        text: String,
        mediaType: MediaType,
        attachments: [AttachmentPayload],
        duration: Double?,
        completion: @escaping (Result<Message, Error>) -> Void
    ) {
        guard let url = makeURL("/send") else {
            completion(.failure(NSError(domain: "NetworkService", code: -50, userInfo: [
                NSLocalizedDescriptionKey: "Invalid send attachments URL"
            ])))
            return
        }

        let requestBody = MessageRequest(
            to: username,
            text: text,
            mediaType: mediaType.rawValue,
            mediaData: nil,
            duration: duration,
            fileName: nil,
            fileSize: nil,
            attachments: attachments
        )

        do {
            let body = try jsonEncoder.encode(requestBody)
            let request = authorizedRequest(url: url, method: "POST", body: body)

            performDecodableRequest(request) { (result: Result<MessageResponse, Error>) in
                switch result {
                case .success(let response):
                    guard response.success, let messageData = response.message else {
                        completion(.failure(NSError(domain: "NetworkService", code: -51, userInfo: [
                            NSLocalizedDescriptionKey: response.error ?? "Failed to send attachments"
                        ])))
                        return
                    }
                    completion(.success(self.mapMessage(messageData)))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }

    // MARK: - Media file upload (/send-media)

    func sendMediaFile(
        to username: String,
        mediaType: MediaType,
        fileURL: URL,
        text: String?,
        duration: Double?,
        completion: @escaping (Result<Message, Error>) -> Void
    ) {
        guard let url = makeURL("/send-media") else {
            completion(.failure(NSError(domain: "NetworkService", code: -60, userInfo: [
                NSLocalizedDescriptionKey: "Invalid send-media URL"
            ])))
            return
        }

        guard let fileData = try? Data(contentsOf: fileURL) else {
            completion(.failure(NSError(domain: "NetworkService", code: -61, userInfo: [
                NSLocalizedDescriptionKey: "Failed to read file"
            ])))
            return
        }

        let boundary = "Boundary-\(UUID().uuidString)"

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if let token = AuthManager.shared.token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let fileName = fileURL.lastPathComponent
        let ext = (fileName as NSString).pathExtension.lowercased()
        let mime: String
        if mediaType == .image {
            mime = "image/jpeg"
        } else if mediaType == .video {
            mime = ext == "mov" ? "video/quicktime" : "video/mp4"
        } else {
            mime = "application/octet-stream"
        }

        var body = Data()

        func appendField(name: String, value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        appendField(name: "to", value: username)
        appendField(name: "mediaType", value: mediaType.rawValue)

        if let text = text, !text.isEmpty {
            appendField(name: "text", value: text)
        }

        if let duration = duration {
            appendField(name: "duration", value: String(duration))
        }

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mime)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse,
                  let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "NetworkService", code: -62, userInfo: [
                        NSLocalizedDescriptionKey: "Invalid server response"
                    ])))
                }
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let serverText = String(data: data, encoding: .utf8) ?? "Unknown server error"
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "NetworkService", code: httpResponse.statusCode, userInfo: [
                        NSLocalizedDescriptionKey: serverText
                    ])))
                }
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let success = json["success"] as? Bool,
                   success,
                   let msgData = json["message"] as? [String: Any],
                   let message = self.parseMessageFromAny(msgData) {

                    DispatchQueue.main.async { completion(.success(message)) }
                } else {
                    let errText: String
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let e = json["error"] as? String {
                        errText = e
                    } else {
                        errText = "Failed to send media"
                    }

                    DispatchQueue.main.async {
                        completion(.failure(NSError(domain: "NetworkService", code: -63, userInfo: [
                            NSLocalizedDescriptionKey: errText
                        ])))
                    }
                }
            } catch {
                let raw = String(data: data, encoding: .utf8) ?? "Unable to decode response"
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "NetworkService", code: -64, userInfo: [
                        NSLocalizedDescriptionKey: "Decoding error: \(error.localizedDescription)\nResponse: \(raw)"
                    ])))
                }
            }
        }.resume()
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
        let duration = data["duration"] as? Double
        let fileName = data["fileName"] as? String
        let fileSize = data["fileSize"] as? Int
        let fileId = data["fileId"] as? String
        let downloadUrl = data["downloadUrl"] as? String

        return Message(
            id: id,
            from: from,
            to: to,
            text: text,
            mediaType: mediaType,
            mediaData: mediaData,
            attachments: nil,
            duration: duration,
            fileName: fileName,
            fileSize: fileSize,
            timestamp: timestamp,
            fileId: fileId,
            downloadUrl: downloadUrl
        )
    }
}
