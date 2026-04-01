import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct PendingMediaItem: Identifiable, Equatable {
    let id = UUID()
    var image: UIImage?
    var videoURL: URL?
    var fileURL: URL?
    var fileName: String?
    var type: MediaType
}

struct MessageInputView: View {
    @State private var messageText: String = ""
    @State private var showAttachmentMenu = false

    @State private var showCameraPicker = false
    @State private var showLibraryPicker = false
    @State private var showFileImporter = false

    @State private var pickedImage: UIImage?
    @State private var pickedVideoURL: URL?
    @State private var pickedFileURL: URL?

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
            handleFileImport(result)
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
                fileURL: nil,
                fileName: "photo.jpg",
                type: .image
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
                fileURL: nil,
                fileName: videoURL.lastPathComponent,
                type: .video
            )
            onAddMediaDraft?([item])
            pickedImage = nil
            pickedVideoURL = nil
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let sourceURL = urls.first else { return }

            do {
                let localURL = try copyImportedFileToTemporaryDirectory(from: sourceURL)

                let item = PendingMediaItem(
                    image: nil,
                    videoURL: nil,
                    fileURL: localURL,
                    fileName: localURL.lastPathComponent,
                    type: .file
                )

                onAddMediaDraft?([item])
                pickedFileURL = localURL

            } catch {
                print("❌ File import copy error: \(error)")
            }

        case .failure(let error):
            print("❌ File import error: \(error)")
        }
    }
    
    private func copyImportedFileToTemporaryDirectory(from sourceURL: URL) throws -> URL {
        let gainedAccess = sourceURL.startAccessingSecurityScopedResource()

        defer {
            if gainedAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let fileManager = FileManager.default
        let originalName = sourceURL.lastPathComponent.isEmpty ? "file" : sourceURL.lastPathComponent
        let ext = sourceURL.pathExtension
        let baseName = UUID().uuidString
        let tempFileName = ext.isEmpty ? baseName : "\(baseName).\(ext)"
        let destinationURL = fileManager.temporaryDirectory.appendingPathComponent(tempFileName)

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        do {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        } catch {
            let data = try Data(contentsOf: sourceURL)
            try data.write(to: destinationURL, options: .atomic)
        }

        return destinationURL
    }
}
