import Foundation
import AVFoundation
import Combine
import UIKit

final class NetworkService: ObservableObject {
    static let shared = NetworkService()

    @Published var conversations: [Conversation] = []
    @Published var users: [User] = []

    private let baseURL = "https://messangerserver-1.onrender.com"
    private init() {}

    private var authToken: String? {
        AuthManager.shared.token
    }

    private func makeRequest(
        path: String,
        method: String = "GET",
        contentType: String = "application/json"
    ) -> URLRequest? {
        guard let url = URL(string: baseURL + path) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")

        if let token = authToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    private func decodeError(from data: Data?) -> Error {
        guard
            let data,
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let errorMessage = json["error"] as? String
        else {
            return NSError(domain: "NetworkService", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Неизвестная ошибка"
            ])
        }

        return NSError(domain: "NetworkService", code: -1, userInfo: [
            NSLocalizedDescriptionKey: errorMessage
        ])
    }

    // MARK: - Users / Conversations / History

    func fetchUsers(completion: @escaping (Result<[User], Error>) -> Void) {
        guard let request = makeRequest(path: "/users") else {
            completion(.failure(NSError(domain: "NetworkService", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Некорректный URL"
            ])))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "NetworkService", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Некорректный ответ сервера"
                ])))
                return
            }

            guard (200...299).contains(httpResponse.statusCode), let data else {
                completion(.failure(self.decodeError(from: data)))
                return
            }

            do {
                let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
                DispatchQueue.main.async {
                    self.users = decoded.users
                }
                completion(.success(decoded.users))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func searchUsers(query: String, completion: @escaping (Result<[User], Error>) -> Void) {
        guard
            let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let request = makeRequest(path: "/users/search?q=\(encodedQuery)")
        else {
            completion(.failure(NSError(domain: "NetworkService", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Некорректный URL"
            ])))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "NetworkService", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Некорректный ответ сервера"
                ])))
                return
            }

            guard (200...299).contains(httpResponse.statusCode), let data else {
                completion(.failure(self.decodeError(from: data)))
                return
            }

            do {
                let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
                completion(.success(decoded.users))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func fetchConversations(completion: @escaping (Result<[Conversation], Error>) -> Void) {
        guard let request = makeRequest(path: "/conversations") else {
            completion(.failure(NSError(domain: "NetworkService", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Некорректный URL"
            ])))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "NetworkService", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Некорректный ответ сервера"
                ])))
                return
            }

            guard (200...299).contains(httpResponse.statusCode), let data else {
                completion(.failure(self.decodeError(from: data)))
                return
            }

            do {
                let decoded = try JSONDecoder().decode(ConversationsResponse.self, from: data)
                DispatchQueue.main.async {
                    self.conversations = decoded.conversations
                }
                completion(.success(decoded.conversations))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func fetchHistory(with username: String, completion: @escaping (Result<[Message], Error>) -> Void) {
        guard let currentUsername = AuthManager.shared.currentUser?.username else {
            completion(.failure(NSError(domain: "NetworkService", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Пользователь не авторизован"
            ])))
            return
        }

        guard let request = makeRequest(path: "/history/\(currentUsername)/\(username)") else {
            completion(.failure(NSError(domain: "NetworkService", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Некорректный URL"
            ])))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "NetworkService", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Некорректный ответ сервера"
                ])))
                return
            }

            guard (200...299).contains(httpResponse.statusCode), let data else {
                completion(.failure(self.decodeError(from: data)))
                return
            }

            do {
                let decoded = try JSONDecoder().decode(HistoryResponse.self, from: data)
                let messages = decoded.messages.map { item in
                    Message(
                        id: item.id,
                        from: item.from,
                        to: item.to,
                        text: item.text,
                        mediaType: item.mediaType,
                        mediaData: item.mediaData,
                        attachments: item.attachments,
                        duration: item.duration,
                        fileName: item.fileName,
                        fileSize: item.fileSize,
                        timestamp: item.timestamp,
                        fileId: item.fileId,
                        downloadUrl: item.downloadUrl
                    )
                }
                completion(.success(messages))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    // MARK: - Profile

    func fetchProfile(
        completion: @escaping (Result<User, Error>) -> Void
    ) {
        guard let request = makeRequest(path: "/auth/verify") else {
            completion(.failure(NSError(domain: "NetworkService", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Некорректный URL профиля"
            ])))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "NetworkService", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Некорректный ответ сервера"
                ])))
                return
            }

            guard (200...299).contains(httpResponse.statusCode), let data else {
                completion(.failure(self.decodeError(from: data)))
                return
            }

            do {
                let decoded = try JSONDecoder().decode(ProfileVerifyResponse.self, from: data)
                if let user = decoded.user {
                    DispatchQueue.main.async {
                        AuthManager.shared.currentUser = user
                    }
                    completion(.success(user))
                } else {
                    completion(.failure(NSError(domain: "NetworkService", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Профиль не найден"
                    ])))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func updateProfile(
        name: String,
        completion: @escaping (Result<User, Error>) -> Void
    ) {
        guard var request = makeRequest(path: "/profile", method: "PUT") else {
            completion(.failure(NSError(domain: "NetworkService", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Некорректный URL обновления профиля"
            ])))
            return
        }

        let payload = ProfileUpdateRequest(name: name)

        do {
            request.httpBody = try JSONEncoder().encode(payload)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "NetworkService", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Некорректный ответ сервера"
                ])))
                return
            }

            guard (200...299).contains(httpResponse.statusCode), let data else {
                completion(.failure(self.decodeError(from: data)))
                return
            }

            do {
                let decoded = try JSONDecoder().decode(ProfileUpdateResponse.self, from: data)
                guard decoded.success, let user = decoded.user else {
                    completion(.failure(NSError(domain: "NetworkService", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: decoded.error ?? "Не удалось обновить профиль"
                    ])))
                    return
                }

                DispatchQueue.main.async {
                    AuthManager.shared.currentUser = user
                }
                completion(.success(user))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func deleteAccount(
        completion: @escaping (Result<Bool, Error>) -> Void
    ) {
        guard let request = makeRequest(path: "/profile", method: "DELETE") else {
            completion(.failure(NSError(domain: "NetworkService", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Некорректный URL удаления профиля"
            ])))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "NetworkService", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Некорректный ответ сервера"
                ])))
                return
            }

            if (200...299).contains(httpResponse.statusCode) {
                completion(.success(true))
            } else {
                let serverText = data.flatMap { String(data: $0, encoding: .utf8) } ?? "Не удалось удалить аккаунт"
                completion(.failure(NSError(domain: "NetworkService", code: httpResponse.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: serverText
                ])))
            }
        }.resume()
    }

    // MARK: - Messages / Media

    func sendMessage(
        to: String,
        text: String?,
        mediaType: MediaType,
        mediaData: String?,
        duration: Double?,
        fileName: String?,
        fileSize: Int?,
        completion: @escaping (Result<Message, Error>) -> Void
    ) {
        guard var request = makeRequest(path: "/send", method: "POST") else {
            completion(.failure(NSError(domain: "NetworkService", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Некорректный URL"
            ])))
            return
        }

        let payload = MessageRequest(
            to: to,
            text: text,
            mediaType: mediaType.rawValue,
            mediaData: mediaData,
            duration: duration,
            fileName: fileName,
            fileSize: fileSize,
            attachments: nil
        )

        do {
            request.httpBody = try JSONEncoder().encode(payload)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "NetworkService", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Некорректный ответ сервера"
                ])))
                return
            }

            guard (200...299).contains(httpResponse.statusCode), let data else {
                completion(.failure(self.decodeError(from: data)))
                return
            }

            do {
                let decoded = try JSONDecoder().decode(MessageResponse.self, from: data)
                guard let item = decoded.message else {
                    completion(.failure(NSError(domain: "NetworkService", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: decoded.error ?? "Сообщение не получено"
                    ])))
                    return
                }

                let message = Message(
                    id: item.id,
                    from: item.from,
                    to: item.to,
                    text: item.text,
                    mediaType: item.mediaType,
                    mediaData: item.mediaData,
                    attachments: item.attachments,
                    duration: item.duration,
                    fileName: item.fileName,
                    fileSize: item.fileSize,
                    timestamp: item.timestamp,
                    fileId: item.fileId,
                    downloadUrl: item.downloadUrl
                )

                completion(.success(message))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func sendAttachments(
        to: String,
        text: String?,
        mediaType: MediaType,
        attachments: [AttachmentPayload],
        duration: Double?,
        completion: @escaping (Result<Message, Error>) -> Void
    ) {
        guard var request = makeRequest(path: "/send", method: "POST") else {
            completion(.failure(NSError(domain: "NetworkService", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Некорректный URL"
            ])))
            return
        }

        let payload = MessageRequest(
            to: to,
            text: text,
            mediaType: mediaType.rawValue,
            mediaData: nil,
            duration: duration,
            fileName: nil,
            fileSize: nil,
            attachments: attachments
        )

        do {
            request.httpBody = try JSONEncoder().encode(payload)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "NetworkService", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Некорректный ответ сервера"
                ])))
                return
            }

            guard (200...299).contains(httpResponse.statusCode), let data else {
                completion(.failure(self.decodeError(from: data)))
                return
            }

            do {
                let decoded = try JSONDecoder().decode(MessageResponse.self, from: data)
                guard let item = decoded.message else {
                    completion(.failure(NSError(domain: "NetworkService", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: decoded.error ?? "Сообщение не получено"
                    ])))
                    return
                }

                let message = Message(
                    id: item.id,
                    from: item.from,
                    to: item.to,
                    text: item.text,
                    mediaType: item.mediaType,
                    mediaData: item.mediaData,
                    attachments: item.attachments,
                    duration: item.duration,
                    fileName: item.fileName,
                    fileSize: item.fileSize,
                    timestamp: item.timestamp,
                    fileId: item.fileId,
                    downloadUrl: item.downloadUrl
                )

                completion(.success(message))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func sendMediaFile(
        to: String,
        mediaType: MediaType,
        fileURL: URL,
        text: String?,
        duration: Double?,
        completion: @escaping (Result<Message, Error>) -> Void
    ) {
        guard let url = URL(string: baseURL + "/send-media") else {
            completion(.failure(NSError(domain: "NetworkService", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Некорректный URL"
            ])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        if let token = authToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        do {
            let fileData = try Data(contentsOf: fileURL)
            let body = createMultipartBody(
                boundary: boundary,
                fields: [
                    "to": to,
                    "mediaType": mediaType.rawValue,
                    "text": text ?? "",
                    "duration": duration.map { String($0) } ?? ""
                ],
                files: [
                    MultipartFile(
                        fieldName: "file",
                        fileName: fileURL.lastPathComponent,
                        mimeType: mimeType(for: fileURL),
                        data: fileData
                    )
                ]
            )

            request.httpBody = body
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "NetworkService", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Некорректный ответ сервера"
                ])))
                return
            }

            guard (200...299).contains(httpResponse.statusCode), let data else {
                completion(.failure(self.decodeError(from: data)))
                return
            }

            do {
                let decoded = try JSONDecoder().decode(MessageResponse.self, from: data)
                guard let item = decoded.message else {
                    completion(.failure(NSError(domain: "NetworkService", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: decoded.error ?? "Сообщение не получено"
                    ])))
                    return
                }

                let message = Message(
                    id: item.id,
                    from: item.from,
                    to: item.to,
                    text: item.text,
                    mediaType: item.mediaType,
                    mediaData: item.mediaData,
                    attachments: item.attachments,
                    duration: item.duration,
                    fileName: item.fileName,
                    fileSize: item.fileSize,
                    timestamp: item.timestamp,
                    fileId: item.fileId,
                    downloadUrl: item.downloadUrl
                )

                completion(.success(message))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func sendMediaFilesGroup(
        to: String,
        mediaType: MediaType,
        fileURLs: [URL],
        caption: String,
        durations: [Double?],
        completion: @escaping (Result<Message, Error>) -> Void
    ) {
        guard let url = URL(string: baseURL + "/send-media-group") else {
            completion(.failure(NSError(domain: "NetworkService", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Некорректный URL"
            ])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        if let token = authToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        do {
            let files: [MultipartFile] = try fileURLs.map { fileURL in
                MultipartFile(
                    fieldName: "files",
                    fileName: fileURL.lastPathComponent,
                    mimeType: mimeType(for: fileURL),
                    data: try Data(contentsOf: fileURL)
                )
            }

            let durationsJSONString = try String(
                data: JSONSerialization.data(withJSONObject: durations.map { $0 as Any }),
                encoding: .utf8
            ) ?? "[]"

            let body = createMultipartBody(
                boundary: boundary,
                fields: [
                    "to": to,
                    "mediaType": mediaType.rawValue,
                    "text": caption,
                    "durations": durationsJSONString
                ],
                files: files
            )

            request.httpBody = body
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "NetworkService", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Некорректный ответ сервера"
                ])))
                return
            }

            guard (200...299).contains(httpResponse.statusCode), let data else {
                completion(.failure(self.decodeError(from: data)))
                return
            }

            do {
                let decoded = try JSONDecoder().decode(MessageResponse.self, from: data)
                guard let item = decoded.message else {
                    completion(.failure(NSError(domain: "NetworkService", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: decoded.error ?? "Сообщение не получено"
                    ])))
                    return
                }

                let message = Message(
                    id: item.id,
                    from: item.from,
                    to: item.to,
                    text: item.text,
                    mediaType: item.mediaType,
                    mediaData: item.mediaData,
                    attachments: item.attachments,
                    duration: item.duration,
                    fileName: item.fileName,
                    fileSize: item.fileSize,
                    timestamp: item.timestamp,
                    fileId: item.fileId,
                    downloadUrl: item.downloadUrl
                )

                completion(.success(message))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func sendMixedMediaGroup(
        to: String,
        items: [PendingMediaItem],
        caption: String,
        completion: @escaping (Result<Message, Error>) -> Void
    ) {
        guard let url = URL(string: baseURL + "/send-media-mixed-group") else {
            completion(.failure(NSError(domain: "NetworkService", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Некорректный URL"
            ])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        if let token = authToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        do {
            var multipartFiles: [MultipartFile] = []
            var durations: [Any] = []
            var itemTypes: [String] = []

            for (index, item) in items.enumerated() {
                if let image = item.image,
                   let imageData = image.jpegData(compressionQuality: 0.85) {
                    multipartFiles.append(
                        MultipartFile(
                            fieldName: "files",
                            fileName: item.fileName.isEmpty ? "image_\(index).jpg" : item.fileName,
                            mimeType: "image/jpeg",
                            data: imageData
                        )
                    )
                    durations.append(NSNull())
                    itemTypes.append(MediaType.image.rawValue)
                    continue
                }

                if let videoURL = item.videoURL {
                    let data = try Data(contentsOf: videoURL)
                    multipartFiles.append(
                        MultipartFile(
                            fieldName: "files",
                            fileName: item.fileName.isEmpty ? videoURL.lastPathComponent : item.fileName,
                            mimeType: mimeType(for: videoURL),
                            data: data
                        )
                    )

                    let asset = AVURLAsset(url: videoURL)
                    let seconds = CMTimeGetSeconds(asset.duration)
                    if seconds.isFinite && !seconds.isNaN {
                        durations.append(seconds)
                    } else {
                        durations.append(NSNull())
                    }

                    itemTypes.append(MediaType.video.rawValue)
                    continue
                }

                if let fileURL = item.fileURL {
                    let data = try Data(contentsOf: fileURL)
                    multipartFiles.append(
                        MultipartFile(
                            fieldName: "files",
                            fileName: item.fileName.isEmpty ? fileURL.lastPathComponent : item.fileName,
                            mimeType: mimeType(for: fileURL),
                            data: data
                        )
                    )
                    durations.append(NSNull())
                    itemTypes.append(MediaType.file.rawValue)
                    continue
                }
            }

            guard !multipartFiles.isEmpty else {
                completion(.failure(NSError(domain: "NetworkService", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Нет файлов для отправки"
                ])))
                return
            }

            let durationsJSONString = try String(
                data: JSONSerialization.data(withJSONObject: durations),
                encoding: .utf8
            ) ?? "[]"

            let itemTypesJSONString = try String(
                data: JSONSerialization.data(withJSONObject: itemTypes),
                encoding: .utf8
            ) ?? "[]"

            let body = createMultipartBody(
                boundary: boundary,
                fields: [
                    "to": to,
                    "text": caption,
                    "durations": durationsJSONString,
                    "itemTypes": itemTypesJSONString
                ],
                files: multipartFiles
            )

            request.httpBody = body
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "NetworkService", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Некорректный ответ сервера"
                ])))
                return
            }

            guard (200...299).contains(httpResponse.statusCode), let data else {
                completion(.failure(self.decodeError(from: data)))
                return
            }

            do {
                let decoded = try JSONDecoder().decode(MessageResponse.self, from: data)
                guard let item = decoded.message else {
                    completion(.failure(NSError(domain: "NetworkService", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: decoded.error ?? "Сообщение не получено"
                    ])))
                    return
                }

                let message = Message(
                    id: item.id,
                    from: item.from,
                    to: item.to,
                    text: item.text,
                    mediaType: item.mediaType,
                    mediaData: item.mediaData,
                    attachments: item.attachments,
                    duration: item.duration,
                    fileName: item.fileName,
                    fileSize: item.fileSize,
                    timestamp: item.timestamp,
                    fileId: item.fileId,
                    downloadUrl: item.downloadUrl
                )

                completion(.success(message))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    // MARK: - Multipart helpers

    private struct MultipartFile {
        let fieldName: String
        let fileName: String
        let mimeType: String
        let data: Data
    }

    private func createMultipartBody(
        boundary: String,
        fields: [String: String],
        files: [MultipartFile]
    ) -> Data {
        var body = Data()

        for (key, value) in fields {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.append("\(value)\r\n")
        }

        for file in files {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(file.fieldName)\"; filename=\"\(file.fileName)\"\r\n")
            body.append("Content-Type: \(file.mimeType)\r\n\r\n")
            body.append(file.data)
            body.append("\r\n")
        }

        body.append("--\(boundary)--\r\n")
        return body
    }

    private func mimeType(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()

        switch ext {
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "webp":
            return "image/webp"
        case "heic":
            return "image/heic"
        case "mp4":
            return "video/mp4"
        case "mov":
            return "video/quicktime"
        case "m4v":
            return "video/x-m4v"
        case "mp3":
            return "audio/mpeg"
        case "m4a":
            return "audio/mp4"
        case "pdf":
            return "application/pdf"
        case "txt":
            return "text/plain"
        case "doc":
            return "application/msword"
        case "docx":
            return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        default:
            return "application/octet-stream"
        }
    }
    
    func uploadAvatar(
        avatarBase64: String,
        completion: @escaping (Result<User, Error>) -> Void
    ) {
        guard var request = makeRequest(path: "/profile/avatar", method: "PUT") else {
            completion(.failure(NSError(domain: "NetworkService", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Некорректный URL загрузки аватара"
            ])))
            return
        }

        let payload: [String: String] = [
            "avatar": avatarBase64
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "NetworkService", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Некорректный ответ сервера"
                ])))
                return
            }

            guard (200...299).contains(httpResponse.statusCode), let data else {
                completion(.failure(self.decodeError(from: data)))
                return
            }

            do {
                let decoded = try JSONDecoder().decode(ProfileUpdateResponse.self, from: data)
                guard decoded.success, let user = decoded.user else {
                    completion(.failure(NSError(domain: "NetworkService", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: decoded.error ?? "Не удалось загрузить аватар"
                    ])))
                    return
                }

                DispatchQueue.main.async {
                    AuthManager.shared.currentUser = user
                }
                completion(.success(user))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func register(
            username: String,
            password: String,
            name: String,
            completion: @escaping (Result<AuthResponse, Error>) -> Void
        ) {
            guard var request = makeRequest(path: "/auth/register", method: "POST") else {
                completion(.failure(NSError(domain: "NetworkService", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Некорректный URL регистрации"
                ])))
                return
            }

            let payload: [String: String] = [
                "username": username,
                "password": password,
                "name": name
            ]

            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            } catch {
                completion(.failure(error))
                return
            }

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error {
                    completion(.failure(error))
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(NSError(domain: "NetworkService", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Некорректный ответ сервера"
                    ])))
                    return
                }

                guard (200...299).contains(httpResponse.statusCode), let data else {
                    completion(.failure(self.decodeError(from: data)))
                    return
                }

                do {
                    let decoded = try JSONDecoder().decode(AuthResponse.self, from: data)
                    completion(.success(decoded))
                } catch {
                    completion(.failure(error))
                }
            }.resume()
        }

        func login(
            username: String,
            password: String,
            completion: @escaping (Result<AuthResponse, Error>) -> Void
        ) {
            guard var request = makeRequest(path: "/auth/login", method: "POST") else {
                completion(.failure(NSError(domain: "NetworkService", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Некорректный URL входа"
                ])))
                return
            }

            let payload: [String: String] = [
                "username": username,
                "password": password
            ]

            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            } catch {
                completion(.failure(error))
                return
            }

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error {
                    completion(.failure(error))
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(NSError(domain: "NetworkService", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Некорректный ответ сервера"
                    ])))
                    return
                }

                guard (200...299).contains(httpResponse.statusCode), let data else {
                    completion(.failure(self.decodeError(from: data)))
                    return
                }

                do {
                    let decoded = try JSONDecoder().decode(AuthResponse.self, from: data)
                    completion(.success(decoded))
                } catch {
                    completion(.failure(error))
                }
            }.resume()
        }
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
