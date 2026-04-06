import SwiftUI
import AVKit
import AVFoundation
import QuickLook

struct PendingMediaItem: Identifiable, Equatable {
    let id = UUID()
    let type: MediaType
    let image: UIImage?
    let videoURL: URL?
    let fileURL: URL?
    let fileName: String

    static func == (lhs: PendingMediaItem, rhs: PendingMediaItem) -> Bool {
        lhs.id == rhs.id
    }
}

struct MediaComposerSheet: View {
    let initialItems: [PendingMediaItem]
    var isSending: Bool = false
    let onSend: (_ caption: String, _ items: [PendingMediaItem]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var items: [PendingMediaItem]
    @State private var caption: String = ""
    @State private var selectedPreviewIndex: Int = 0

    init(
        initialItems: [PendingMediaItem],
        isSending: Bool = false,
        onSend: @escaping (_ caption: String, _ items: [PendingMediaItem]) -> Void
    ) {
        self.initialItems = initialItems
        self.isSending = isSending
        self.onSend = onSend
        _items = State(initialValue: initialItems)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if items.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "tray")
                            .font(.system(size: 44))
                            .foregroundColor(.secondary)

                        Text("Нет вложений")
                            .font(.headline)

                        Spacer()
                    }
                } else {
                    previewArea
                    thumbnailStrip
                    captionArea
                }
            }
            .navigationTitle("Отправка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        if !isSending {
                            dismiss()
                        }
                    }
                    .disabled(isSending)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        guard !items.isEmpty, !isSending else { return }
                        onSend(caption, items)
                    } label: {
                        if isSending {
                            ProgressView()
                        } else {
                            Text("Отправить")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(items.isEmpty || isSending)
                }
            }
        }
        .interactiveDismissDisabled(isSending)
    }

    @ViewBuilder
    private var previewArea: some View {
        let safeIndex = min(max(selectedPreviewIndex, 0), max(items.count - 1, 0))
        let currentItem = items[safeIndex]

        ZStack {
            Color.black.opacity(0.95)
                .ignoresSafeArea()

            switch currentItem.type {
            case .image:
                if let image = currentItem.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                } else {
                    unsupportedPreview
                }

            case .video:
                if let url = currentItem.videoURL {
                    VideoPlayer(player: AVPlayer(url: url))
                        .ignoresSafeArea(edges: .horizontal)
                } else {
                    unsupportedPreview
                }

            case .file:
                if let fileURL = currentItem.fileURL {
                    QuickLookPreview(url: fileURL)
                } else {
                    unsupportedPreview
                }

            default:
                unsupportedPreview
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 360)
    }

    private var unsupportedPreview: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc")
                .font(.system(size: 42))
                .foregroundColor(.white.opacity(0.75))
            Text("Предпросмотр недоступен")
                .foregroundColor(.white.opacity(0.85))
        }
    }

    private var thumbnailStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    ZStack(alignment: .topTrailing) {
                        Button {
                            selectedPreviewIndex = index
                        } label: {
                            thumbnailView(for: item, isSelected: index == selectedPreviewIndex)
                        }
                        .buttonStyle(.plain)
                        .disabled(isSending)

                        Button {
                            guard !isSending else { return }
                            removeItem(at: index)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .background(Color.black.opacity(0.35))
                                .clipShape(Circle())
                        }
                        .offset(x: 6, y: -6)
                        .disabled(isSending)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(Color(.systemBackground))
    }

    @ViewBuilder
    private func thumbnailView(for item: PendingMediaItem, isSelected: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.15))
                .frame(width: 74, height: 74)

            switch item.type {
            case .image:
                if let image = item.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 74, height: 74)
                        .clipped()
                        .cornerRadius(12)
                } else {
                    Image(systemName: "photo")
                        .foregroundColor(.secondary)
                }

            case .video:
                if let url = item.videoURL {
                    VideoThumbMiniView(url: url)
                        .frame(width: 74, height: 74)
                        .cornerRadius(12)
                        .overlay(
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                        )
                } else {
                    Image(systemName: "video")
                        .foregroundColor(.secondary)
                }

            case .file:
                VStack(spacing: 4) {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 24))
                    Text(fileExtension(from: item.fileName))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

            default:
                Image(systemName: "questionmark")
                    .foregroundColor(.secondary)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
        )
    }

    private var captionArea: some View {
        VStack(spacing: 10) {
            TextField("Подпись", text: $caption, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .disabled(isSending)

            HStack {
                Text(summaryText)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if isSending {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.9)
                        Text("Отправка...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
    }

    private var summaryText: String {
        let imagesCount = items.filter { $0.type == .image }.count
        let videosCount = items.filter { $0.type == .video }.count
        let filesCount = items.filter { $0.type == .file }.count

        var parts: [String] = []

        if imagesCount > 0 {
            parts.append(imagesCount == 1 ? "1 фото" : "\(imagesCount) фото")
        }
        if videosCount > 0 {
            parts.append(videosCount == 1 ? "1 видео" : "\(videosCount) видео")
        }
        if filesCount > 0 {
            parts.append(filesCount == 1 ? "1 файл" : "\(filesCount) файлов")
        }

        return parts.isEmpty ? "Нет вложений" : parts.joined(separator: " • ")
    }

    private func removeItem(at index: Int) {
        guard items.indices.contains(index) else { return }

        items.remove(at: index)

        if items.isEmpty {
            selectedPreviewIndex = 0
            return
        }

        if selectedPreviewIndex >= items.count {
            selectedPreviewIndex = max(0, items.count - 1)
        }
    }

    private func fileExtension(from fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.uppercased()
        return ext.isEmpty ? "FILE" : ext
    }
}

private struct VideoThumbMiniView: View {
    let url: URL
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color.black.opacity(0.2))
                    .overlay(
                        ProgressView()
                            .tint(.white)
                    )
            }
        }
        .task {
            if image == nil {
                image = await VideoFrameLoader.generateThumbnail(from: url)
            }
        }
    }
}
