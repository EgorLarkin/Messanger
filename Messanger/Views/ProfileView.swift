import SwiftUI
import PhotosUI
import UIKit

struct ProfileView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = ProfileViewModel()

    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var pickedItems: [PendingMediaItem] = []
    @State private var isUploading = false

    var body: some View {
        NavigationView {
            Form {
                avatarSection
                infoSection
                accountSection
                dangerSection
            }
            .navigationTitle("Профиль")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingImagePicker, onDismiss: handlePickedItems) {
                ImagePicker(items: $pickedItems)
            }
            .alert("Ошибка", isPresented: errorAlertBinding) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .alert("Выход", isPresented: $viewModel.showLogoutAlert) {
                Button("Отмена", role: .cancel) { }
                Button("Выйти", role: .destructive) {
                    viewModel.logout()
                }
            } message: {
                Text("Вы уверены?")
            }
            .alert("Удаление", isPresented: $viewModel.showDeleteAlert) {
                Button("Отмена", role: .cancel) { }
                Button("Удалить", role: .destructive) {
                    viewModel.deleteAccount()
                }
            } message: {
                Text("Это нельзя отменить")
            }
            .disabled(viewModel.isLoading || isUploading)
            .overlay {
                if viewModel.isLoading || isUploading {
                    ZStack {
                        Color.black.opacity(0.1).ignoresSafeArea()

                        ProgressView("Сохранение...")
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                    }
                }
            }
        }
    }

    private var avatarSection: some View {
        Section(header: Text("Аватар")) {
            VStack(spacing: 12) {
                avatarEditor

                Button("Изменить аватар") {
                    showingImagePicker = true
                }
                .foregroundColor(.blue)
                .padding(.vertical, 8)
            }
        }
    }

    private var avatarEditor: some View {
        ZStack(alignment: .bottomTrailing) {
            AvatarView(user: currentUser, size: 100)

            Circle()
                .fill(Color.blue)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "camera.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                )
                .onTapGesture {
                    showingImagePicker = true
                }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var infoSection: some View {
        Section(header: Text("Информация")) {
            VStack(alignment: .leading, spacing: 12) {
                if viewModel.isEditing {
                    TextField("Имя", text: $viewModel.newName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.displayName)
                            .font(.headline)

                        Text("@\(viewModel.username)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                if viewModel.isEditing {
                    HStack {
                        Button("Отмена") {
                            viewModel.cancelEdit()
                        }
                        .foregroundColor(.gray)

                        Spacer()

                        Button("Сохранить") {
                            viewModel.saveProfile()
                        }
                        .foregroundColor(.blue)
                        .disabled(viewModel.isLoading)
                    }
                } else {
                    Button("Редактировать профиль") {
                        viewModel.isEditing = true
                    }
                    .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var accountSection: some View {
        Section(header: Text("Аккаунт")) {
            LabeledContent("ID", value: viewModel.userId)
            LabeledContent("Логин", value: viewModel.username)
        }
    }

    private var dangerSection: some View {
        Section {
            Button(role: .destructive) {
                viewModel.showLogoutAlert = true
            } label: {
                Label("Выйти", systemImage: "rectangle.portrait.and.arrow.right")
            }

            Button(role: .destructive) {
                viewModel.showDeleteAlert = true
            } label: {
                Label("Удалить аккаунт", systemImage: "trash")
            }
        }
    }

    private var currentUser: User {
        AuthManager.shared.currentUser ?? User(id: "", username: "", name: "", avatar: nil)
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { newValue in
                if !newValue {
                    viewModel.errorMessage = nil
                }
            }
        )
    }

    private func handlePickedItems() {
        guard let first = pickedItems.first,
              first.type == .image,
              let image = first.image else {
            pickedItems = []
            return
        }

        selectedImage = image
        pickedItems = []
        handlePickedImage()
    }

    private func handlePickedImage() {
        guard let image = selectedImage else { return }
        uploadAvatar(image: image)
    }

    private func uploadAvatar(image: UIImage) {
        guard let base64 = image.toBase64() else {
            viewModel.errorMessage = "Ошибка обработки изображения"
            return
        }

        isUploading = true

        NetworkService.shared.uploadAvatar(avatarBase64: base64) { result in
            DispatchQueue.main.async {
                isUploading = false

                switch result {
                case .success:
                    selectedImage = nil
                    viewModel.loadProfile()

                case .failure(let error):
                    viewModel.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

extension UIImage {
    func toBase64() -> String? {
        self.jpegData(compressionQuality: 0.8)?.base64EncodedString()
    }
}
