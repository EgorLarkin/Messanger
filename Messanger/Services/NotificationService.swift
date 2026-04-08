import Foundation
import UIKit
import UserNotifications
import Combine

final class NotificationService: NSObject, ObservableObject {
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
        if #available(iOS 17.0, *) {
            center.getDeliveredNotifications { notifications in
                let ids = notifications.map { $0.request.identifier }
                self.center.removeDeliveredNotifications(withIdentifiers: ids)
            }
        } else {
            DispatchQueue.main.async {
                UIApplication.shared.applicationIconBadgeNumber = 0
            }
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
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let preparedFile = try self.prepareUploadFile(from: fileURL, mediaType: mediaType)
                defer {
                    try? FileManager.default.removeItem(at: preparedFile.localURL)
                }

                let fileData = try Data(contentsOf: preparedFile.localURL, options: .mappedIfSafe)
                let base64 = fileData.base64EncodedString()

                DispatchQueue.main.async {
                    NetworkService.shared.sendMessage(
                        to: to,
                        text: text,
                        mediaType: mediaType,
                        mediaData: base64,
                        duration: duration,
                        fileName: preparedFile.fileName,
                        fileSize: fileData.count,
                        completion: completion
                    )
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
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
            duration: nil,
            fileName: fileName,
            fileSize: fileSize,
            completion: completion
        )
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
        case .file, .text, .mixed:
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
            case .file, .text, .mixed:
                return "application/octet-stream"
            }
        }
    }
}

extension NotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        print("🔔 Тап по уведомлению")
        completionHandler()
    }
}
