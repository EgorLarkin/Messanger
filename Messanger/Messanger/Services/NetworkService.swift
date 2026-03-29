import Foundation
import Combine

class NetworkService: ObservableObject {
    static let shared = NetworkService()
    
    private let baseURL = "http://192.168.1.65:3000"
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func register(username: String, password: String, name: String, completion: @escaping (Result<User, Error>) -> Void) {
        request(endpoint: "/auth/register", method: "POST", body: ["username": username, "password": password, "name": name]) { result in
            switch result {
            case .success(let response):
                if let token = response["token"] as? String,
                   let userData = response["user"] as? [String: Any],
                   let user = self.parseUser(userData) {
                    AuthManager.shared.saveAuth(token: token, user: user)
                    completion(.success(user))
                } else {
                    completion(.failure(NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Ошибка регистрации"])))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func login(username: String, password: String, completion: @escaping (Result<User, Error>) -> Void) {
        request(endpoint: "/auth/login", method: "POST", body: ["username": username, "password": password]) { result in
            switch result {
            case .success(let response):
                if let token = response["token"] as? String,
                   let userData = response["user"] as? [String: Any],
                   let user = self.parseUser(userData) {
                    AuthManager.shared.saveAuth(token: token, user: user)
                    completion(.success(user))
                } else {
                    completion(.failure(NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Ошибка входа"])))
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
    
    func sendMessage(to: String, text: String, mediaType: MediaType = .text, mediaData: String? = nil, duration: Double? = nil, fileName: String? = nil, fileSize: Int? = nil, completion: @escaping (Result<Message, Error>) -> Void) {
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
                    completion(.failure(NSError(domain: "Profile", code: -1, userInfo: [NSLocalizedDescriptionKey: "Ошибка обновления"])))
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
                    completion(.failure(NSError(domain: "Avatar", code: -1, userInfo: [NSLocalizedDescriptionKey: "Ошибка загрузки аватара"])))
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
        request(endpoint: "/notifications/register-token", method: "POST", body: ["deviceToken": token]) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func request(endpoint: String, method: String, body: [String: Any]? = nil, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        isLoading = true
        guard var url = URL(string: "\(baseURL)\(endpoint)") else {
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
                    completion(.failure(NSError(domain: "Server", code: -1, userInfo: [NSLocalizedDescriptionKey: error])))
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
}
