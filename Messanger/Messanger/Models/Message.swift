import Foundation

struct User: Codable, Identifiable, Equatable {
    let id: String
    let username: String
    let name: String
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
    let timestamp: String
    
    var date: Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: timestamp) ?? Date()
    }
    
    var isFromMe: Bool {
        from == AuthManager.shared.currentUser?.username ?? ""
    }
}

struct Conversation: Codable, Identifiable {
    let chatWith: String
    let lastMessage: String
    let timestamp: String
    let unreadCount: Int
    let user: User
    
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
}

struct MessageRequest: Codable {
    let to: String
    let text: String
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
