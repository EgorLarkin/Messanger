import SwiftUI
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers

struct MediaComposerSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var items: [PendingMediaItem]
    @State private var caption: String = ""

    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var showCamera = false
    @State private var cameraItems: [PendingMediaItem] = []
    @State private var showFileImporter = false
    @State private var isLoadingPickerItems = false

    let onSend: (String, [PendingMediaItem]) -> Void

    init(initialItems: [PendingMediaItem], onSend: @escaping (String, [PendingMediaItem]) -> Void) {
        _items = State(initialValue: initialItems)
        self.onSend = onSend
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if items.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()

                        Image(systemName: "paperclip")
                            .font(.system(size: 44))
                            .foregroundColor(.secondary)

                        Text("Нет вложений")
                            .font(.headline)

                        Text("Добавь фото, видео или файл")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            mediaGridSection
                            filesSection

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Подпись")
                                    .font(.headline)

                                TextField("Добавить подпись", text: $caption, axis: .vertical)
                                    .textFieldStyle(.roundedBorder)
                                    .lineLimit(3...6)
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)
                        }
                        .padding(.vertical)
                    }
                }

                Divider()

                bottomBar
            }
            .navigationTitle("Отправка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showCamera, onDismiss: handleCameraItems) {
            CameraPicker(items: $cameraItems)
        }
        .photosPicker(
            isPresented: .constant(false),
            selection: $photoPickerItems,
            maxSelectionCount: 20,
            matching: .any(of: [.images, .videos])
        )
        .onChange(of: photoPickerItems) { newValue in
            guard !newValue.isEmpty else { return }
            loadPhotosPickerItems(newValue)
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
    }

    private var mediaGridSection: some View {
        let visualItems = items.filter { $0.type == .image || $0.type == .video }

        return Group {
            if !visualItems.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Медиа")
                        .font(.headline)
                        .padding(.horizontal)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 10) {
                        ForEach(visualItems) { item in
                            ZStack(alignment: .topTrailing) {
                                MediaComposerTile(item: item)

                                Button {
                                    removeItem(item)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(.white)
                                        .background(Color.black.opacity(0.45))
                                        .clipShape(Circle())
                                }
                                .padding(6)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    private var filesSection: some View {
        let fileItems = items.filter { $0.type == .file }

        return Group {
            if !fileItems.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Файлы")
                        .font(.headline)
                        .padding(.horizontal)

                    VStack(spacing: 8) {
                        ForEach(fileItems) { item in
                            HStack(spacing: 12) {
                                Image(systemName: "doc.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.blue)

                                Text(item.fileName)
                                    .font(.subheadline)
                                    .lineLimit(2)

                                Spacer()

                                Button {
                                    removeItem(item)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                            }
                            .padding(12)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    Button {
                        showCamera = true
                    } label: {
                        composerAddButton(title: "Камера", systemImage: "camera.fill")
                    }

                    PhotosPicker(
                        selection: $photoPickerItems,
                        maxSelectionCount: 20,
                        matching: .any(of: [.images, .videos])
                    ) {
                        composerAddButton(title: "Галерея", systemImage: "photo.on.rectangle")
                    }

                    Button {
                        showFileImporter = true
                    } label: {
                        composerAddButton(title: "Файл", systemImage: "doc")
                    }
                }
                .padding(.horizontal)
            }

            Button {
                guard !items.isEmpty else { return }
                onSend(caption, items)
                dismiss()
            } label: {
                Text("Отправить")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(items.isEmpty ? Color.gray : Color.blue)
                    .cornerRadius(14)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
            .disabled(items.isEmpty || isLoadingPickerItems)
        }
        .padding(.top, 10)
        .background(Color(.systemBackground))
    }

    private func composerAddButton(title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
            Text(title)
                .font(.subheadline)
        }
        .foregroundColor(.blue)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.blue.opacity(0.12))
        .cornerRadius(12)
    }

    private func removeItem(_ item: PendingMediaItem) {
        items.removeAll { $0.id == item.id }
    }

    private func handleCameraItems() {
        guard !cameraItems.isEmpty else { return }
        items.append(contentsOf: cameraItems)
        cameraItems = []
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            let mapped = urls.compactMap { importedURL -> PendingMediaItem? in
                let secured = importedURL.startAccessingSecurityScopedResource()
                defer {
                    if secured {
                        importedURL.stopAccessingSecurityScopedResource()
                    }
                }

                let fileName = importedURL.lastPathComponent
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString + "-" + fileName)

                do {
                    if FileManager.default.fileExists(atPath: tempURL.path) {
                        try FileManager.default.removeItem(at: tempURL)
                    }
                    try FileManager.default.copyItem(at: importedURL, to: tempURL)

                    return PendingMediaItem(
                        image: nil,
                        videoURL: nil,
                        videoThumbnail: nil,
                        fileURL: tempURL,
                        fileName: fileName,
                        type: .file
                    )
                } catch {
                    print("❌ Failed to copy imported file: \(error.localizedDescription)")
                    return nil
                }
            }

            items.append(contentsOf: mapped)

        case .failure(let error):
            print("❌ File import error: \(error.localizedDescription)")
        }
    }

    private func loadPhotosPickerItems(_ pickerItems: [PhotosPickerItem]) {
        isLoadingPickerItems = true

        Task {
            var loaded: [PendingMediaItem] = []

            for pickerItem in pickerItems {
                if let data = try? await pickerItem.loadTransferable(type: Data.self) {
                    if let image = UIImage(data: data) {
                        let name = suggestedFileName(from: pickerItem, fallback: "image.jpg")
                        loaded.append(
                            PendingMediaItem(
                                image: image,
                                videoURL: nil,
                                videoThumbnail: nil,
                                fileURL: nil,
                                fileName: name,
                                type: .image
                            )
                        )
                        continue
                    }

                    let fallbackName = suggestedFileName(from: pickerItem, fallback: "file.bin")
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString + "-" + fallbackName)

                    do {
                        try data.write(to: tempURL)
                        let thumb = generateThumbnail(for: tempURL)
                        loaded.append(
                            PendingMediaItem(
                                image: nil,
                                videoURL: tempURL,
                                videoThumbnail: thumb,
                                fileURL: nil,
                                fileName: fallbackName,
                                type: .video
                            )
                        )
                    } catch {
                        print("❌ Failed to write picked data: \(error.localizedDescription)")
                    }
                } else if let movie = try? await pickerItem.loadTransferable(type: MovieTransferable.self) {
                    let thumb = generateThumbnail(for: movie.url)
                    loaded.append(
                        PendingMediaItem(
                            image: nil,
                            videoURL: movie.url,
                            videoThumbnail: thumb,
                            fileURL: nil,
                            fileName: movie.url.lastPathComponent,
                            type: .video
                        )
                    )
                }
            }

            await MainActor.run {
                items.append(contentsOf: loaded)
                photoPickerItems = []
                isLoadingPickerItems = false
            }
        }
    }

    private func suggestedFileName(from item: PhotosPickerItem, fallback: String) -> String {
        item.itemIdentifier ?? fallback
    }

    private func generateThumbnail(for url: URL) -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 400, height: 400)

        do {
            let cgImage = try generator.copyCGImage(
                at: CMTime(seconds: 0.1, preferredTimescale: 600),
                actualTime: nil
            )
            return UIImage(cgImage: cgImage)
        } catch {
            return nil
        }
    }
}

struct MediaComposerTile: View {
    let item: PendingMediaItem

    var body: some View {
        ZStack {
            if item.type == .image, let image = item.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if item.type == .video {
                if let thumb = item.videoThumbnail {
                    Image(uiImage: thumb)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.black.opacity(0.1)
                }

                Image(systemName: "play.circle.fill")
                    .font(.system(size: 34))
                    .foregroundColor(.white)
                    .shadow(radius: 4)
            }
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
        .clipped()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(14)
    }
}

struct MovieTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let copyURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + "-" + received.file.lastPathComponent)

            if FileManager.default.fileExists(atPath: copyURL.path) {
                try? FileManager.default.removeItem(at: copyURL)
            }

            try FileManager.default.copyItem(at: received.file, to: copyURL)
            return MovieTransferable(url: copyURL)
        }
    }
}
