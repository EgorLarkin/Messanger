import SwiftUI
import AVKit

struct MessageBubble: View {
    let message: Message
    let sender: User?
    
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
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 8)
    }
    
    @ViewBuilder private var myMessageView: some View {
        VStack(alignment: .trailing, spacing: 4) {
            mediaContentView
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(16)
            if message.type != .text && !message.formattedDuration.isEmpty {
                Text(message.formattedDuration)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 8)
            }
        }
    }
    
    @ViewBuilder private var otherMessageView: some View {
        VStack(alignment: .leading, spacing: 4) {
            mediaContentView
                .background(Color.gray.opacity(0.2))
                .foregroundColor(.primary)
                .cornerRadius(16)
            if message.type != .text && !message.formattedDuration.isEmpty {
                Text(message.formattedDuration)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 8)
            }
        }
    }
    
    @ViewBuilder private var mediaContentView: some View {
        switch message.type {
        case .text:
            Text(message.text)
                .font(.body)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: 250, alignment: .leading)
        case .image:
            if let image = message.image {
                NavigationLink(
                    destination: FullScreenImageView(
                        image: image,
                        fileName: message.fileName ?? "Фото"
                    )
                ) {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 200, maxHeight: 200)
                        .cornerRadius(12)
                        .clipped()
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.7))
                    Text("Фото")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: 200)
                .padding(.vertical, 20)
            }
        case .video:
            NavigationLink(
                destination: FullScreenImageView(
                    image: message.videoThumbnail ?? Image(systemName: "video"),
                    fileName: message.fileName
                )
            ) {
                if let thumbnail = message.videoThumbnail {
                    ZStack {
                        thumbnail
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 200, maxHeight: 200)
                            .cornerRadius(12)
                            .clipped()
                        Circle()
                            .fill(Color.black.opacity(0.5))
                            .frame(width: 40, height: 40)
                        Image(systemName: "play.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "video")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.7))
                        Text("Видео")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .frame(maxWidth: 200)
                    .padding(.vertical, 20)
                }
            }
            .buttonStyle(PlainButtonStyle())
        case .file:
            HStack(spacing: 12) {
                Image(systemName: "doc.fill")
                    .font(.system(size: 30))
                VStack(alignment: .leading) {
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
            .frame(maxWidth: 250)
        case .voice:
            HStack(spacing: 12) {
                Image(systemName: "waveform")
                    .font(.system(size: 24))
                Text(message.formattedDuration.isEmpty ? "Голосовое" : message.formattedDuration)
                    .font(.body)
                    .monospacedDigit()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: 250)
        case .videoNote:
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.3))
                    .frame(width: 150, height: 150)
                if let thumbnail = message.videoThumbnail {
                    thumbnail
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 150, height: 150)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "video.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.5))
                }
                Circle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: 50, height: 50)
                Image(systemName: "play.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
            .frame(width: 150, height: 150)
        }
    }
    
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
