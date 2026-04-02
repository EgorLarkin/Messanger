import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct MessageInputView: View {
    @State private var messageText: String = ""
    @State private var showAttachmentMenu = false

    @State private var showCameraPicker = false
    @State private var showLibraryPicker = false
    @State private var showFileImporter = false

    @State private var pickedImage: UIImage?
    @State private var pickedVideoURL: URL?

    var onSendText: ((String) -> Void)? = nil
    var onAddMediaDraft: (([PendingMediaItem]) -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            Button {
                showAttachmentMenu = true
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
        .confirmationDialog("Вложение", isPresented: $showAttachmentMenu, titleVisibility: .visible) {
            Button("Сделать снимок") {
                showCameraPicker = true
            }

            Button("Выбрать из галереи") {
                showLibraryPicker = true
            }

            Button("Выбрать файл") {
                showFileImporter = true
            }

            Button("Отмена", role: .cancel) { }
        }
        .sheet(isPresented: $showCameraPicker, onDismiss: handlePickedMedia) {
            CameraPicker(image: $pickedImage, videoURL: $pickedVideoURL)
        }
        .sheet(isPresented: $showLibraryPicker, onDismiss: handlePickedMedia) {
            MediaPicker(image: $pickedImage, videoURL: $pickedVideoURL)
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    print("📁 Selected file: \(url)")
                }
            case .failure(let error):
                print("❌ File import error: \(error)")
            }
        }
    }

    private func sendText() {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSendText?(trimmed)
        messageText = ""
    }

    private func handlePickedMedia() {
        if let image = pickedImage {
            let item = PendingMediaItem(
                image: image,
                videoURL: nil,
                fileName: "photo.jpg",
                kind: .image
            )
            onAddMediaDraft?([item])
            pickedImage = nil
            pickedVideoURL = nil
            return
        }

        if let videoURL = pickedVideoURL {
            let item = PendingMediaItem(
                image: nil,
                videoURL: videoURL,
                fileName: videoURL.lastPathComponent,
                kind: .video
            )
            onAddMediaDraft?([item])
            pickedImage = nil
            pickedVideoURL = nil
        }
    }
}
