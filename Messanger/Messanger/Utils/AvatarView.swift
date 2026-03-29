import SwiftUI
import UIKit

struct AvatarView: View {
    let user: User
    let size: CGFloat
    
    var body: some View {
        Group {
            if let avatarImage = user.avatarImage {
                avatarImage
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                ZStack {
                    Circle()
                        .fill(user.avatarColor)
                    
                    Text(user.initials)
                        .font(.system(size: size * 0.4, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: size, height: size)
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
