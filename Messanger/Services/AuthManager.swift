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
        if let _ = UserDefaults.standard.string(forKey: tokenKey),
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
    
    func logout() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: userKey)
        self.currentUser = nil
        self.isAuthenticated = false
    }
    
    var token: String? {
        UserDefaults.standard.string(forKey: tokenKey)
    }
    // MARK: - Обновление профиля
    
    func updateCurrentUser(_ user: User) {
        self.currentUser = user
        // Сохраняем обновлённые данные
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: userKey)
        }
    }
    
    func refreshCurrentUser(completion: @escaping (Result<User, Error>) -> Void) {
        guard let token = token else {
            completion(.failure(NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Нет токена"])))
            return
        }
        
        // Делаем запрос к /auth/verify для получения актуальных данных
        guard let url = URL(string: "\(NetworkService.shared.serverURL)/auth/verify") else {
            completion(.failure(URLError(.badURL)))
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let userData = json["user"] as? [String: Any],
                  let user = NetworkService.shared.parseUser(userData) else {
                completion(.failure(NSError(domain: "Parse", code: -1, userInfo: nil)))
                return
            }
            
            self.updateCurrentUser(user)
            completion(.success(user))
        }.resume()
    }
}
