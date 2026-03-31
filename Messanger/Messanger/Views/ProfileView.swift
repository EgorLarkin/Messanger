import SwiftUI
import PhotosUI
import UIKit

struct ProfileView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = ProfileViewModel()
    
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var isUploading = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Аватар")) {
                    VStack(spacing: 12) {
                        ZStack {
                            AvatarView(user: currentUser, size: 100)
                            
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white)
                                )
                                .offset(x: 25, y: 25)
                        }
                        .onTapGesture {
                            showingImagePicker = true
                        }
                        
                        Button("Изменить аватар") {
                            showingImagePicker = true
                        }
                        .foregroundColor(.blue)
                    }
                    .padding(.vertical, 8)
                }
                
                Section(header: Text("Информация")) {
                    HStack {
                        VStack(alignment: .leading) {
                            if viewModel.isEditing {
                                TextField("Имя", text: $viewModel.newName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            } else {
                                Text(viewModel.displayName)
                                    .font(.headline)
                            }
                            Text("@\(viewModel.username)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    if viewModel.isEditing {
                        HStack {
                            Button("Отмена") { viewModel.cancelEdit() }
                                .foregroundColor(.gray)
                            Spacer()
                            Button("Сохранить") { viewModel.saveProfile() }
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
                
                Section(header: Text("Аккаунт")) {
                    LabeledContent("ID", value: viewModel.userId)
                    LabeledContent("Логин", value: viewModel.username)
                }
                
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
            .navigationTitle("Профиль")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $selectedImage)
                    .onDisappear {
                        if let image = selectedImage {
                            uploadAvatar(image: image)
                        }
                    }
            }
            .alert("Ошибка", isPresented: .init(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .alert("Выход", isPresented: $viewModel.showLogoutAlert) {
                Button("Отмена", role: .cancel) { }
                Button("Выйти", role: .destructive) { viewModel.logout() }
            } message: {
                Text("Вы уверены?")
            }
            .alert("Удаление", isPresented: $viewModel.showDeleteAlert) {
                Button("Отмена", role: .cancel) { }
                Button("Удалить", role: .destructive) { viewModel.deleteAccount() }
            } message: {
                Text("Это нельзя отменить")
            }
            .disabled(viewModel.isLoading || isUploading)
            .overlay {
                if viewModel.isLoading || isUploading {
                    ProgressView("Сохранение...")
                }
            }
        }
    }
    
    private var currentUser: User {
        AuthManager.shared.currentUser ?? User(id: "", username: "", name: "", avatar: nil)
    }
    
    private func uploadAvatar(image: UIImage) {
        guard let base64 = image.toBase64() else {
            viewModel.errorMessage = "Ошибка обработки изображения"
            return
        }
        
        isUploading = true
        
        NetworkService.shared.uploadAvatar(avatarBase64: base64) { result in
            isUploading = false
            switch result {
            case .success:
                selectedImage = nil
            case .failure(let error):
                viewModel.errorMessage = error.localizedDescription
            }
        }
    }
}

extension UIImage {
    func toBase64(compressionQuality: CGFloat = 0.8) -> String? {
        guard let data = jpegData(compressionQuality: compressionQuality) else {
            return nil
        }
        return "image/jpeg;base64,\(data.base64EncodedString())"
    }
}

extension Data {
    func toImage() -> UIImage? {
        return UIImage(data: self)
    }
}
