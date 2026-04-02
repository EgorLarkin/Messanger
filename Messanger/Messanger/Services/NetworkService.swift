import Foundation
import Combine

final class NetworkService: ObservableObject {
    static let shared = NetworkService()

    var serverURL: String {
        baseURL
    }

    private let baseURL = "https://messangerserver-1.onrender.com"
    private let session: URLSession

    @Published var isLoading = false
    @Published var errorMessage: String?

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)
    }

    private func request(
        endpoint: String,
        method: String,
        body: [String: Any]? = nil,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
        }

        guard let url = URL(string: baseURL + endpoint) else {
            DispatchQueue.main.async {
                self.isLoading = false
            }
            completion(.failure(URLError(.badURL)))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = AuthManager.shared.token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }

        session.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                self.isLoading = false
            }

            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                }
                completion(.failure(error))
                return
            }

            guard let data = data else {
                let error = NSError(
                    domain: "NetworkService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Empty response data"]
                )
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                }
                completion(.failure(error))
                return
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                let error = NSError(
                    domain: "NetworkService",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid server response"]
                )
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                }
                completion(.failure(error))
                return
            }

            if let errorText = json["error"] as? String, !errorText.isEmpty {
                let error = NSError(
                    domain: "Server",
                    code: -3,
                    userInfo: [NSLocalizedDescriptionKey: errorText]
                )
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                }
                completion(.failure(error))
                return
            }

            completion(.success(json))
        }.resume()
    }

    func register(
        username: String,
        password: String,
        name: String,
        completion: @escaping (Result<AuthResponse, Error>) -> Void
    ) {
        let body: [String: Any] = [
            "username": username,
            "password": password,
            "name": name
        ]

        request(endpoint: "/auth/register", method: "POST", body: body) { result in
            switch result {
            case .success(let json):
                let success = json["success"] as? Bool ?? false
                let token = json["token"] as? String
                let user = (json["user"] as? [String: Any]).flatMap { self.parseUser($0) }
                let error = json["error"] as? String
                completion(.success(AuthResponse(success: success, token: token, user: user, error: error)))

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func login(
        username: String,
        password: String,
        completion: @escaping (Result<AuthResponse, Error>) -> Void
    ) {
        let body: [String: Any] = [
            "username": username,
            "password": password
        ]

        request(endpoint: "/auth/login", method: "POST", body: body) { result in
            switch result {
            case .success(let json):
                let success = json["success"] as? Bool ?? false
                let token = json["token"] as? String
                let user = (json["user"] as? [String: Any]).flatMap { self.parseUser($0) }
                let error = json["error"] as? String
                completion(.success(AuthResponse(success: success, token: token, user: user, error: error)))

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func fetchUsers(
        completion: @escaping (Result<[User], Error>) -> Void
    ) {
        request(endpoint: "/users", method: "GET") { result in
            switch result {
            case .success(let json):
                if let usersData = json["users"] as? [[String: Any]] {
                    completion(.success(usersData.compactMap { self.parseUser($0) }))
                } else {
                    completion(.success([]))
                }

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func searchUsers(
        query: String,
        completion: @escaping (Result<[User], Error>) -> Void
    ) {
        guard !query.isEmpty else {
            completion(.success([]))
            return
        }

        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query

        request(endpoint: "/users/search?q=\(encodedQuery)", method: "GET") { result in
            switch result {
            case .success(let json):
                if let usersData = json["users"] as? [[String: Any]] {
                    completion(.success(usersData.compactMap { self.parseUser($0) }))
                } else {
                    completion(.success([]))
                }

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func fetchConversations(
        completion: @escaping (Result<[Conversation], Error>) -> Void
    ) {
        request(endpoint: "/conversations", method: "GET") { result in
            switch result {
            case .success(let json):
                if let convsData = json["conversations"] as? [[String: Any]] {
                    completion(.success(convsData.compactMap { self.parseConversation($0) }))
                } else if let convsData = json["data"] as? [[String: Any]] {
                    completion(.success(convsData.compactMap { self.parseConversation($0) }))
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
        guard AuthManager.shared.currentUser != nil else {
            completion(.failure(NSError(
                domain: "Auth",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "User is not authenticated"]
            )))
            return
        }

        var body: [String: Any] = [
            "to": to,
            "mediaType": mediaType.rawValue
        ]

        if !text.isEmpty {
            body["text"] = text
        }

        if let mediaData = mediaData {
            body["mediaData"] = mediaData
        }

        if let duration = duration {
            body["duration"] = duration
        }

        if let fileName = fileName {
            body["fileName"] = fileName
        }

        if let fileSize = fileSize {
            body["fileSize"] = fileSize
        }

        request(endpoint: "/send", method: "POST", body: body) { result in
            switch result {
            case .success(let json):
                if let msgData = json["message"] as? [String: Any],
                   let message = self.parseMessage(msgData) {
                    completion(.success(message))
                } else {
                    completion(.failure(NSError(
                        domain: "Message",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to parse sent message"]
                    )))
                }

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func fetchHistory(
        with username: String,
        completion: @escaping (Result<[Message], Error>) -> Void
    ) {
        guard let currentUsername = AuthManager.shared.currentUser?.username else {
            completion(.failure(NSError(
                domain: "Auth",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "User is not authenticated"]
            )))
            return
        }

        fetchHistory(user1: currentUsername, user2: username, completion: completion)
    }

    func fetchHistory(
        user1: String,
        user2: String,
        completion: @escaping (Result<[Message], Error>) -> Void
    ) {
        let encodedUser1 = user1.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? user1
        let encodedUser2 = user2.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? user2

        request(endpoint: "/history/\(encodedUser1)/\(encodedUser2)", method: "GET") { result in
            switch result {
            case .success(let json):
                if let messagesData = json["messages"] as? [[String: Any]] {
                    let messages = messagesData.compactMap { self.parseMessage($0) }
                    completion(.success(messages.sorted { $0.date < $1.date }))
                } else {
                    completion(.success([]))
                }

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func fetchMessages(
        with username: String,
        completion: @escaping (Result<[Message], Error>) -> Void
    ) {
        fetchHistory(with: username, completion: completion)
    }

    func updateProfile(
        name: String,
        completion: @escaping (Result<User, Error>) -> Void
    ) {
        request(endpoint: "/profile", method: "PUT", body: ["name": name]) { result in
            switch result {
            case .success(let json):
                if let userData = json["user"] as? [String: Any],
                   let user = self.parseUser(userData) {
                    AuthManager.shared.updateCurrentUser(user)
                    completion(.success(user))
                } else {
                    completion(.failure(NSError(
                        domain: "Profile",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to update profile"]
                    )))
                }

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func fetchProfile(
        completion: @escaping (Result<User, Error>) -> Void
    ) {
        request(endpoint: "/auth/me", method: "GET") { result in
            switch result {
            case .success(let json):
                if let userData = json["user"] as? [String: Any],
                   let user = self.parseUser(userData) {
                    AuthManager.shared.updateCurrentUser(user)
                    completion(.success(user))
                } else {
                    completion(.failure(NSError(
                        domain: "Profile",
                        code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to fetch profile"]
                    )))
                }

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func uploadAvatar(
        avatarBase64: String,
        completion: @escaping (Result<User, Error>) -> Void
    ) {
        request(endpoint: "/profile/avatar", method: "PUT", body: ["avatar": avatarBase64]) { result in
            switch result {
            case .success(let json):
                if let userData = json["user"] as? [String: Any],
                   let user = self.parseUser(userData) {
                    AuthManager.shared.updateCurrentUser(user)
                    completion(.success(user))
                } else {
                    completion(.failure(NSError(
                        domain: "Avatar",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to upload avatar"]
                    )))
                }

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func deleteAccount(
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
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

    func saveDeviceToken(
        _ token: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        request(
            endpoint: "/notifications/register-token",
            method: "POST",
            body: ["deviceToken": token]
        ) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
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
              let user = parseUser(userData) else {
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
}
