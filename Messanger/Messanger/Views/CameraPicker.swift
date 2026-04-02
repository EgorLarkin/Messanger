import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct CameraPicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss

    @Binding var image: UIImage?
    @Binding var videoURL: URL?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = [UTType.image.identifier, UTType.movie.identifier]
        picker.videoQuality = .typeMedium
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) { }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
        ) {
            if let mediaType = info[.mediaType] as? String {
                if mediaType == UTType.image.identifier,
                   let pickedImage = info[.originalImage] as? UIImage {
                    parent.image = pickedImage
                    parent.videoURL = nil
                } else if mediaType == UTType.movie.identifier,
                          let pickedVideoURL = info[.mediaURL] as? URL {
                    parent.videoURL = pickedVideoURL
                    parent.image = nil
                }
            }

            parent.dismiss()
        }
    }
}
