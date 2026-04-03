import Foundation
import SwiftUI
import UIKit
import AVFoundation

// MARK: - MediaType

enum MediaType: String, Codable, CaseIterable {
    case text = "text"
    case image = "image"
    case video = "video"
    case file = "file"
    case voice = "voice"
    case videoNote = "video_note"

    var icon: String {
        switch self {
        case .text: return "message"
        case .image: return "photo"
        case .video: return "video"
        case .file: return "doc"
        case .voice: return "waveform"
        case .videoNote: return "record.circle"
        }
    }

    var label: String {
        switch self {
        case .text: return "Текст"
        case .image: return "Фото"
        case .video: return "Видео"
        case .file: return "Файл"
        case .voice: return "Голосовое"
        case .videoNote: return "Кружочек"
        }
    }
}

// MARK: - User / Auth

struct User: Codable, Identifiable, Equatable {
    let id: String
    let username: String
    let name: String
    let avatar: String?

    var avatarImage: Image? {
        guard
            let avatar = avatar,
            !avatar.isEmpty,
            let imageData = Data(base64Encoded: avatar.components(separatedBy: ",").last ?? ""),
            let uiImage = UIImage(data: imageData)
        else {
            return nil
        }
        return Image(uiImage: uiImage)
    }

    var initials: String {
        let components = name.components(separatedBy: " ")
        if components.count >= 2 {
            return "\(components[0].prefix(1))\(components[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    var avatarColor: Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .red, .teal]
        let index = abs(username.hashValue) % colors.count
        return colors[index]
    }
}

struct AuthResponse: Codable {
    let success: Bool
    let token: String?
    let user: User?
    let error: String?
}

// MARK: - Attachments

struct MessageAttachment: Codable, Equatable, Identifiable {
    var id: String {
        "\(fileName ?? "attachment")_\(fileSize ?? 0)_\(mediaData.prefix(24))"
    }

    let mediaData: String
    let fileName: String?
    let fileSize: Int?

    var detectedType: MediaType {
        if mediaData.hasPrefix("image") { return .image }
        if mediaData.hasPrefix("video") { return .video }
        if mediaData.hasPrefix("audio") { return .voice }

        if mediaData.hasPrefix("http://") || mediaData.hasPrefix("https://") {
            let lower = (fileName ?? mediaData).lowercased()
            if lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg") || lower.hasSuffix(".png") || lower.hasSuffix(".webp") {
                return .image
            }
            if lower.hasSuffix(".mp4") || lower.hasSuffix(".mov") || lower.hasSuffix(".m4v") {
                return .video
            }
        }

        return .file
    }

    var image: Image? {
        guard detectedType == .image else { return nil }

        if mediaData.hasPrefix("http://") || mediaData.hasPrefix("https://") {
            return nil
        }

        let parts = mediaData.components(separatedBy: ",")
        let base64 = parts.count > 1 ? parts[1] : mediaData

        guard let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters),
              let uiImage = UIImage(data: data) else {
            return nil
        }

        return Image(uiImage: uiImage)
    }

    var videoURL: URL? {
        if mediaData.hasPrefix("http://") || mediaData.hasPrefix("https://") {
            return URL(string: mediaData)
        }

        if mediaData.hasPrefix("/") {
            return URL(fileURLWithPath: mediaData)
        }

        return nil
    }

    var videoThumbnail: Image? {
        guard detectedType == .video,
              let url = videoURL,
              let image = VideoThumbnailGenerator.generate(from: url) else {
            return nil
        }

        return Image(uiImage: image)
    }
}

// MARK: - Video thumbnail helper

enum VideoThumbnailGenerator {
    static func generate(from url: URL) -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 600, height: 600)

        let times: [Double] = [0.0, 0.05, 0.1, 0.25, 0.5, 1.0]

        for second in times {
            let time = CMTime(seconds: second, preferredTimescale: 600)
            do {
                let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
                return UIImage(cgImage: cgImage)
            } catch {
                continue
            }
        }

        print("❌ Failed to generate thumbnail for url: \(url)")
        return nil
    }
}

// MARK: - Message

struct Message: Codable, Identifiable, Equatable {
    let id: String
    let from: String
    let to: String
    let text: String
    let mediaType: String
    let mediaData: String?
    let attachments: [MessageAttachment]?
    let duration: Double?
    let fileName: String?
    let fileSize: Int?
    let timestamp: String

    // новые поля с сервера для /send-media
    let fileId: String?
    let downloadUrl: String?

    // MARK: Meta

    var date: Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: timestamp)
            ?? ISO8601DateFormatter().date(from: timestamp)
            ?? Date()
    }

    var isFromMe: Bool {
        from == (AuthManager.shared.currentUser?.username ?? "")
    }

    var hasAttachments: Bool {
        !(attachments?.isEmpty ?? true)
    }

    var firstAttachment: MessageAttachment? {
        attachments?.first
    }

    // MARK: Type

    var type: MediaType {
        if !mediaType.isEmpty, let mapped = MediaType(rawValue: mediaType) {
            return mapped
        }

        if let firstAttachment = firstAttachment {
            return firstAttachment.detectedType
        }

        if let data = mediaData, !data.isEmpty {
            if data.hasPrefix("image") { return .image }
            if data.hasPrefix("video") { return .video }
            if data.hasPrefix("audio") { return .voice }
            if data.hasPrefix("file") { return .file }

            if data.hasPrefix("http://") || data.hasPrefix("https://") {
                let lower = data.lowercased()
                if lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg") || lower.hasSuffix(".png") || lower.hasSuffix(".webp") {
                    return .image
                }
                if lower.hasSuffix(".mp4") || lower.hasSuffix(".mov") || lower.hasSuffix(".m4v") {
                    return .video
                }
            }
        }

        return .text
    }

    // MARK: Display text

    var displayText: String {
        switch type {
        case .text:
            return text

        case .video, .videoNote:
            return text

        case .image:
            if let attachments, !attachments.isEmpty {
                return !text.isEmpty ? text : "Фотографии: \(attachments.count)"
            }
            return !text.isEmpty ? text : "Фото"

        default:
            if let fileName = fileName, !fileName.isEmpty {
                return fileName
            } else if let firstAttachmentName = firstAttachment?.fileName, !firstAttachmentName.isEmpty {
                return firstAttachmentName
            } else {
                return type.label
            }
        }
    }

    // MARK: Images

    var image: Image? {
        if let attachments, !attachments.isEmpty {
            return attachments.first(where: { $0.detectedType == .image })?.image
        }

        guard type == .image,
              let mediaData = mediaData,
              !mediaData.isEmpty else {
            return nil
        }

        if mediaData.hasPrefix("http://") || mediaData.hasPrefix("https://") {
            return nil
        }

        let components = mediaData.components(separatedBy: ",")
        let base64String = components.count > 1 ? components[1] : mediaData

        guard let imageData = Data(base64Encoded: base64String, options: .ignoreUnknownCharacters),
              let uiImage = UIImage(data: imageData) else {
            return nil
        }

        return Image(uiImage: uiImage)
    }

    var allImages: [Image] {
        if let attachments, !attachments.isEmpty {
            return attachments.compactMap { $0.image }
        }

        if let image = image {
            return [image]
        }

        return []
    }

    // MARK: Video URL

    /// 1) attachments с видео
    /// 2) mediaData как http(s)/file url
    /// 3) downloadUrl с сервера (/files/:fileId)
    var videoURL: URL? {
        if let attachments, !attachments.isEmpty,
           let url = attachments.first(where: { $0.detectedType == .video })?.videoURL {
            return url
        }

        if let mediaData = mediaData, !mediaData.isEmpty {
            if mediaData.hasPrefix("http://") || mediaData.hasPrefix("https://") {
                return URL(string: mediaData)
            }
            if mediaData.hasPrefix("/") {
                return URL(fileURLWithPath: mediaData)
            }
        }

        if let downloadUrl, !downloadUrl.isEmpty {
            return URL(string: downloadUrl)
        }

        return nil
    }

    // MARK: Video thumbnail

    var videoThumbnail: Image? {
        guard type == .video || type == .videoNote else { return nil }
        guard let url = videoURL,
              let image = VideoThumbnailGenerator.generate(from: url) else {
            return nil
        }
        return Image(uiImage: image)
    }

    // MARK: Duration / size

    var formattedDuration: String {
        guard let duration = duration, duration > 0 else { return "" }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var formattedFileSize: String {
        guard let size = fileSize else { return "" }
        if size < 1024 { return "\(size) Б" }
        if size < 1024 * 1024 { return String(format: "%.1f КБ", Double(size) / 1024) }
        return String(format: "%.1f МБ", Double(size) / 1024 / 1024)
    }
}

// MARK: - Other models

struct Conversation: Codable, Identifiable {
    let chatWith: String
    let lastMessage: String
    let timestamp: String
    let unreadCount: Int
    let user: User
    let lastMessageType: String?

    var id: String { chatWith }

    var date: Date {
        ISO8601DateFormatter().date(from: timestamp) ?? Date()
    }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    var type: MediaType {
        MediaType(rawValue: lastMessageType ?? "text") ?? .text
    }
}

struct AttachmentPayload: Codable {
    let mediaData: String
    let fileName: String?
    let fileSize: Int?
}

struct MessageRequest: Codable {
    let to: String
    let text: String?
    let mediaType: String?
    let mediaData: String?
    let duration: Double?
    let fileName: String?
    let fileSize: Int?
    let attachments: [AttachmentPayload]?
}

struct MessageResponse: Codable {
    let success: Bool
    let message: MessageData?
    let error: String?
}

struct SearchResponse: Codable {
    let users: [User]
}

struct ProfileUpdateRequest: Codable {
    let name: String
}

struct ProfileUpdateResponse: Codable {
    let success: Bool
    let user: User?
    let error: String?
}

struct ProfileVerifyResponse: Codable {
    let valid: Bool
    let user: User?
}

struct ConversationsResponse: Codable {
    let success: Bool
    let conversations: [Conversation]
}

struct MessageData: Codable {
    let id: String
    let from: String
    let to: String
    let text: String
    let mediaType: String
    let mediaData: String?
    let attachments: [MessageAttachment]?
    let duration: Double?
    let fileName: String?
    let fileSize: Int?
    let timestamp: String

    let fileId: String?
    let downloadUrl: String?
}

struct HistoryResponse: Codable {
    let success: Bool
    let count: Int
    let messages: [MessageData]
}
