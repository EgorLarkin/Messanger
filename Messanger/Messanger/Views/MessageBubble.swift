import SwiftUI
import AVKit
import AVFoundation

struct MessageBubble: View {
    let message: Message
    let sender: User?

    private var bubbleBackground: Color {
        message.isFromMe ? Color.blue : Color.gray.opacity(0.2)
    }

    private var bubbleForeground: Color {
        message.isFromMe ? .white : .primary
    }

    private var captionTextColor: Color {
        message.isFromMe ? .white : .primary
    }

    var body: some View {
        Group {
            if message.isFromMe {
                myMessageView
                    .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                HStack(alignment: .bottom, spacing: 8) {
                    if let sender = sender {
                        AvatarView(user: sender, size: 32)
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 32, height: 32)
                    }

                    otherMessageView
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 8)
    }

    @ViewBuilder
    private var myMessageView: some View {
        VStack(alignment: .trailing, spacing: 4) {
            mediaContentView

            if shouldShowDuration {
                Text(message.formattedDuration)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 8)
            }
        }
    }

    @ViewBuilder
    private var otherMessageView: some View {
        VStack(alignment: .leading, spacing: 4) {
            mediaContentView

            if shouldShowDuration {
                Text(message.formattedDuration)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 8)
            }
        }
    }

    private var shouldShowDuration: Bool {
        message.type != .text && !message.formattedDuration.isEmpty
    }

    @ViewBuilder
    private var mediaContentView: some View {
        switch message.type {
        case .text:
            textBubble(message.text)

        case .image:
            if message.hasAttachments, message.allImages.count > 1 {
                groupedImagesBubble
            } else {
                singleImageBubble
            }

        case .video:
            videoBubble

        case .file:
            fileBubble

        case .voice:
            voiceBubble

        case .videoNote:
            videoNoteBubble
        }
    }

    private func textBubble(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .foregroundColor(bubbleForeground)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: 250, alignment: .leading)
            .background(bubbleBackground)
            .cornerRadius(16)
    }

    private var singleImageBubble: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let image = message.image {
                NavigationLink(destination: FullScreenImageView(image: image, fileName: message.fileName ?? "Фото")) {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: 220, maxHeight: 260)
                        .clipped()
                        .cornerRadius(14)
                }
                .buttonStyle(.plain)
            } else {
                fallbackImageView
            }

            if !message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(message.text)
                    .font(.body)
                    .foregroundColor(captionTextColor)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 2)
                    .frame(maxWidth: 220, alignment: .leading)
            }
        }
        .padding(6)
        .background(bubbleBackground)
        .cornerRadius(18)
    }

    private var groupedImagesBubble: some View {
        VStack(alignment: .leading, spacing: 8) {
            imagesGrid(images: message.allImages)

            if !message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(message.text)
                    .font(.body)
                    .foregroundColor(captionTextColor)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 4)
                    .frame(maxWidth: 240, alignment: .leading)
            }
        }
        .padding(6)
        .background(bubbleBackground)
        .cornerRadius(18)
    }

    @ViewBuilder
    private func imagesGrid(images: [Image]) -> some View {
        let limitedImages = Array(images.prefix(4))

        if limitedImages.count == 2 {
            HStack(spacing: 4) {
                imageCell(limitedImages[0], name: "Фото 1")
                imageCell(limitedImages[1], name: "Фото 2")
            }
        } else if limitedImages.count == 3 {
            VStack(spacing: 4) {
                imageCell(limitedImages[0], name: "Фото 1", width: 220, height: 140)

                HStack(spacing: 4) {
                    imageCell(limitedImages[1], name: "Фото 2", width: 108, height: 88)
                    imageCell(limitedImages[2], name: "Фото 3", width: 108, height: 88)
                }
            }
        } else if limitedImages.count >= 4 {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    imageCell(limitedImages[0], name: "Фото 1", width: 108, height: 90)
                    imageCell(limitedImages[1], name: "Фото 2", width: 108, height: 90)
                }

                HStack(spacing: 4) {
                    imageCell(limitedImages[2], name: "Фото 3", width: 108, height: 90)
                    imageCell(limitedImages[3], name: "Фото 4", width: 108, height: 90)
                }
            }
        } else if let first = limitedImages.first {
            imageCell(first, name: "Фото", width: 220, height: 180)
        }
    }

    private func imageCell(_ image: Image, name: String, width: CGFloat = 108, height: CGFloat = 120) -> some View {
        NavigationLink(destination: FullScreenImageView(image: image, fileName: name)) {
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: width, height: height)
                .clipped()
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    private var fallbackImageView: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.7))

            Text(message.displayText.isEmpty ? "Фото" : message.displayText)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(width: 220, height: 180)
    }

    private var videoBubble: some View {
        Group {
            if let url = message.videoURL {
                NavigationLink(destination: VideoPlayerScreen(videoURL: url, fileName: message.fileName ?? "Видео")) {
                    VideoThumbnailCard(
                        videoURL: url,
                        title: message.fileName ?? "Видео",
                        caption: message.text,
                        isFromMe: message.isFromMe,
                        width: 220,
                        height: 150,
                        cornerRadius: 14
                    )
                }
                .buttonStyle(.plain)
            } else {
                fallbackVideoView
            }
        }
    }

    private var videoNoteBubble: some View {
        Group {
            if let url = message.videoURL {
                NavigationLink(destination: VideoPlayerScreen(videoURL: url, fileName: message.fileName ?? "Видеосообщение")) {
                    VideoThumbnailCircle(videoURL: url)
                }
                .buttonStyle(.plain)
            } else {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.15))
                        .frame(width: 150, height: 150)

                    Image(systemName: "video.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(width: 150, height: 150)
            }
        }
    }

    private var fallbackVideoView: some View {
        VStack(spacing: 8) {
            Image(systemName: "video")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.7))

            Text(message.fileName ?? "Видео")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(width: 220, height: 150)
        .background(bubbleBackground)
        .cornerRadius(16)
    }

    private var fileBubble: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.fill")
                .font(.system(size: 30))
                .foregroundColor(bubbleForeground)

            VStack(alignment: .leading, spacing: 4) {
                Text(message.fileName ?? "Файл")
                    .font(.headline)
                    .foregroundColor(bubbleForeground)
                    .lineLimit(1)

                if let size = message.fileSize {
                    Text(formatFileSize(size))
                        .font(.caption)
                        .foregroundColor(message.isFromMe ? .white.opacity(0.8) : .gray)
                }

                if !message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(message.text)
                        .font(.caption)
                        .foregroundColor(message.isFromMe ? .white.opacity(0.9) : .secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: 250, alignment: .leading)
        .background(bubbleBackground)
        .cornerRadius(16)
    }

    private var voiceBubble: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.system(size: 24))
                .foregroundColor(bubbleForeground)

            Text(message.formattedDuration.isEmpty ? "Голосовое сообщение" : message.formattedDuration)
                .font(.body.monospacedDigit())
                .foregroundColor(bubbleForeground)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: 250, alignment: .leading)
        .background(bubbleBackground)
        .cornerRadius(16)
    }

    private func formatFileSize(_ size: Int) -> String {
        if size < 1024 {
            return "\(size) Б"
        } else if size < 1024 * 1024 {
            return String(format: "%.1f КБ", Double(size) / 1024)
        } else {
            return String(format: "%.1f МБ", Double(size) / 1024 / 1024)
        }
    }
}

struct VideoThumbnailCard: View {
    let videoURL: URL
    let title: String
    let caption: String
    let isFromMe: Bool
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat

    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipped()
            } else {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(isFromMe ? Color.blue.opacity(0.85) : Color.gray.opacity(0.12))
                    .frame(width: width, height: height)
            }

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.05),
                            Color.black.opacity(0.18),
                            Color.black.opacity(0.42)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: width, height: height)
                .clipped()

            VStack {
                Spacer()

                HStack {
                    Spacer()

                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.35))
                            .frame(width: 48, height: 48)

                        Image(systemName: "play.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                            .padding(.leading, 3)
                    }

                    Spacer()
                }

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)

                    if !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(caption)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.92))
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task(id: videoURL) {
            if thumbnail == nil {
                thumbnail = await VideoThumbnailGenerator.generate(from: videoURL)
            }
        }
    }
}

struct VideoThumbnailCircle: View {
    let videoURL: URL
    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 150, height: 150)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.black.opacity(0.15))
                    .frame(width: 150, height: 150)
            }

            Circle()
                .fill(Color.black.opacity(0.22))
                .frame(width: 150, height: 150)

            Circle()
                .fill(Color.black.opacity(0.5))
                .frame(width: 50, height: 50)

            Image(systemName: "play.fill")
                .font(.system(size: 24))
                .foregroundColor(.white)
                .padding(.leading, 3)
        }
        .frame(width: 150, height: 150)
        .task(id: videoURL) {
            if thumbnail == nil {
                thumbnail = await VideoThumbnailGenerator.generate(from: videoURL)
            }
        }
    }
}

enum VideoThumbnailGenerator {
    static func generate(from url: URL) async -> UIImage? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let asset = AVURLAsset(url: url)
                let generator = AVAssetImageGenerator(asset: asset)
                generator.appliesPreferredTrackTransform = true
                generator.requestedTimeToleranceBefore = .zero
                generator.requestedTimeToleranceAfter = .zero
                generator.maximumSize = CGSize(width: 1000, height: 1000)

                let times: [CMTime] = [
                    CMTime(seconds: 0.1, preferredTimescale: 600),
                    CMTime(seconds: 0.0, preferredTimescale: 600),
                    CMTime(seconds: 0.25, preferredTimescale: 600),
                    CMTime(seconds: 0.5, preferredTimescale: 600),
                    CMTime(seconds: 1.0, preferredTimescale: 600)
                ]

                for time in times {
                    do {
                        let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
                        let image = UIImage(cgImage: cgImage)
                        DispatchQueue.main.async {
                            continuation.resume(returning: image)
                        }
                        return
                    } catch {
                        continue
                    }
                }

                DispatchQueue.main.async {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

struct VideoPlayerScreen: View {
    let videoURL: URL
    let fileName: String

    var body: some View {
        VideoPlayer(player: AVPlayer(url: videoURL))
            .navigationTitle(fileName)
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.black.ignoresSafeArea())
    }
}
