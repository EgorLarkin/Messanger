import SwiftUI

struct MessageRow: View {
    let message: Message
    let chatUser: User

    var body: some View {
        MessageBubble(
            message: message,
            sender: message.isFromMe ? nil : chatUser
        )
        .frame(
            maxWidth: .infinity,
            alignment: message.isFromMe ? .trailing : .leading
        )
    }
}
