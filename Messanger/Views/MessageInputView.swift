// MessageInputView for sending new messages in the conversation.
import SwiftUI

struct MessageInputView: View {
    @State private var messageText: String = ""
    var onSend: ((String) -> Void)? = nil

    var body: some View {
        HStack {
            TextField("Сообщение", text: $messageText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(minHeight: 30)
            Button(action: sendMessage) {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(messageText.isEmpty ? .gray : .blue)
            }
            .disabled(messageText.isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        onSend?(messageText)
        messageText = ""
    }
}
