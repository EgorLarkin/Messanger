import Foundation
import Combine

final class ProfileViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isEditing = false
    @Published var newName = ""
    @Published var showLogoutAlert = false
    @Published var showDeleteAlert = false

    init() {
        if let user = AuthManager.shared.currentUser {
            newName = user.name
        } else {
            loadProfile()
        }
    }

    var currentUser: User? {
        AuthManager.shared.currentUser
    }

    var displayName: String {
        currentUser?.name ?? ""
    }

    var username: String {
        currentUser?.username ?? ""
    }

    var userId: String {
        currentUser?.id ?? ""
    }

    func loadProfile() {
        isLoading = true
        errorMessage = nil

        NetworkService.shared.fetchProfile { [weak self] (result: Result<User, Error>) in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.isLoading = false

                switch result {
                case .success(let user):
                    AuthManager.shared.updateCurrentUser(user)
                    self.newName = user.name

                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func cancelEdit() {
        newName = currentUser?.name ?? ""
        isEditing = false
        errorMessage = nil
    }

    func saveProfile() {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            errorMessage = "Имя не может быть пустым"
            return
        }

        isLoading = true
        errorMessage = nil

        NetworkService.shared.updateProfile(name: trimmedName) { [weak self] (result: Result<User, Error>) in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.isLoading = false

                switch result {
                case .success(let user):
                    AuthManager.shared.updateCurrentUser(user)
                    self.newName = user.name
                    self.isEditing = false

                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func logout() {
        AuthManager.shared.logout()
    }

    func deleteAccount() {
        isLoading = true
        errorMessage = nil

        NetworkService.shared.deleteAccount { [weak self] (result: Result<Void, Error>) in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.isLoading = false

                switch result {
                case .success:
                    AuthManager.shared.deleteAccount()

                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
