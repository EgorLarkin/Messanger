import Foundation
import UIKit
import Combine

class NetworkService: ObservableObject {
    static let shared = NetworkService()

    private let baseURL = "https://messangerserver-1.onrender.com"

    var serverURL: String {
        baseURL
    }

    @Published var isLoading = false
    @Published var errorMessage: String?

    private init() {}

    private func makeRequest(path: String, method: String = "GET") -> URLRequest? {
        guard let url = URL(string: baseURL + path) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = method

        if let token = AuthManager.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    private func request(
        endpoint: String,
        method: String,
        body: [String: Any]? = nil,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        isLoading = true

        guard var request = makeRequest(path: endpoint, method: method) else {
            isLoading = false
            completion(.failure(URLError(.badURL)))
            return
        }

        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = body {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                isLoading = false
                completion(.failure(error))
                return
            }
        }

        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                self.isLoading = false

                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    completion(.failure(NSError(domain: "Parse", code: -1, userInfo: [NSLocalizedDescriptionKey: "Ошибка ответа сервера"])))
                    return
                }

                if let errorMessage = json["error"] as? String {
                    completion(.failure(NSError(domain: "Server", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                    return
                }

                completion(.success(json))
            }
        }.resume()
    }

    // MARK: - Auth

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
                    completion(.failure(NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Ошибка регистрации"])))
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
                    completion(.failure(NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Ошибка входа"])))
                }

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - Users

    func fetchUsers(completion: @escaping (Result<[User], Error>) -> Void) {
        request(endpoint: "/users", method: "GET") { result in
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

    func searchUsers(query: String, completion: @escaping (Result<[User], Error>) -> Void) {
        guard !query.isEmpty else {
            completion(.success([]))
            return
        }

        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        request(endpoint: "/users/search?q=\(encodedQuery)", method: "GET") { result in
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

    // MARK: - Conversations

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

    // MARK: - Messages

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
        var body: [String: Any] = [
            "to": to,
            "text": text
        ]

        if mediaType != .text {
            body["mediaType"] = mediaType.rawValue
            body["mediaData"] = mediaData
            if let duration = duration { body["duration"] = duration }
            if let fileName = fileName { body["fileName"] = fileName }
            if let fileSize = fileSize { body["fileSize"] = fileSize }
        }

        request(endpoint: "/send", method: "POST", body: body) { result in
            switch result {
            case .success(let response):
                if let msgData = response["message"] as? [String: Any],
                   let message = self.parseMessage(msgData) {
                    completion(.success(message))
                } else {
                    completion(.failure(NSError(domain: "Message", code: -1, userInfo: [NSLocalizedDescriptionKey: "Ошибка отправки сообщения"])))
                }

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func sendMediaMessage(
        to: String,
        fileURL: URL,
        mediaType: MediaType,
        text: String = "",
        duration: Double? = nil,
        completion: @escaping (Result<Message, Error>) -> Void
    ) {
        guard var request = makeRequest(path: "/send-media", method: "POST") else {
            completion(.failure(URLError(.badURL)))
            return
        }

        request.timeoutInterval = 600

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        do {
            let tempBodyURL = try createMultipartTempFile(
                boundary: boundary,
                to: to,
                text: text,
                mediaType: mediaType.rawValue,
                duration: duration,
                fileURL: fileURL,
                fileName: fileURL.lastPathComponent,
                mimeType: mimeType(for: fileURL, mediaType: mediaType)
            )

            URLSession.shared.uploadTask(with: request, fromFile: tempBodyURL) { data, _, error in
                try? FileManager.default.removeItem(at: tempBodyURL)
                self.handleMessageResponse(data: data, error: error, completion: completion)
            }.resume()
        } catch {
            completion(.failure(error))
        }
    }

    private func createMultipartTempFile(
        boundary: String,
        to: String,
        text: String,
        mediaType: String,
        duration: Double?,
        fileURL: URL,
        fileName: String,
        mimeType: String
    ) throws -> URL {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".multipart")
        FileManager.default.createFile(atPath: tempURL.path, contents: nil)

        let handle = try FileHandle(forWritingTo: tempURL)

        func write(_ string: String) throws {
            if let data = string.data(using: .utf8) {
                try handle.write(contentsOf: data)
            }
        }

        try write("--\(boundary)\r\n")
        try write("Content-Disposition: form-data; name=\"to\"\r\n\r\n")
        try write("\(to)\r\n")

        try write("--\(boundary)\r\n")
        try write("Content-Disposition: form-data; name=\"text\"\r\n\r\n")
        try write("\(text)\r\n")

        try write("--\(boundary)\r\n")
        try write("Content-Disposition: form-data; name=\"mediaType\"\r\n\r\n")
        try write("\(mediaType)\r\n")

        if let duration = duration {
            try write("--\(boundary)\r\n")
            try write("Content-Disposition: form-data; name=\"duration\"\r\n\r\n")
            try write("\(duration)\r\n")
        }

        try write("--\(boundary)\r\n")
        try write("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n")
        try write("Content-Type: \(mimeType)\r\n\r\n")

        let fileData = try Data(contentsOf: fileURL)
        try handle.write(contentsOf: fileData)

        try write("\r\n")
        try write("--\(boundary)--\r\n")
        try handle.close()

        return tempURL
    }
    
    func downloadFile(from remoteURL: String, fileName: String, completion: @escaping (Result<URL, Error>) -> Void) {
        guard let url = URL(string: remoteURL) else {
            completion(.failure(URLError(.badURL)))
            return
        }

        var request = URLRequest(url: url)
        if let token = AuthManager.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        URLSession.shared.downloadTask(with: request) { tempURL, _, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard let tempURL = tempURL else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "Download", code: -1, userInfo: [NSLocalizedDescriptionKey: "Файл не скачан"])))
                }
                return
            }

            let destination = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

            do {
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.copyItem(at: tempURL, to: destination)

                DispatchQueue.main.async {
                    completion(.success(destination))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }

    private func handleMessageResponse(
        data: Data?,
        error: Error?,
        completion: @escaping (Result<Message, Error>) -> Void
    ) {
        if let error = error {
            DispatchQueue.main.async {
                completion(.failure(error))
            }
            return
        }

        guard let data = data else {
            DispatchQueue.main.async {
                completion(.failure(NSError(domain: "NetworkService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Пустой ответ сервера"])))
            }
            return
        }

        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let messageData = json["message"] as? [String: Any],
                  let message = self.parseMessage(messageData) else {
                throw NSError(domain: "ParseError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Ошибка разбора сообщения"])
            }

            DispatchQueue.main.async {
                completion(.success(message))
            }
        } catch {
            DispatchQueue.main.async {
                completion(.failure(error))
            }
        }
    }

    private func createMultipartBody(
        boundary: String,
        to: String,
        text: String,
        mediaType: String,
        duration: Double?,
        fileData: Data,
        fileName: String,
        mimeType: String
    ) -> Data {
        var body = Data()

        func append(_ string: String) {
            body.append(string.data(using: .utf8)!)
        }

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"to\"\r\n\r\n")
        append("\(to)\r\n")

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"text\"\r\n\r\n")
        append("\(text)\r\n")

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"mediaType\"\r\n\r\n")
        append("\(mediaType)\r\n")

        if let duration = duration {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"duration\"\r\n\r\n")
            append("\(duration)\r\n")
        }

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n")
        append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(fileData)
        append("\r\n")

        append("--\(boundary)--\r\n")
        return body
    }

    private func mimeType(for url: URL, mediaType: MediaType) -> String {
        let ext = url.pathExtension.lowercased()

        switch mediaType {
        case .image:
            switch ext {
            case "png": return "image/png"
            case "heic": return "image/heic"
            case "gif": return "image/gif"
            default: return "image/jpeg"
            }

        case .video:
            switch ext {
            case "mov": return "video/quicktime"
            case "m4v": return "video/x-m4v"
            case "avi": return "video/x-msvideo"
            case "mkv": return "video/x-matroska"
            default: return "video/mp4"
            }

        default:
            return "application/octet-stream"
        }
    }

    // MARK: - Profile

    func updateProfile(name: String, completion: @escaping (Result<User, Error>) -> Void) {
        request(endpoint: "/profile", method: "PUT", body: ["name": name]) { result in
            switch result {
            case .success(let response):
                if let userData = response["user"] as? [String: Any],
                   let user = self.parseUser(userData) {
                    AuthManager.shared.updateCurrentUser(user)
                    completion(.success(user))
                } else {
                    completion(.failure(NSError(domain: "Profile", code: -1, userInfo: [NSLocalizedDescriptionKey: "Ошибка обновления профиля"])))
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

    // MARK: - Parsing

    func parseUser(_ data: [String: Any]) -> User? {
        guard let id = data["id"] as? String,
              let username = data["username"] as? String,
              let name = data["name"] as? String else {
            return nil
        }

        return User(
            id: id,
            username: username,
            name: name,
            avatar: data["avatar"] as? String
        )
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
            fileId: data["fileId"] as? String,
            downloadUrl: data["downloadUrl"] as? String,
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
