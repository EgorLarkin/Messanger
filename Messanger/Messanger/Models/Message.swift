import Foundation
import SwiftUI
import UIKit
import AVFoundation

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

struct MessageAttachment: Codable, Equatable, Identifiable {
    let mediaData: String
    let fileName: String?
    let fileSize: Int?
    let downloadUrl: String?
    let duration: Double?

    var id: String {
        let source = downloadUrl ?? mediaData
        return "\(fileName ?? "attachment")_\(fileSize ?? 0)_\(source.prefix(24))"
    }

    var resolvedMediaURLString: String {
        if let downloadUrl, !downloadUrl.isEmpty {
            return downloadUrl
        }
        return mediaData
    }

    var detectedType: MediaType {
        let source = resolvedMediaURLString.lowercased()
        let name = (fileName ?? source).lowercased()

        if source.hasPrefix("image") { return .image }
        if source.hasPrefix("video") { return .video }
        if source.hasPrefix("audio") { return .voice }

        if source.hasPrefix("http://") || source.hasPrefix("https://") {
            if name.hasSuffix(".jpg") || name.hasSuffix(".jpeg") || name.hasSuffix(".png") || name.hasSuffix(".webp") {
                return .image
            }
            if name.hasSuffix(".mp4") || name.hasSuffix(".mov") || name.hasSuffix(".m4v") {
                return .video
            }
        }

        return .file
    }

    var image: Image? {
        guard detectedType == .image else { return nil }

        let source = resolvedMediaURLString
        if source.hasPrefix("http://") || source.hasPrefix("https://") {
            return nil
        }

        let parts = source.components(separatedBy: ",")
        let base64 = parts.count > 1 ? parts[1] : source

        guard let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters),
              let uiImage = UIImage(data: data) else {
            return nil
        }

        return Image(uiImage: uiImage)
    }

    var videoURL: URL? {
        let source = resolvedMediaURLString

        if source.hasPrefix("http://") || source.hasPrefix("https://") {
            return URL(string: source)
        }

        if source.hasPrefix("/") {
            return URL(fileURLWithPath: source)
        }

        return nil
    }

    var videoThumbnail: Image? { nil }
}

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
    let fileId: String?
    let downloadUrl: String?

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

    var videoAttachments: [MessageAttachment] {
        (attachments ?? []).filter { $0.detectedType == .video }
    }

    var imageAttachments: [MessageAttachment] {
        (attachments ?? []).filter { $0.detectedType == .image }
    }

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

    var displayText: String {
        switch type {
        case .text:
            return text

        case .video, .videoNote:
            if videoAttachments.count > 1 {
                return !text.isEmpty ? text : "Видео: \(videoAttachments.count)"
            }
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

    var videoURL: URL? {
        if let url = videoAttachments.first?.videoURL {
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

    var videoThumbnail: Image? { nil }

    var formattedDuration: String {
        let sourceDuration = duration ?? videoAttachments.first?.duration
        guard let duration = sourceDuration, duration > 0 else { return "" }
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
