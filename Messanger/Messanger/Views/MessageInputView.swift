import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct PendingMediaItem: Identifiable, Equatable {
    let id = UUID()
    var image: UIImage?
    var videoURL: URL?
    var videoThumbnail: UIImage?
    var fileURL: URL?
    var fileName: String
    var type: MediaType
}

struct MessageInputView: View {
    @State private var messageText = ""

    var onSendText: ((String) -> Void)? = nil
    var onAddMediaDraft: (([PendingMediaItem]) -> Void)? = nil

    @State private var showAttachmentMenu = false

    @State private var showCamera = false
    @State private var cameraItems: [PendingMediaItem] = []

    @State private var showImagePicker = false
    @State private var pickedItems: [PendingMediaItem] = []

    @State private var showFileImporter = false

    var body: some View {
        HStack(spacing: 8) {
            Button {
                showAttachmentMenu = true
            } label: {
                Image(systemName: "paperclip.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.blue)
            }
            .confirmationDialog("Вложение", isPresented: $showAttachmentMenu, titleVisibility: .visible) {
                Button("Сделать снимок") {
                    showCamera = true
                }

                Button("Выбрать из галереи") {
                    showImagePicker = true
                }

                Button("Выбрать файл") {
                    showFileImporter = true
                }

                Button("Отмена", role: .cancel) { }
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
        .sheet(isPresented: $showCamera, onDismiss: handleCameraItems) {
            CameraPicker(items: $cameraItems)
        }
        .sheet(isPresented: $showImagePicker, onDismiss: handlePickedItems) {
            ImagePicker(items: $pickedItems)
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
    }

    private func sendText() {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSendText?(trimmed)
        messageText = ""
    }

    private func handlePickedItems() {
        guard !pickedItems.isEmpty else { return }
        onAddMediaDraft?(pickedItems)
        pickedItems = []
    }

    private func handleCameraItems() {
        guard !cameraItems.isEmpty else { return }
        onAddMediaDraft?(cameraItems)
        cameraItems = []
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            let items = urls.compactMap { importedURL -> PendingMediaItem? in
                let secured = importedURL.startAccessingSecurityScopedResource()
                defer {
                    if secured {
                        importedURL.stopAccessingSecurityScopedResource()
                    }
                }

                let ext = importedURL.pathExtension
                let fileName = importedURL.lastPathComponent
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString + "-" + fileName)

                do {
                    if FileManager.default.fileExists(atPath: tempURL.path) {
                        try FileManager.default.removeItem(at: tempURL)
                    }
                    try FileManager.default.copyItem(at: importedURL, to: tempURL)

                    return PendingMediaItem(
                        image: nil,
                        videoURL: nil,
                        videoThumbnail: nil,
                        fileURL: tempURL,
                        fileName: fileName.isEmpty ? "file.\(ext)" : fileName,
                        type: .file
                    )
                } catch {
                    print("❌ Failed to copy imported file: \(error.localizedDescription)")
                    return nil
                }
            }

            guard !items.isEmpty else { return }
            onAddMediaDraft?(items)

        case .failure(let error):
            print("❌ File import error: \(error.localizedDescription)")
        }
    }
}
