import SwiftUI

struct MessageRow: View {
    let message: Message
    let chatUser: User

    var body: some View {
        HStack {
            if message.isFromMe {
                Spacer()
                MessageBubble(message: message, sender: nil)
            } else {
                MessageBubble(message: message, sender: chatUser)
                Spacer()
            }
        }
    }
}
