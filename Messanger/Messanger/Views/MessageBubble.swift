import SwiftUI
import AVKit

struct MessageBubble: View {
    let message: Message
    let sender: User?

    var body: some View {
        Group {
            if message.isFromMe {
                content
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

                    content
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 8)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            bubbleContent
        }
        .background(message.isFromMe ? Color.blue : Color.gray.opacity(0.2))
        .foregroundColor(message.isFromMe ? .white : .primary)
        .cornerRadius(16)
    }

    @ViewBuilder
    private var bubbleContent: some View {
        switch message.type {
        case .text:
            Text(message.text)
                .font(.body)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: 250, alignment: .leading)

        case .image:
            VStack(alignment: .leading, spacing: 8) {
                if let image = message.image {
                    NavigationLink(destination: FullScreenImageView(image: image, fileName: message.fileName ?? "")) {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 220, height: 280)
                            .clipped()
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)
                    .padding(.horizontal, 6)
                } else {
                    fallbackPreview(icon: "photo", title: "Фото", height: 180)
                }

                mediaCaptionIfNeeded
            }

        case .video:
            VStack(alignment: .leading, spacing: 8) {
                if let url = message.videoURL {
                    NavigationLink(destination: VideoPlayerScreen(videoURL: url, fileName: message.fileName ?? "Видео")) {
                        ZStack(alignment: .bottomLeading) {
                            if let thumbnail = message.videoThumbnail {
                                thumbnail
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 220, height: 280)
                                    .clipped()
                                    .cornerRadius(12)
                            } else {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.black.opacity(0.12))
                                    .frame(width: 220, height: 180)
                            }

                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.black.opacity(0.04),
                                            Color.black.opacity(0.12),
                                            Color.black.opacity(0.35)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 220, height: message.videoThumbnail == nil ? 180 : 280)

                            VStack {
                                Spacer()

                                HStack {
                                    Spacer()

                                    ZStack {
                                        Circle()
                                            .fill(Color.black.opacity(0.45))
                                            .frame(width: 56, height: 56)

                                        Image(systemName: "play.fill")
                                            .font(.system(size: 24, weight: .semibold))
                                            .foregroundColor(.white)
                                            .padding(.leading, 3)
                                    }

                                    Spacer()
                                }

                                Spacer()
                            }
                            .frame(width: 220, height: message.videoThumbnail == nil ? 180 : 280)

                            if !message.formattedDuration.isEmpty {
                                Text(message.formattedDuration)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 4)
                                    .background(Color.black.opacity(0.65))
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                    .padding(10)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)
                    .padding(.horizontal, 6)
                } else {
                    fallbackPreview(icon: "video.fill", title: "Видео", height: 180)
                }

                mediaCaptionIfNeeded
            }

        case .file:
            HStack(spacing: 12) {
                Image(systemName: "doc.fill")
                    .font(.system(size: 28))

                VStack(alignment: .leading, spacing: 4) {
                    Text(message.fileName ?? "Файл")
                        .font(.headline)
                        .lineLimit(1)

                    if !message.formattedFileSize.isEmpty {
                        Text(message.formattedFileSize)
                            .font(.caption)
                            .foregroundColor(message.isFromMe ? .white.opacity(0.8) : .secondary)
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: 250)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

        case .voice:
            HStack(spacing: 12) {
                Image(systemName: "waveform")
                    .font(.system(size: 24))

                Text(message.formattedDuration.isEmpty ? "Голосовое сообщение" : message.formattedDuration)
                    .font(.body.monospacedDigit())

                Spacer(minLength: 0)
            }
            .frame(maxWidth: 250)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

        case .videoNote:
            if let url = message.videoURL {
                NavigationLink(destination: VideoPlayerScreen(videoURL: url, fileName: message.fileName ?? "Видеосообщение")) {
                    ZStack {
                        if let thumbnail = message.videoThumbnail {
                            thumbnail
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
                            .fill(Color.black.opacity(0.35))
                            .frame(width: 48, height: 48)

                        Image(systemName: "play.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.leading, 3)
                    }
                    .frame(width: 150, height: 150)
                }
                .buttonStyle(.plain)
                .padding(6)
            } else {
                fallbackPreview(icon: "video.fill", title: "Видеосообщение", height: 150, width: 150, circular: true)
            }
        }
    }

    @ViewBuilder
    private var mediaCaptionIfNeeded: some View {
        let trimmed = message.text.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmed.isEmpty {
            Text(trimmed)
                .font(.body)
                .foregroundColor(message.isFromMe ? .white : .primary)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
                .frame(maxWidth: 220, alignment: .leading)
        }
    }

    @ViewBuilder
    private func fallbackPreview(
        icon: String,
        title: String,
        height: CGFloat,
        width: CGFloat = 220,
        circular: Bool = false
    ) -> some View {
        ZStack {
            if circular {
                Circle()
                    .fill(Color.black.opacity(0.12))
                    .frame(width: width, height: height)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.12))
                    .frame(width: width, height: height)
            }

            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 34))

                Text(title)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 8)
            }
            .foregroundColor(.white)
        }
        .padding(6)
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
