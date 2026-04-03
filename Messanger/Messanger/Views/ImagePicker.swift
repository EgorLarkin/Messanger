import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import AVFoundation

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var items: [PendingMediaItem]

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .any(of: [.images, .videos])
        config.selectionLimit = 0 // 0 = без лимита, можно выбирать несколько

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

                // IMAGE
                if provider.canLoadObject(ofClass: UIImage.self) {
                    dispatchGroup.enter()

                    provider.loadObject(ofClass: UIImage.self) { image, _ in
                        defer { dispatchGroup.leave() }

                        guard let uiImage = image as? UIImage else { return }

                        let item = PendingMediaItem(
                            image: uiImage,
                            videoURL: nil,
                            videoThumbnail: nil,
                            fileName: "image.jpg",
                            type: .image
                        )

                        DispatchQueue.main.async {
                            collectedItems.append(item)
                        }
                    }

                    continue
                }

                // VIDEO
                if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                    dispatchGroup.enter()

                    provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, _ in
                        defer { dispatchGroup.leave() }

                        guard let sourceURL = url else { return }

                        let tempDir = FileManager.default.temporaryDirectory
                        let targetURL = tempDir.appendingPathComponent(UUID().uuidString + "_" + sourceURL.lastPathComponent)

                        do {
                            if FileManager.default.fileExists(atPath: targetURL.path) {
                                try FileManager.default.removeItem(at: targetURL)
                            }
                            try FileManager.default.copyItem(at: sourceURL, to: targetURL)

                            let thumbnail = Self.generateThumbnail(from: targetURL)

                            let item = PendingMediaItem(
                                image: nil,
                                videoURL: targetURL,
                                videoThumbnail: thumbnail,
                                fileName: sourceURL.lastPathComponent,
                                type: .video
                            )

                            DispatchQueue.main.async {
                                collectedItems.append(item)
                            }
                        } catch {
                            print("❌ Failed to copy picked video: \(error)")
                        }
                    }
                }
            }

            dispatchGroup.notify(queue: .main) {
                self.parent.items = collectedItems
            }
        }

        static func generateThumbnail(from url: URL) -> UIImage? {
            let asset = AVAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true

            let time = CMTime(seconds: 0.1, preferredTimescale: 600)

            do {
                let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
                return UIImage(cgImage: cgImage)
            } catch {
                print("❌ Failed to generate video thumbnail: \(error)")
                return nil
            }
        }
    }
}
