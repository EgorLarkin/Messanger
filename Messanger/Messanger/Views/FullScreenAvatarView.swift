import SwiftUI

struct FullScreenAvatarView: View {
    let user: User
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack {
                Spacer()

                if let image = user.avatarImage {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding()
                } else {
                    AvatarView(user: user, size: 200)
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Text("Закрыть")
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(20)
                }
                .padding(.bottom, 40)
            }
        }
    }
}
