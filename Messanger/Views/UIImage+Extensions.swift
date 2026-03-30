import UIKit
import SwiftUI

extension UIImage {
    func toBase64(compressionQuality: CGFloat = 0.8) -> String? {
        guard let data = jpegData(compressionQuality: compressionQuality) else {
            return nil
        }
        return "image/jpeg;base64,\(data.base64EncodedString())"
    }
}

extension Data {
    func toImage() -> UIImage? {
        return UIImage(data: self)
    }
}
