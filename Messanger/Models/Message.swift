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
        return name.prefix(2).uppercased()
    }
    
    var avatarColor: Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .red, .teal]
        let index = username.hashValue % colors.count
        return colors[abs(index)]
    }
}

struct AuthResponse: Codable {
    let success: Bool
    let token: String?
    let user: User?
    let error: String?
}

struct Message: Codable, Identifiable {
    let id: String
    let from: String
    let to: String
    let text: String
    let mediaType: String
    let mediaData: String?
    let duration: Double?
    let fileName: String?
    let fileSize: Int?
    let timestamp: String
    
    var date: Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: timestamp) ?? Date()
    }
    
    var isFromMe: Bool {
        from == AuthManager.shared.currentUser?.username ?? ""
    }
    
    var type: MediaType {
        // 1. Сначала проверяем явный mediaType от сервера
        if !mediaType.isEmpty && mediaType != "text" {
            if let type = MediaType(rawValue: mediaType) {
                print("📊 TYPE: mediaType='\(mediaType)' → \(type)")
                return type
            }
        }
        
        // 2. Если mediaType пустой или "text", определяем по mediaData
        if let data = mediaData, !data.isEmpty {
            if data.hasPrefix("image") {
                print("📊 TYPE: mediaData начинается с 'image' → .image")
                return .image
            } else if data.hasPrefix("video") {
                print("📊 TYPE: mediaData начинается с 'video' → .video")
                return .video
            } else if data.hasPrefix("audio") {
                print("📊 TYPE: mediaData начинается с 'audio' → .voice")
                return .voice
            } else if data.hasPrefix("file") {
                print("📊 TYPE: mediaData начинается с 'file' → .file")
                return .file
            }
        }
        
        // 3. Если есть текст и нет медиа — это текст
        if !text.isEmpty {
            print("📊 TYPE: текст → .text")
            return .text
        }
        
        // 4. По умолчанию текст
        print("📊 TYPE: default → .text")
        return .text
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
        guard type == .image,
              let mediaData = mediaData,
              !mediaData.isEmpty else {
            return nil
        }
        
        // Извлекаем base64 часть (после запятой)
        let components = mediaData.components(separatedBy: ",")
        let base64String = components.count > 1 ? components[1] : mediaData
        
        // Отладка
        print("🖼️ DECODE IMAGE:")
        print("  - mediaData starts: \(mediaData.prefix(50))...")
        print("  - base64String length: \(base64String.count)")
        print("  - components count: \(components.count)")
        
        guard let imageData = Data(base64Encoded: base64String, options: .ignoreUnknownCharacters),
              let uiImage = UIImage(data: imageData) else {
            print("  - ❌ НЕ УДАЛОСЬ декодировать изображение")
            print("  - base64String first chars: \(base64String.prefix(20))")
            return nil
        }
        
        print("  - ✅ Изображение декодировано: \(uiImage.size)")
        return Image(uiImage: uiImage)
    }

    var videoThumbnail: Image? {
        guard (type == .video || type == .videoNote),
              let mediaData = mediaData,
              !mediaData.isEmpty else {
            return nil
        }
        
        // Для видео пытаемся создать thumbnail из base64
        let components = mediaData.components(separatedBy: ",")
        let base64String = components.count > 1 ? components[1] : mediaData
        
        guard let imageData = Data(base64Encoded: base64String, options: .ignoreUnknownCharacters),
              let uiImage = UIImage(data: imageData) else {
            return nil
        }
        return Image(uiImage: uiImage)
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
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: timestamp) ?? Date()
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

struct MessageRequest: Codable {
    let to: String
    let text: String?
    let mediaType: String?
    let mediaData: String?
    let duration: Double?
    let fileName: String?
    let fileSize: Int?
}

struct MessageResponse: Codable {
    let success: Bool
    let message: MessageData?
    let error: String?
}

struct MessageData: Codable {
    let id: String
    let from: String
    let to: String
    let text: String
    let mediaType: String
    let mediaData: String?
    let duration: Double?
    let fileName: String?
    let fileSize: Int?
    let timestamp: String
}

struct HistoryResponse: Codable {
    let success: Bool
    let count: Int
    let messages: [MessageData]
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

