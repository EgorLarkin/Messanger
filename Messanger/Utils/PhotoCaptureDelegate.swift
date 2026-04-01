import AVFoundation
import UIKit

final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let handler: (UIImage) -> Void

    init(handler: @escaping (UIImage) -> Void) {
        self.handler = handler
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if let error = error {
            print("Photo capture error: \(error)")
            return
        }

        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            print("Failed to get image data")
            return
        }

        handler(image)
    }
}
