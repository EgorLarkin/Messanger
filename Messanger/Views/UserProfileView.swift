import SwiftUI

struct UserProfileView: View {
    let user: User
    @Environment(\.dismiss) private var dismiss
    @State private var showingFullScreenAvatar = false

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Button {
                    showingFullScreenAvatar = true
                } label: {
                    AvatarView(user: user, size: 110)
                }
                .buttonStyle(.plain)

                VStack(spacing: 8) {
                    Text(user.name)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("@\(user.username)")
                        .font(.body)
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 12) {
                    infoRow(title: "Имя", value: user.name)
                    infoRow(title: "Логин", value: "@\(user.username)")
                    infoRow(title: "ID", value: user.id)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 24)
            .navigationTitle("Профиль")
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(isPresented: $showingFullScreenAvatar) {
                FullScreenAvatarView(user: user)
            }
        }
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }
}
