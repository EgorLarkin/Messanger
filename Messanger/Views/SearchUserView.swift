import SwiftUI

struct SearchUserView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = SearchViewModel()
    
    var body: some View {
        NavigationView {
            VStack {
                TextField("Поиск по логину или имени", text: $viewModel.searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                if viewModel.isSearching {
                    ProgressView()
                        .padding()
                } else if let error = viewModel.errorMessage, !error.isEmpty {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                } else if viewModel.searchResults.isEmpty && !viewModel.searchText.isEmpty {
                    Text("Пользователи не найдены")
                        .foregroundColor(.gray)
                        .padding()
                }
                
                List(viewModel.searchResults) { user in
                    Button(action: {
                        dismiss()
                        NotificationCenter.default.post(
                            name: .openChatWithUser,
                            object: nil,
                            userInfo: ["user": user]
                        )
                    }) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text(user.name)
                                    .font(.headline)
                                Text("@\(user.username)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 5)
                    }
                }
            }
            .navigationTitle("Поиск пользователей")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Готово") {
                        dismiss()
                    }
                }
            }
        }
    }
}

extension Notification.Name {
    static let openChatWithUser = Notification.Name("openChatWithUser")
}
