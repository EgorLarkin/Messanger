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
                    ProgressView().padding()
                } else if let error = viewModel.errorMessage, !error.isEmpty {
                    Text(error).foregroundColor(.red).padding()
                } else if viewModel.searchResults.isEmpty && !viewModel.searchText.isEmpty {
                    Text("Пользователи не найдены").foregroundColor(.gray).padding()
                }
                
                List(viewModel.searchResults) { user in
                    Button(action: {
                        NotificationCenter.default.post(
                            name: .userSelectedFromSearch,
                            object: nil,
                            userInfo: ["user": user]
                        )
                        dismiss()
                    }) {
                        HStack {
                            AvatarView(user: user, size: 40)
                            VStack(alignment: .leading) {
                                Text(user.name).font(.headline)
                                Text("@\(user.username)").font(.caption).foregroundColor(.gray)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.gray)
                        }.padding(.vertical, 5)
                    }
                }
            }
            .navigationTitle("Поиск пользователей")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") { dismiss() }
                }
            }
        }
    }
}
