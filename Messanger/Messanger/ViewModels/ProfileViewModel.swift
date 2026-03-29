import Foundation
import Combine

class ProfileViewModel: ObservableObject {
    @Published var displayName: String = ""
    @Published var username: String = ""
    @Published var userId: String = ""
    
    @Published var isEditing = false
    @Published var newName: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showLogoutAlert = false
    @Published var showDeleteAlert = false
    
    private let networkService = NetworkService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadProfile()
    }
    
    func loadProfile() {
        guard let user = AuthManager.shared.currentUser else { return }
        displayName = user.name
        username = user.username
        userId = user.id
        newName = user.name
    }
    
    func saveProfile() {
        guard !newName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Имя не может быть пустым"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        networkService.updateProfile(name: newName) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let user):
                    self?.displayName = user.name
                    self?.newName = user.name
                    self?.isEditing = false
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func cancelEdit() {
        newName = displayName
        isEditing = false
        errorMessage = nil
    }
    
    func logout() {
        AuthManager.shared.logout()
    }
    
    func deleteAccount() {
        isLoading = true
        networkService.deleteAccount { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                // Аккаунт удалён
            }
        }
    }
}
