import Foundation
import SwiftUI
import UIKit

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

enum MessageDeliveryState: String, Codable {
    case sending
    case sent
    case failed
}

struct User: Codable, Identifiable, Equatable {
    let id: String
    let username: String
    let name: String
    let avatar: String?

    var avatarImage: Image? {
        guard let avatar = avatar,
              !avatar.isEmpty,
              let imageData = Data(base64Encoded: avatar.components(separatedBy: ",").last ?? ""),
              let uiImage = UIImage(data: imageData) else {
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
        let index = username.hashValue % colors.count
        return colors[abs(index)]
    }
}

struct Message: Codable, Identifiable, Equatable {
    let id: String
    let from: String
    let to: String
    let text: String
    let mediaType: String
    let mediaData: String?
    let fileId: String?
    let downloadUrl: String?
    let duration: Double?
    let fileName: String?
    let fileSize: Int?
    let timestamp: String

    var localFilePath: String? = nil
    var localId: String? = nil
    var deliveryState: MessageDeliveryState = .sent

    var date: Date {
        ISO8601DateFormatter().date(from: timestamp) ?? Date()
    }

    var isFromMe: Bool {
        from == AuthManager.shared.currentUser?.username ?? ""
    }

    var type: MediaType {
        MediaType(rawValue: mediaType) ?? .text
    }

    var displayText: String {
        if type == .text {
            return text
        } else if let fileName = fileName, !fileName.isEmpty {
            return fileName
        } else {
            return type.label
        }
    }

    var image: Image? {
        if let localFilePath = localFilePath,
           let uiImage = UIImage(contentsOfFile: localFilePath) {
            return Image(uiImage: uiImage)
        }

        guard type == .image,
              let mediaData = mediaData,
              !mediaData.isEmpty else {
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

    var localFileURL: URL? {
        guard let localFilePath else { return nil }
        return URL(fileURLWithPath: localFilePath)
    }

    var formattedDuration: String {
        guard let duration = duration, duration > 0 else { return "" }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var formattedFileSize: String {
        guard let size = fileSize else { return "" }
        if size < 1024 {
            return "\(size) Б"
        } else if size < 1024 * 1024 {
            return String(format: "%.1f КБ", Double(size) / 1024)
        } else {
            return String(format: "%.1f МБ", Double(size) / (1024 * 1024))
        }
    }

    static func == (lhs: Message, rhs: Message) -> Bool {
        lhs.id == rhs.id
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
