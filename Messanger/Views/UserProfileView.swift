import SwiftUI

struct UserProfileView: View {
    let user: User
    @Environment(\.dismiss) private var dismiss

    @State private var showFullAvatar = false

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Button {
                    showFullAvatar = true
                } label: {
                    AvatarView(user: user, size: 100)
                }
                .buttonStyle(.plain)

                VStack(spacing: 4) {
                    Text(user.name)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("@\(user.username)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Профиль")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
            .fullScreenCover(isPresented: $showFullAvatar) {
                FullScreenAvatarView(user: user)
            }
        }
    }
}
