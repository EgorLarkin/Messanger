import SwiftUI
import AVFoundation

struct VideoThumbnailView: View {
    let url: URL
    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color.black.opacity(0.15))

                ProgressView()
            }

            Image(systemName: "play.circle.fill")
                .font(.system(size: 44))
                .foregroundColor(.white)
                .shadow(radius: 8)
        }
        .task {
            if thumbnail == nil {
                thumbnail = generateThumbnail(url: url)
            }
        }
    }

    private func generateThumbnail(url: URL) -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 600, height: 600)

        do {
            let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            print("❌ Video thumbnail error: \(error)")
            return nil
        }
    }
}
