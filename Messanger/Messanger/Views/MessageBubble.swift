import SwiftUI
import AVFoundation
import AVKit
import UIKit

struct MessageBubble: View {
    let message: Message
    let sender: User?

    var body: some View {
        Group {
            if message.isFromMe {
                myMessageView
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
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
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Outgoing

    @ViewBuilder
    private var myMessageView: some View {
        VStack(alignment: .trailing, spacing: 4) {
            mediaContentView
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(16)

            if message.type != .text && !message.formattedDuration.isEmpty && message.type != .video {
                Text(message.formattedDuration)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 8)
            }
        }
    }

    // MARK: - Incoming

    @ViewBuilder
    private var otherMessageView: some View {
        VStack(alignment: .leading, spacing: 4) {
            mediaContentView
                .background(Color.gray.opacity(0.2))
                .foregroundColor(.primary)
                .cornerRadius(16)

            if message.type != .text && !message.formattedDuration.isEmpty && message.type != .video {
                Text(message.formattedDuration)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 8)
            }
        }
    }

    // MARK: - Content switch

    @ViewBuilder
    private var mediaContentView: some View {
        switch message.type {
        case .text:
            Text(message.text)
                .font(.body)
                .foregroundColor(message.isFromMe ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: 250, alignment: .leading)

        case .image:
            imageContent

        case .video:
            videoContent

        case .file:
            fileContent

        case .voice:
            voiceContent

        case .videoNote:
            videoNoteContent
        }
    }

    // MARK: - Image

    @ViewBuilder
    private var imageContent: some View {
        let images = message.allImages

        if images.count <= 1 {
            if let image = images.first {
                VStack(alignment: .leading, spacing: 0) {
                    NavigationLink(
                        destination: FullScreenImageView(
                            image: image,
                            fileName: message.fileName ?? "Фото"
                        )
                    ) {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 220, maxHeight: 220)
                            .cornerRadius(12)
                            .clipped()
                    }
                    .buttonStyle(PlainButtonStyle())

                    if !message.text.isEmpty {
                        Text(message.text)
                            .font(.body)
                            .foregroundColor(message.isFromMe ? .white : .primary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: 250, alignment: .leading)
                            .padding(.top, 8)
                            .padding(.horizontal, 10)
                            .padding(.bottom, 8)
                    }
                }
                .padding(6)
            } else {
                fallbackImageView
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 4),
                        GridItem(.flexible(), spacing: 4)
                    ],
                    spacing: 4
                ) {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                        NavigationLink(
                            destination: FullScreenImageView(
                                image: image,
                                fileName: "Фото \(index + 1)"
                            )
                        ) {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 100, height: 100)
                                .clipped()
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .frame(maxWidth: 220)

                if !message.text.isEmpty {
                    Text(message.text)
                        .font(.body)
                        .foregroundColor(message.isFromMe ? .white : .primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 250, alignment: .leading)
                        .padding(.top, 4)
                        .padding(.horizontal, 6)
                        .padding(.bottom, 4)
                }
            }
            .padding(6)
        }
    }

    private var fallbackImageView: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.7))
            Text("Фото")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(width: 220, height: 180)
    }

    // MARK: - Video

    @ViewBuilder
    private var videoContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let url = message.videoURL {
                NavigationLink(destination: VideoPlayerView(url: url)) {
                    VideoThumbnailView(
                        url: url,
                        durationText: message.formattedDuration,
                        width: 220,
                        height: 220
                    )
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                fallbackVideoView
            }

            if !message.text.isEmpty {
                Text(message.text)
                    .font(.body)
                    .foregroundColor(message.isFromMe ? .white : .primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 250, alignment: .leading)
                    .padding(.top, 4)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var fallbackVideoView: some View {
        VStack(spacing: 8) {
            Image(systemName: "video")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.7))
            Text("Видео")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(width: 220, height: 180)
    }

    // MARK: - File

    @ViewBuilder
    private var fileContent: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.fill")
                .font(.system(size: 30))

            VStack(alignment: .leading, spacing: 4) {
                Text(message.fileName ?? "Файл")
                    .font(.headline)
                    .lineLimit(1)

                if let size = message.fileSize {
                    Text(formatFileSize(size))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: 250, alignment: .leading)
    }

    // MARK: - Voice

    @ViewBuilder
    private var voiceContent: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.system(size: 24))

            Text(message.formattedDuration.isEmpty ? "Голосовое" : message.formattedDuration)
                .font(.body)
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: 250, alignment: .leading)
    }

    // MARK: - Video note

    @ViewBuilder
    private var videoNoteContent: some View {
        if let url = message.videoURL {
            NavigationLink(destination: VideoPlayerView(url: url)) {
                CircularVideoThumbnailView(url: url, size: 150)
            }
            .buttonStyle(PlainButtonStyle())
        } else {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.3))
                    .frame(width: 150, height: 150)

                Image(systemName: "video.slash")
                    .font(.system(size: 40))
                    .foregroundColor(.white.opacity(0.5))
            }
            .frame(width: 150, height: 150)
        }
    }

    // MARK: - Helpers

    private func formatFileSize(_ size: Int) -> String {
        if size < 1024 {
            return "\(size) Б"
        } else if size < 1024 * 1024 {
            return String(format: "%.1f КБ", Double(size) / 1024)
        } else {
            return String(format: "%.1f МБ", Double(size) / (1024 * 1024))
        }
    }
}

// MARK: - Thumbnail Views

struct VideoThumbnailView: View {
    let url: URL
    let durationText: String
    let width: CGFloat
    let height: CGFloat

    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(Color.black.opacity(0.15))
                        .overlay(
                            ProgressView()
                                .tint(.white)
                        )
                }
            }
            .frame(width: width, height: min(height, 220))
            .clipped()
            .cornerRadius(12)

            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.55))
                    .frame(width: 44, height: 44)

                Image(systemName: "play.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.leading, 2)
            }
            .padding(8)

            if !durationText.isEmpty {
                Text(durationText)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(8)
                    .offset(x: -46, y: 0)
            }
        }
        .frame(width: width, height: min(height, 220))
        .task {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        if thumbnail != nil { return }

        let loaded = await VideoFrameLoader.generateThumbnail(from: url)
        await MainActor.run {
            self.thumbnail = loaded
        }
    }
}

struct CircularVideoThumbnailView: View {
    let url: URL
    let size: CGFloat

    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack {
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.black.opacity(0.3))
                    .frame(width: size, height: size)
                    .overlay(
                        ProgressView()
                            .tint(.white)
                    )
            }

            Circle()
                .fill(Color.black.opacity(0.5))
                .frame(width: 50, height: 50)

            Image(systemName: "play.fill")
                .font(.system(size: 24))
                .foregroundColor(.white)
                .padding(.leading, 2)
        }
        .frame(width: size, height: size)
        .task {
            if thumbnail == nil {
                thumbnail = await VideoFrameLoader.generateThumbnail(from: url)
            }
        }
    }
}

// MARK: - Video loader

enum VideoFrameLoader {
    private static var localCache: [String: URL] = [:]

    static func generateThumbnail(from url: URL) async -> UIImage? {
        let localURL = await prepareLocalURL(from: url)

        guard let localURL = localURL else {
            print("❌ Failed to prepare local file for thumbnail: \(url)")
            return nil
        }

        let asset = AVURLAsset(url: localURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 600, height: 600)

        let times: [Double] = [0.0, 0.05, 0.1, 0.25, 0.5, 1.0]

        for second in times {
            let time = CMTime(seconds: second, preferredTimescale: 600)
            do {
                let result = try await generator.image(at: time)
                return UIImage(cgImage: result.image)
            } catch {
                continue
            }
        }

        print("❌ Could not generate thumbnail from local url: \(localURL)")
        return nil
    }

    private static func prepareLocalURL(from url: URL) async -> URL? {
        if url.isFileURL {
            return url
        }

        let cacheKey = url.absoluteString

        if let cached = localCache[cacheKey],
           FileManager.default.fileExists(atPath: cached.path) {
            return cached
        }

        guard let token = AuthManager.shared.token, !token.isEmpty else {
            print("❌ Failed to download remote video: missing auth token")
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Failed to download remote video: invalid response")
                return nil
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let responseText = String(data: data, encoding: .utf8) ?? "No response body"
                print("❌ Failed to download remote video: status=\(httpResponse.statusCode), body=\(responseText)")
                return nil
            }

            let ext = url.pathExtension.isEmpty ? "mp4" : url.pathExtension
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(ext)

            try data.write(to: tempURL, options: .atomic)
            localCache[cacheKey] = tempURL
            return tempURL
        } catch {
            print("❌ Failed to download remote video: \(error.localizedDescription)")
            return nil
        }
    }
}
