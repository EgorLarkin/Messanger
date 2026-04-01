import SwiftUI

struct UserProfileView: View {
    let user: User
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                AvatarView(user: user, size: 110)

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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                }
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
