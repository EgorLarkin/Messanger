import SwiftUI

struct MessageInputView: View {
    @State private var messageText: String = ""
    @State private var showAttachmentMenu = false

    var onSend: ((String) -> Void)? = nil
    var onCameraTap: (() -> Void)? = nil
    var onGalleryTap: (() -> Void)? = nil
    var onFileTap: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            Button(action: {
                showAttachmentMenu = true
            }) {
                Image(systemName: "paperclip")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.blue)
                    .frame(width: 36, height: 36)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Circle())
            }

            TextField("Сообщение", text: $messageText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(minHeight: 36)

            Button(action: sendMessage) {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                    .frame(width: 36, height: 36)
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .confirmationDialog("Вложение", isPresented: $showAttachmentMenu, titleVisibility: .visible) {
            Button("Сделать снимок") {
                onCameraTap?()
            }
            Button("Выбрать из галереи") {
                onGalleryTap?()
            }
            Button("Выбрать файл") {
                onFileTap?()
            }
            Button("Отмена", role: .cancel) { }
        }
    }

    private func sendMessage() {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSend?(trimmed)
        messageText = ""
    }
}
