import SwiftUI
import UIKit

struct PendingMediaItem: Identifiable, Equatable {
    let id = UUID()
    var image: UIImage?
    var videoURL: URL?
    var type: MediaType
    var fileName: String
}

struct MessageInputView: View {
    @State private var messageText: String = ""
    @State private var showMediaPicker = false

    var onSendText: ((String) -> Void)? = nil
    var onAddMediaDraft: (([PendingMediaItem]) -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            Button {
                showMediaPicker = true
            } label: {
                Image(systemName: "paperclip.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.blue)
            }

            TextField("Сообщение", text: $messageText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(minHeight: 36)

            Button(action: sendText) {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(
                        messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? .gray
                        : .blue
                    )
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .sheet(isPresented: $showMediaPicker) {
            ImagePicker(selectionLimit: 20) { pickedItems in
                let mapped = pickedItems.map {
                    PendingMediaItem(
                        image: $0.image,
                        videoURL: $0.videoURL,
                        type: $0.type,
                        fileName: $0.fileName
                    )
                }

                if !mapped.isEmpty {
                    onAddMediaDraft?(mapped)
                }
            }
        }
    }

    private func sendText() {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSendText?(trimmed)
        messageText = ""
    }
}
