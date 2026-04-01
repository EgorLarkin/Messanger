import Foundation
import Combine

class NetworkService: ObservableObject {
    static let shared = NetworkService()

    private let baseURL = "https://messangerserver-1.onrender.com"

    var serverURL: String {
        return baseURL
    }

    @Published var isLoading = false
    @Published var errorMessage: String?

    func register(username: String, password: String, name: String, completion: @escaping (Result<User, Error>) -> Void) {
        request(endpoint: "/auth/register", method: "POST", body: [
            "username": username,
            "password": password,
            "name": name
        ]) { result in
            switch result {
            case .success(let response):
                if let token = response["token"] as? String,
                   let userData = response["user"] as? [String: Any],
                   let user = self.parseUser(userData) {
                    AuthManager.shared.saveAuth(token: token, user: user)
                    completion(.success(user))
                } else {
                    completion(.failure(NSError(domain: "Auth", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Ошибка регистрации"
                    ])))
                }

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func login(username: String, password: String, completion: @escaping (Result<User, Error>) -> Void) {
        request(endpoint: "/auth/login", method: "POST", body: [
            "username": username,
            "password": password
        ]) { result in
            switch result {
            case .success(let response):
                if let token = response["token"] as? String,
                   let userData = response["user"] as? [String: Any],
                   let user = self.parseUser(userData) {
                    AuthManager.shared.saveAuth(token: token, user: user)
                    completion(.success(user))
                } else {
                    completion(.failure(NSError(domain: "Auth", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Ошибка входа"
                    ])))
                }

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func fetchUsers(completion: @escaping (Result<[User], Error>) -> Void) {
        request(endpoint: "/users", method: "GET") { result in
            switch result {
            case .success(let response):
                if let usersData = response["users"] as? [[String: Any]] {
                    let users = usersData.compactMap { self.parseUser($0) }
                    completion(.success(users))
                } else {
                    completion(.failure(NSError(domain: "Users", code: -1, userInfo: nil)))
                }

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func searchUsers(query: String, completion: @escaping (Result<[User], Error>) -> Void) {
        guard !query.isEmpty else {
            completion(.success([]))
            return
        }

        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let endpoint = "/users/search?q=\(encodedQuery)"

        request(endpoint: endpoint, method: "GET") { result in
            switch result {
            case .success(let response):
                if let usersData = response["users"] as? [[String: Any]] {
                    let users = usersData.compactMap { self.parseUser($0) }
                    completion(.success(users))
                } else {
                    completion(.success([]))
                }

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func fetchConversations(completion: @escaping (Result<[Conversation], Error>) -> Void) {
        request(endpoint: "/conversations", method: "GET") { result in
            switch result {
            case .success(let response):
                if let convsData = response["conversations"] as? [[String: Any]] {
                    let conversations = convsData.compactMap { self.parseConversation($0) }
                    completion(.success(conversations))
                } else {
                    completion(.success([]))
                }

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func sendMessage(
        to: String,
        text: String,
        mediaType: MediaType = .text,
        mediaData: String? = nil,
        duration: Double? = nil,
        fileName: String? = nil,
        fileSize: Int? = nil,
        completion: @escaping (Result<Message, Error>) -> Void
    ) {
        guard let currentUser = AuthManager.shared.currentUser else {
            completion(.failure(NSError(domain: "Auth", code: -1, userInfo: nil)))
            return
        }

        var body: [String: Any] = ["to": to]

        if mediaType == .text {
            body["text"] = text
            body["mediaType"] = "text"
        } else {
            body["mediaType"] = mediaType.rawValue
            body["mediaData"] = mediaData
            if let duration = duration { body["duration"] = duration }
            if let fileName = fileName { body["fileName"] = fileName }
            if let fileSize = fileSize { body["fileSize"] = fileSize }
            if !text.isEmpty { body["text"] = text }
        }

        print("📤 Sending \(mediaType.rawValue) message from \(currentUser.username) to \(to)")
        if let mediaData = mediaData {
            print("📦 MediaData prefix: \(mediaData.prefix(50))...")
        }

        request(endpoint: "/send", method: "POST", body: body) { result in
            switch result {
            case .success(let response):
                if let msgData = response["message"] as? [String: Any],
                   let message = self.parseMessage(msgData) {
                    completion(.success(message))
                } else {
                    completion(.failure(NSError(domain: "Message", code: -1, userInfo: nil)))
                }

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func fetchHistory(user1: String, user2: String, completion: @escaping (Result<[Message], Error>) -> Void) {
        request(endpoint: "/history/\(user1)/\(user2)", method: "GET") { result in
            switch result {
            case .success(let response):
                if let messagesData = response["messages"] as? [[String: Any]] {
                    let messages = messagesData.compactMap { self.parseMessage($0) }
                    completion(.success(messages))
                } else {
                    completion(.success([]))
                }

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func updateProfile(name: String, completion: @escaping (Result<User, Error>) -> Void) {
        request(endpoint: "/profile", method: "PUT", body: ["name": name]) { result in
            switch result {
            case .success(let response):
                if let userData = response["user"] as? [String: Any],
                   let user = self.parseUser(userData) {
                    AuthManager.shared.updateCurrentUser(user)
                    completion(.success(user))
                } else {
                    completion(.failure(NSError(domain: "Profile", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Ошибка обновления"
                    ])))
                }

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func uploadAvatar(avatarBase64: String, completion: @escaping (Result<User, Error>) -> Void) {
        request(endpoint: "/profile/avatar", method: "PUT", body: ["avatar": avatarBase64]) { result in
            switch result {
            case .success(let response):
                if let userData = response["user"] as? [String: Any],
                   let user = self.parseUser(userData) {
                    AuthManager.shared.updateCurrentUser(user)
                    completion(.success(user))
                } else {
                    completion(.failure(NSError(domain: "Avatar", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Ошибка загрузки аватара"
                    ])))
                }

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func deleteAccount(completion: @escaping (Result<Void, Error>) -> Void) {
        request(endpoint: "/profile", method: "DELETE", body: nil) { result in
            switch result {
            case .success:
                AuthManager.shared.deleteAccount()
                completion(.success(()))

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func saveDeviceToken(_ token: String, completion: @escaping (Result<Void, Error>) -> Void) {
        request(endpoint: "/notifications/register-token", method: "POST", body: [
            "deviceToken": token
        ]) { result in
            switch result {
            case .success:
                completion(.success(()))

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func request(
        endpoint: String,
        method: String,
        body: [String: Any]? = nil,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        isLoading = true

        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            completion(.failure(URLError(.badURL)))
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = AuthManager.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false

                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    completion(.failure(NSError(domain: "Parse", code: -1, userInfo: nil)))
                    return
                }

                if let error = json["error"] as? String {
                    completion(.failure(NSError(domain: "Server", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: error
                    ])))
                    return
                }

                completion(.success(json))
            }
        }.resume()
    }

    func parseUser(_ data: [String: Any]) -> User? {
        guard let id = data["id"] as? String,
              let username = data["username"] as? String,
              let name = data["name"] as? String else {
            return nil
        }

        let avatar = data["avatar"] as? String
        return User(id: id, username: username, name: name, avatar: avatar)
    }

    func parseMessage(_ data: [String: Any]) -> Message? {
        guard let id = data["id"] as? String,
              let from = data["from"] as? String,
              let to = data["to"] as? String,
              let text = data["text"] as? String,
              let mediaType = data["mediaType"] as? String,
              let timestamp = data["timestamp"] as? String else {
            return nil
        }

        return Message(
            id: id,
            from: from,
            to: to,
            text: text,
            mediaType: mediaType,
            mediaData: data["mediaData"] as? String,
            duration: data["duration"] as? Double,
            fileName: data["fileName"] as? String,
            fileSize: data["fileSize"] as? Int,
            timestamp: timestamp
        )
    }

    func parseConversation(_ data: [String: Any]) -> Conversation? {
        guard let chatWith = data["chatWith"] as? String,
              let lastMessage = data["lastMessage"] as? String,
              let timestamp = data["timestamp"] as? String,
              let unreadCount = data["unreadCount"] as? Int,
              let userData = data["user"] as? [String: Any],
              let user = self.parseUser(userData) else {
            return nil
        }

        return Conversation(
            chatWith: chatWith,
            lastMessage: lastMessage,
            timestamp: timestamp,
            unreadCount: unreadCount,
            user: user,
            lastMessageType: data["lastMessageType"] as? String
        )
    }
    
    func uploadMedia(
        data: Data,
        fileName: String,
        mimeType: String,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        guard let token = AuthManager.shared.token else {
            completion(.failure(NSError(
                domain: "Auth",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Нет токена авторизации"]
            )))
            return
        }

        guard let url = URL(string: "\(baseURL)/upload") else {
            completion(.failure(NSError(
                domain: "URL",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Некорректный URL"]
            )))
            return
        }

        let boundary = "Boundary-\(UUID().uuidString)"

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        URLSession.shared.uploadTask(with: request, from: body) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    completion(.failure(NSError(
                        domain: "Parse",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Ошибка разбора ответа"]
                    )))
                    return
                }

                if let errorText = json["error"] as? String {
                    completion(.failure(NSError(
                        domain: "Server",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: errorText]
                    )))
                    return
                }

                completion(.success(json))
            }
        }.resume()
    }

    func uploadMedia(
        to: String,
        text: String,
        mediaType: MediaType,
        mediaData: String,
        fileName: String?,
        fileSize: Int?,
        completion: @escaping (Result<Message, Error>) -> Void
    ) {
        sendMessage(
            to: to,
            text: text,
            mediaType: mediaType,
            mediaData: mediaData,
            duration: nil,
            fileName: fileName,
            fileSize: fileSize,
            completion: completion
        )
    }
    
    func uploadMedia(
        to: String,
        mediaType: MediaType,
        mediaData: String,
        fileName: String?,
        fileSize: Int?,
        completion: @escaping (Result<Message, Error>) -> Void
    ) {
        sendMessage(
            to: to,
            text: "",
            mediaType: mediaType,
            mediaData: mediaData,
            duration: nil,
            fileName: fileName,
            fileSize: fileSize,
            completion: completion
        )
    }
    
    func uploadMedia(
        to: String,
        fileURL: URL,
        mediaType: MediaType,
        text: String,
        duration: Double?,
        completion: @escaping (Result<Message, Error>) -> Void
    ) {
        do {
            let data = try Data(contentsOf: fileURL)
            let fileName = fileURL.lastPathComponent
            let fileSize = data.count

            let mimeType: String
            switch mediaType {
            case .video, .videoNote:
                mimeType = "video/mp4"
            case .voice:
                mimeType = "audio/m4a"
            case .image:
                mimeType = "image/jpeg"
            case .file:
                mimeType = "application/octet-stream"
            case .text:
                mimeType = "application/octet-stream"
            }

            let base64 = "\(mimeType);base64," + data.base64EncodedString()

            sendMessage(
                to: to,
                text: text,
                mediaType: mediaType,
                mediaData: base64,
                duration: duration,
                fileName: fileName,
                fileSize: fileSize,
                completion: completion
            )
        } catch {
            completion(.failure(error))
        }
    }
}
