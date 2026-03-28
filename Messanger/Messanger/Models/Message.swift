import Foundation

struct Message: Codable, Identifiable {
    let id: String
    let from: String
    let to: String
    let text: String
    let timestamp: String
    
    var date: Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: timestamp) ?? Date()
    }
    
    var isFromMe: Bool {
        from == AuthManager.shared.currentUser?.username ?? ""
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
