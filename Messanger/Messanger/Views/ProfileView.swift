import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = ProfileViewModel()
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Информация")) {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        VStack(alignment: .leading) {
                            if viewModel.isEditing {
                                TextField("Имя", text: $viewModel.newName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            } else {
                                Text(viewModel.displayName).font(.headline)
                            }
                            Text("@\(viewModel.username)").font(.caption).foregroundColor(.gray)
                        }
                    }.padding(.vertical, 8)
                    
                    if viewModel.isEditing {
                        HStack {
                            Button("Отмена") { viewModel.cancelEdit() }.foregroundColor(.gray)
                            Spacer()
                            Button("Сохранить") { viewModel.saveProfile() }
                                .foregroundColor(.blue)
                                .disabled(viewModel.isLoading)
                        }.padding(.top, 8)
                    } else {
                        Button("Редактировать профиль") { viewModel.isEditing = true }
                            .foregroundColor(.blue)
                    }
                }
                
                Section(header: Text("Аккаунт")) {
                    LabeledContent("ID пользователя", value: viewModel.userId)
                    LabeledContent("Логин", value: viewModel.username)
                }
                
                Section {
                    Button(role: .destructive) {
                        viewModel.showLogoutAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Выйти из аккаунта")
                        }
                    }
                    
                    Button(role: .destructive) {
                        viewModel.showDeleteAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Удалить аккаунт")
                        }
                    }
                }
            }
            .navigationTitle("Профиль")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Готово") { dismiss() }
                }
            }
            .alert("Ошибка", isPresented: .init(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: { Text(viewModel.errorMessage ?? "") }
            .alert("Выход", isPresented: $viewModel.showLogoutAlert) {
                Button("Отмена", role: .cancel) { }
                Button("Выйти", role: .destructive) { viewModel.logout() }
            } message: { Text("Вы уверены, что хотите выйти?") }
            .alert("Удаление аккаунта", isPresented: $viewModel.showDeleteAlert) {
                Button("Отмена", role: .cancel) { }
                Button("Удалить", role: .destructive) { viewModel.deleteAccount() }
            } message: { Text("Это действие нельзя отменить. Все ваши данные будут удалены.") }
            .disabled(viewModel.isLoading)
            .overlay {
                if viewModel.isLoading {
                    ProgressView("Сохранение...")
                }
            }
        }
    }
}
