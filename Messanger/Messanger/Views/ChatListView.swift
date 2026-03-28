//
//  ChatListView.swift
//  Messanger
//
//  Created by Сергей Ларкин on 28/03/2026.
//


import SwiftUI

struct ChatListView: View {
    @State private var users: [User] = []
    @State private var showingSearch = false
    @State private var showingLogoutAlert = false
    private let networkService = NetworkService.shared
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Ваши чаты")) {
                    if users.isEmpty {
                        HStack {
                            Image(systemName: "message.badge")
                                .foregroundColor(.gray)
                            Text("Нет активных чатов")
                                .foregroundColor(.gray)
                                .italic()
                        }
                        .padding(.vertical, 10)
                    } else {
                        ForEach(users) { user in
                            NavigationLink(destination: ConversationView(chatUser: user)) {
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
                                }
                                .padding(.vertical, 5)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Чаты")
            .onAppear { loadUsers() }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    // Кнопка профиля слева
                    NavigationLink(destination: ProfileView()) {
                        Image(systemName: "person.crop.circle")
                            .font(.title2)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    // Кнопка поиска справа
                    Button(action: { showingSearch = true }) {
                        Image(systemName: "person.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showingSearch) {
                SearchUserView()
            }
            .alert("Выход", isPresented: $showingLogoutAlert) {
                Button("Отмена", role: .cancel) { }
                Button("Выйти", role: .destructive) {
                    AuthManager.shared.logout()
                }
            } message: {
                Text("Вы уверены, что хотите выйти?")
            }
        }
    }
    
    private func loadUsers() {
        networkService.fetchUsers { result in
            if case .success(let fetched) = result {
                users = fetched.filter {
                    $0.username != AuthManager.shared.currentUser?.username
                }
            }
        }
    }
}
