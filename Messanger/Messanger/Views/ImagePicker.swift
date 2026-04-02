import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Binding var videoURL: URL?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.selectionLimit = 1
        configuration.filter = .any(of: [.images, .videos])

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) { }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let result = results.first else { return }

            if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                result.itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
                    DispatchQueue.main.async {
                        self.parent.videoURL = nil
                        self.parent.image = object as? UIImage
                    }
                }
                return
            }

            let movieType = UTType.movie.identifier
            if result.itemProvider.hasItemConformingToTypeIdentifier(movieType) {
                result.itemProvider.loadFileRepresentation(forTypeIdentifier: movieType) { url, _ in
                    guard let url = url else { return }

                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString + "." + url.pathExtension)

                    do {
                        if FileManager.default.fileExists(atPath: tempURL.path) {
                            try FileManager.default.removeItem(at: tempURL)
                        }

                        try FileManager.default.copyItem(at: url, to: tempURL)

                        DispatchQueue.main.async {
                            self.parent.image = nil
                            self.parent.videoURL = tempURL
                        }
                    } catch {
                        print("❌ Failed to copy picked video: \(error)")
                    }
                }
            }
        }
    }
}
