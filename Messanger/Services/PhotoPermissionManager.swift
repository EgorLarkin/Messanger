import Photos
import UIKit

final class PhotoPermissionManager {
    static func requestFullAccessIfNeeded(completion: @escaping (PHAuthorizationStatus) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        switch status {
        case .authorized:
            completion(.authorized)

        case .limited:
            // Уже есть частичный доступ — можно работать, но предложить расширить
            completion(.limited)

        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                DispatchQueue.main.async {
                    completion(newStatus)
                }
            }

        case .denied, .restricted:
            completion(status)

        @unknown default:
            completion(status)
        }
    }

    static func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
