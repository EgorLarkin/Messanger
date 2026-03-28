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

struct SearchResponse: Codable {
    let users: [User]
}

// Запрос на обновление профиля
struct ProfileUpdateRequest: Codable {
    let name: String
}

// Ответ сервера при обновлении профиля
struct ProfileUpdateResponse: Codable {
    let success: Bool
    let user: User?
    let error: String?
}
