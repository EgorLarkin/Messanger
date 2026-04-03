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
                        image: image,
                        videoURL: nil,
                        videoThumbnail: nil,
                        fileURL: nil,
                        fileName: "image.jpg",
                        type: .image
                    )
                    parent.items = [item]
                }
            } else if mediaType == kUTTypeMovie as String || mediaType == "public.movie" {
                if let url = info[.mediaURL] as? URL {
                    let thumbnail = generateThumbnail(for: url)
                    let item = PendingMediaItem(
                        image: nil,
                        videoURL: url,
                        videoThumbnail: thumbnail,
                        fileURL: nil,
                        fileName: url.lastPathComponent,
                        type: .video
                    )
                    parent.items = [item]
                }
            }
        }

        private func generateThumbnail(for url: URL) -> UIImage? {
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 400, height: 400)

            do {
                let cgImage = try generator.copyCGImage(
                    at: CMTime(seconds: 0.1, preferredTimescale: 600),
                    actualTime: nil
                )
                return UIImage(cgImage: cgImage)
            } catch {
                print("❌ Failed to generate thumbnail: \(error.localizedDescription)")
                return nil
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
