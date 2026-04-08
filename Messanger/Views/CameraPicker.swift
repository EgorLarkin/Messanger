import SwiftUI
import UIKit
import AVFoundation
import MobileCoreServices

struct CameraPicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) private var presentationMode
    @Binding var items: [PendingMediaItem]

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPicker

        init(parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
        ) {
            defer {
                parent.presentationMode.wrappedValue.dismiss()
            }

            let mediaType = info[.mediaType] as? String

            if mediaType == kUTTypeImage as String || mediaType == "public.image" {
                if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
                    let item = PendingMediaItem(
                        type: .image,
                        image: image,
                        videoURL: nil,
                        fileURL: nil,
                        fileName: "image.jpg"
                    )
                    parent.items = [item]
                }
            } else if mediaType == kUTTypeMovie as String || mediaType == "public.movie" {
                if let url = info[.mediaURL] as? URL {
                    let item = PendingMediaItem(
                        type: .video,
                        image: nil,
                        videoURL: url,
                        fileURL: nil,
                        fileName: url.lastPathComponent
                    )
                    parent.items = [item]
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.mediaTypes = ["public.image", "public.movie"]
        picker.videoQuality = .typeHigh
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) { }
}
