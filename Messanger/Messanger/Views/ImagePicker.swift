import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import AVFoundation

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var items: [PendingMediaItem]

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .any(of: [.images, .videos])
        config.selectionLimit = 0

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard !results.isEmpty else { return }

            var collectedItems: [PendingMediaItem] = []
            let dispatchGroup = DispatchGroup()

            for result in results {
                let provider = result.itemProvider

                if provider.canLoadObject(ofClass: UIImage.self) {
                    dispatchGroup.enter()

                    provider.loadObject(ofClass: UIImage.self) { image, error in
                        defer { dispatchGroup.leave() }

                        if let error = error {
                            print("❌ Failed to load picked image: \(error.localizedDescription)")
                            return
                        }

                        guard let uiImage = image as? UIImage else { return }

                        let item = PendingMediaItem(
                            type: .image,
                            image: uiImage,
                            videoURL: nil,
                            fileURL: nil,
                            fileName: "image.jpg"
                        )

                        DispatchQueue.main.async {
                            collectedItems.append(item)
                        }
                    }

                    continue
                }

                if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                    dispatchGroup.enter()

                    provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                        defer { dispatchGroup.leave() }

                        if let error = error {
                            print("❌ Failed to load picked video: \(error.localizedDescription)")
                            return
                        }

                        guard let sourceURL = url else { return }

                        let tempDir = FileManager.default.temporaryDirectory
                        let targetURL = tempDir.appendingPathComponent(
                            UUID().uuidString + "_" + sourceURL.lastPathComponent
                        )

                        do {
                            if FileManager.default.fileExists(atPath: targetURL.path) {
                                try FileManager.default.removeItem(at: targetURL)
                            }

                            try FileManager.default.copyItem(at: sourceURL, to: targetURL)

                            let item = PendingMediaItem(
                                type: .video,
                                image: nil,
                                videoURL: targetURL,
                                fileURL: nil,
                                fileName: sourceURL.lastPathComponent
                            )

                            DispatchQueue.main.async {
                                collectedItems.append(item)
                            }
                        } catch {
                            print("❌ Failed to copy picked video: \(error.localizedDescription)")
                        }
                    }

                    continue
                }

                if provider.hasItemConformingToTypeIdentifier(UTType.data.identifier) {
                    dispatchGroup.enter()

                    provider.loadFileRepresentation(forTypeIdentifier: UTType.data.identifier) { url, error in
                        defer { dispatchGroup.leave() }

                        if let error = error {
                            print("❌ Failed to load picked file: \(error.localizedDescription)")
                            return
                        }

                        guard let sourceURL = url else { return }

                        let tempDir = FileManager.default.temporaryDirectory
                        let targetURL = tempDir.appendingPathComponent(
                            UUID().uuidString + "_" + sourceURL.lastPathComponent
                        )

                        do {
                            if FileManager.default.fileExists(atPath: targetURL.path) {
                                try FileManager.default.removeItem(at: targetURL)
                            }

                            try FileManager.default.copyItem(at: sourceURL, to: targetURL)

                            let item = PendingMediaItem(
                                type: .file,
                                image: nil,
                                videoURL: nil,
                                fileURL: targetURL,
                                fileName: sourceURL.lastPathComponent
                            )

                            DispatchQueue.main.async {
                                collectedItems.append(item)
                            }
                        } catch {
                            print("❌ Failed to copy picked file: \(error.localizedDescription)")
                        }
                    }
                }
            }

            dispatchGroup.notify(queue: .main) {
                self.parent.items = collectedItems
            }
        }
    }
}
