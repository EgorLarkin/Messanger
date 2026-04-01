import SwiftUI

struct MessageBubble: View {
    let message: Message
    let sender: User?

    @State private var localMediaURL: URL?
    @State private var exportedFileURL: URL?
    @State private var showShareSheet = false
    @State private var showFullScreenImage = false
    @State private var showVideoPlayer = false
    @State private var isLoadingFile = false

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
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 8)
        .task {
            preloadMediaIfNeeded()
        }
        .fullScreenCover(isPresented: $showFullScreenImage) {
            if let image = resolvedImage {
                FullScreenImageView(image: image, fileName: message.fileName ?? "Фото")
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = exportedFileURL {
                ShareSheet(items: [url])
            }
        }
        .sheet(isPresented: $showVideoPlayer) {
            if let url = resolvedMediaURL {
                VideoPlayerSheet(url: url)
            }
        }
    }

    private var content: some View {
        bubbleContent
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
            imageView

        case .video:
            videoView

        case .file, .voice, .videoNote:
            fileView(icon: iconName(for: message.type), title: message.fileName ?? message.displayText)
        }
    }

    private var imageView: some View {
        Group {
            if let image = resolvedImage {
                Button {
                    showFullScreenImage = true
                } label: {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: 220, maxHeight: 280)
                        .clipped()
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .padding(6)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.08))
                        .frame(width: 180, height: 180)

                    if isLoadingFile {
                        ProgressView()
                    } else {
                        Image(systemName: "photo")
                            .font(.system(size: 34))
                    }
                }
                .padding(6)
            }
        }
    }

    private var videoView: some View {
        Group {
            if let url = resolvedMediaURL {
                Button {
                    showVideoPlayer = true
                } label: {
                    ZStack(alignment: .bottomLeading) {
                        VideoThumbnailView(url: url)
                            .frame(width: 220, height: 280)
                            .clipped()
                            .cornerRadius(12)

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
                .padding(6)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.08))
                        .frame(width: 220, height: 180)

                    if isLoadingFile {
                        ProgressView()
                    } else {
                        Image(systemName: "video.fill")
                            .font(.system(size: 34))
                    }
                }
                .padding(6)
            }
        }
    }

    private func fileView(icon: String, title: String) -> some View {
        Button {
            openGenericFile()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 28))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .lineLimit(1)

                    if isLoadingFile {
                        Text("Загрузка...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if !message.formattedFileSize.isEmpty {
                        Text(message.formattedFileSize)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
            .frame(maxWidth: 250)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    private var resolvedImage: Image? {
        if let localMediaURL,
           let uiImage = UIImage(contentsOfFile: localMediaURL.path) {
            return Image(uiImage: uiImage)
        }

        return message.image
    }

    private var resolvedMediaURL: URL? {
        if let localMediaURL {
            return localMediaURL
        }

        if let messageURL = message.localFileURL {
            return messageURL
        }

        return nil
    }

    private func preloadMediaIfNeeded() {
        guard localMediaURL == nil else { return }

        switch message.type {
        case .image, .video:
            downloadAttachment(assignToPreview: true)
        default:
            break
        }
    }

    private func openGenericFile() {
        if let localMediaURL {
            exportedFileURL = localMediaURL
            showShareSheet = true
            return
        }

        downloadAttachment(assignToPreview: false)
    }

    private func downloadAttachment(assignToPreview: Bool) {
        guard let remoteURL = message.downloadUrl else { return }

        isLoadingFile = true

        NetworkService.shared.downloadFile(
            from: remoteURL,
            fileName: message.fileName ?? "attachment"
        ) { result in
            isLoadingFile = false

            switch result {
            case .success(let localURL):
                if assignToPreview {
                    localMediaURL = localURL
                } else {
                    exportedFileURL = localURL
                    showShareSheet = true
                }

            case .failure(let error):
                print("❌ Download failed: \(error)")
            }
        }
    }

    private func iconName(for type: MediaType) -> String {
        switch type {
        case .file: return "doc.fill"
        case .voice: return "waveform"
        case .videoNote: return "play.circle.fill"
        default: return "doc.fill"
        }
    }
}
