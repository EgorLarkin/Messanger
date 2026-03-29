import Foundation
import Combine

class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    
    private let tokenKey = "auth_token"
    private let userKey = "auth_user"
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        checkAuth()
    }
    
    func checkAuth() {
        if let token = UserDefaults.standard.string(forKey: tokenKey),
           let data = UserDefaults.standard.data(forKey: userKey),
           let user = try? JSONDecoder().decode(User.self, from: data) {
            self.currentUser = user
            self.isAuthenticated = true
        }
    }
    
    func saveAuth(token: String, user: User) {
        UserDefaults.standard.set(token, forKey: tokenKey)
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: userKey)
        }
        self.currentUser = user
        self.isAuthenticated = true
    }
    
    func updateCurrentUser(_ user: User) {
        self.currentUser = user
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: userKey)
        }
    }
    
    func logout() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: userKey)
        self.currentUser = nil
        self.isAuthenticated = false
    }
    
    func deleteAccount() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: userKey)
        self.currentUser = nil
        self.isAuthenticated = false
    }
    
    var token: String? {
        UserDefaults.standard.string(forKey: tokenKey)
    }
}
