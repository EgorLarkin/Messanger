import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct PickedMediaItem: Identifiable, Equatable {
    let id = UUID()
    let type: MediaType
    let image: UIImage?
    let videoURL: URL?
    let fileName: String

    static func == (lhs: PickedMediaItem, rhs: PickedMediaItem) -> Bool {
        lhs.id == rhs.id
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    var selectionLimit: Int = 20
    let onComplete: ([PickedMediaItem]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .any(of: [.images, .videos])
        configuration.selectionLimit = selectionLimit
        configuration.preferredAssetRepresentationMode = .current

        let controller = PHPickerViewController(configuration: configuration)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let onComplete: ([PickedMediaItem]) -> Void

        init(onComplete: @escaping ([PickedMediaItem]) -> Void) {
            self.onComplete = onComplete
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard !results.isEmpty else {
                DispatchQueue.main.async {
                    self.onComplete([])
                }
                return
            }

            let group = DispatchGroup()
            var collected: [(Int, PickedMediaItem)] = []
            let lock = NSLock()

            for (index, result) in results.enumerated() {
                let provider = result.itemProvider
                let assetIdentifier = result.assetIdentifier ?? UUID().uuidString

                if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    group.enter()

                    provider.loadObject(ofClass: UIImage.self) { object, _ in
                        defer { group.leave() }

                        guard let image = object as? UIImage else { return }

                        let item = PickedMediaItem(
                            type: .image,
                            image: image,
                            videoURL: nil,
                            fileName: "\(assetIdentifier).jpg"
                        )

                        lock.lock()
                        collected.append((index, item))
                        lock.unlock()
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                    group.enter()

                    provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, _ in
                        defer { group.leave() }

                        guard let sourceURL = url else { return }

                        let ext = sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension
                        let destinationURL = FileManager.default.temporaryDirectory
                            .appendingPathComponent(UUID().uuidString)
                            .appendingPathExtension(ext)

                        do {
                            if FileManager.default.fileExists(atPath: destinationURL.path) {
                                try FileManager.default.removeItem(at: destinationURL)
                            }
                            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

                            let item = PickedMediaItem(
                                type: .video,
                                image: nil,
                                videoURL: destinationURL,
                                fileName: sourceURL.lastPathComponent.isEmpty ? "\(assetIdentifier).\(ext)" : sourceURL.lastPathComponent
                            )

                            lock.lock()
                            collected.append((index, item))
                            lock.unlock()
                        } catch {
                            return
                        }
                    }
                }
            }

            group.notify(queue: .main) {
                let items = collected.sorted { $0.0 < $1.0 }.map { $0.1 }
                self.onComplete(items)
            }
        }
    }
}
