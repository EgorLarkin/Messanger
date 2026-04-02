import SwiftUI
import UIKit

struct DocumentPreviewController: UIViewControllerRepresentable {
    let fileURL: URL

    func makeCoordinator() -> Coordinator {
        Coordinator(fileURL: fileURL)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .clear

        DispatchQueue.main.async {
            context.coordinator.presentPreview(from: controller)
        }

        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) { }

    final class Coordinator: NSObject, UIDocumentInteractionControllerDelegate {
        private let fileURL: URL
        private var documentController: UIDocumentInteractionController?

        init(fileURL: URL) {
            self.fileURL = fileURL
        }

        func presentPreview(from viewController: UIViewController) {
            let controller = UIDocumentInteractionController(url: fileURL)
            controller.delegate = self
            self.documentController = controller
            controller.presentPreview(animated: true)
        }

        func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }?.rootViewController ?? UIViewController()
        }
    }
}
