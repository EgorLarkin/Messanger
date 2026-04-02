import Foundation
import UIKit
import UserNotifications
import Combine

class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    
    private let center = UNUserNotificationCenter.current()
    
    override init() {
        super.init()
        center.delegate = self
    }
    
    func requestPermission() {
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("✅ Уведомления разрешены")
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                print("❌ Уведомления запрещены: \(error?.localizedDescription ?? "неизвестно")")
            }
        }
    }
    
    func showMessageNotification(from: String, text: String, chatId: String) {
        let content = UNMutableNotificationContent()
        content.title = from
        content.body = text
        content.sound = .default
        content.badge = 1
        content.threadIdentifier = chatId
        
        let request = UNNotificationRequest(
            identifier: "msg_\(chatId)_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        center.add(request) { error in
            if let error = error {
                print("❌ Ошибка уведомления: \(error)")
            }
        }
    }
    
    func clearBadge() {
        // iOS 17+ способ
        if #available(iOS 17.0, *) {
            center.getDeliveredNotifications { notifications in
                let ids = notifications.map { $0.request.identifier }
                self.center.removeDeliveredNotifications(withIdentifiers: ids)
            }
        } else {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
    }
    
    func uploadMedia(
        to: String,
        fileURL: URL,
        mediaType: MediaType,
        text: String = "",
        duration: Double? = nil,
        completion: @escaping (Result<Message, Error>) -> Void
    ) {
        guard let token = AuthManager.shared.token else {
            completion(.failure(NSError(
                domain: "Auth",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Нет токена авторизации"]
            )))
            return
        }

        guard let url = URL(string: "\(NetworkService.shared.serverURL)/...") else {
            completion(.failure(NSError(
                domain: "URL",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Некорректный URL"]
            )))
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let preparedFile = try self.prepareUploadFile(from: fileURL, mediaType: mediaType)
                defer {
                    try? FileManager.default.removeItem(at: preparedFile.localURL)
                }

                let fileData = try Data(contentsOf: preparedFile.localURL, options: .mappedIfSafe)
                let boundary = "Boundary-\(UUID().uuidString)"

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
                request.timeoutInterval = 300

                var body = Data()

                func appendTextField(name: String, value: String) {
                    body.append("--\(boundary)\r\n".data(using: .utf8)!)
                    body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
                    body.append("\(value)\r\n".data(using: .utf8)!)
                }

                appendTextField(name: "to", value: to)
                appendTextField(name: "mediaType", value: mediaType.rawValue)
                appendTextField(name: "text", value: text)

                if let duration = duration {
                    appendTextField(name: "duration", value: "\(duration)")
                }

                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(preparedFile.fileName)\"\r\n".data(using: .utf8)!)
                body.append("Content-Type: \(preparedFile.mimeType)\r\n\r\n".data(using: .utf8)!)
                body.append(fileData)
                body.append("\r\n".data(using: .utf8)!)
                body.append("--\(boundary)--\r\n".data(using: .utf8)!)

                request.httpBody = body

                URLSession.shared.dataTask(with: request) { data, response, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            completion(.failure(error))
                            return
                        }

                        if let http = response as? HTTPURLResponse,
                           !(200...299).contains(http.statusCode) {
                            let serverText = data.flatMap { String(data: $0, encoding: .utf8) } ?? "HTTP \(http.statusCode)"
                            completion(.failure(NSError(
                                domain: "HTTP",
                                code: http.statusCode,
                                userInfo: [NSLocalizedDescriptionKey: serverText]
                            )))
                            return
                        }

                        guard let data = data,
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                            completion(.failure(NSError(
                                domain: "Parse",
                                code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "Ошибка ответа сервера"]
                            )))
                            return
                        }

                        if let errorMessage = json["error"] as? String {
                            completion(.failure(NSError(
                                domain: "Server",
                                code: -1,
                                userInfo: [NSLocalizedDescriptionKey: errorMessage]
                            )))
                            return
                        }

                        if let msgData = json["message"] as? [String: Any],
                           let message = NetworkService.shared.parseMessage(msgData) {
                            completion(.success(message))
                        } else {
                            completion(.failure(NSError(
                                domain: "Message",
                                code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "Не удалось распарсить сообщение"]
                            )))
                        }
                    }
                }.resume()

            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    private struct PreparedUploadFile {
        let localURL: URL
        let fileName: String
        let mimeType: String
    }

    private func prepareUploadFile(from originalURL: URL, mediaType: MediaType) throws -> PreparedUploadFile {
        let gainedAccess = originalURL.startAccessingSecurityScopedResource()

        defer {
            if gainedAccess {
                originalURL.stopAccessingSecurityScopedResource()
            }
        }

        let fileManager = FileManager.default
        let originalName = originalURL.lastPathComponent.isEmpty ? "upload" : originalURL.lastPathComponent
        let ext = originalURL.pathExtension
        let safeExtension = ext.isEmpty ? defaultExtension(for: mediaType) : ext

        let tempFileName = UUID().uuidString + (safeExtension.isEmpty ? "" : ".\(safeExtension)")
        let tempURL = fileManager.temporaryDirectory.appendingPathComponent(tempFileName)

        if fileManager.fileExists(atPath: tempURL.path) {
            try fileManager.removeItem(at: tempURL)
        }

        do {
            try fileManager.copyItem(at: originalURL, to: tempURL)
        } catch {
            let data = try Data(contentsOf: originalURL)
            try data.write(to: tempURL, options: .atomic)
        }

        let mimeType = mimeTypeForFileExtension(safeExtension, mediaType: mediaType)

        return PreparedUploadFile(
            localURL: tempURL,
            fileName: originalName,
            mimeType: mimeType
        )
    }
    
    private func defaultExtension(for mediaType: MediaType) -> String {
        switch mediaType {
        case .image:
            return "jpg"
        case .video, .videoNote:
            return "mp4"
        case .voice:
            return "m4a"
        case .file, .text:
            return "bin"
        }
    }

    private func mimeTypeForFileExtension(_ ext: String, mediaType: MediaType) -> String {
        switch ext.lowercased() {
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "heic":
            return "image/heic"
        case "gif":
            return "image/gif"

        case "mp4":
            return "video/mp4"
        case "mov":
            return "video/quicktime"
        case "m4v":
            return "video/x-m4v"

        case "m4a":
            return "audio/m4a"
        case "mp3":
            return "audio/mpeg"
        case "wav":
            return "audio/wav"
        case "aac":
            return "audio/aac"

        case "pdf":
            return "application/pdf"
        case "txt":
            return "text/plain"
        case "json":
            return "application/json"
        case "zip":
            return "application/zip"
        case "doc":
            return "application/msword"
        case "docx":
            return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "xls":
            return "application/vnd.ms-excel"
        case "xlsx":
            return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "ppt":
            return "application/vnd.ms-powerpoint"
        case "pptx":
            return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        default:
            switch mediaType {
            case .image:
                return "image/jpeg"
            case .video, .videoNote:
                return "video/mp4"
            case .voice:
                return "audio/m4a"
            case .file, .text:
                return "application/octet-stream"
            }
        }
    }

    private func mimeTypeForFile(at url: URL, mediaType: MediaType) -> String {
        switch mediaType {
        case .video:
            let ext = url.pathExtension.lowercased()
            if ext == "mov" { return "video/quicktime" }
            if ext == "mp4" { return "video/mp4" }
            return "video/mp4"

        case .image:
            let ext = url.pathExtension.lowercased()
            if ext == "png" { return "image/png" }
            if ext == "heic" { return "image/heic" }
            return "image/jpeg"

        case .voice:
            return "audio/m4a"

        case .file, .videoNote, .text:
            return "application/octet-stream"
        }
    }
}

extension NotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        print("🔔 Тап по уведомлению")
        completionHandler()
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
        NetworkService.shared.sendMessage(
            to: to,
            text: text,
            mediaType: mediaType,
            mediaData: mediaData,
            duration: nil as Double?,
            fileName: fileName,
            fileSize: fileSize,
            completion: completion
        )
    }
}
