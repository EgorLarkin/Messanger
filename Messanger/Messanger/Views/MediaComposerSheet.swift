import SwiftUI
import PhotosUI
import AVFoundation

struct MediaComposerSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var items: [PendingMediaItem]
    @State private var caption: String = ""
    @State private var selectedPickerItems: [PhotosPickerItem] = []

    let onSend: (String, [PendingMediaItem]) -> Void

    init(items: [PendingMediaItem], onSend: @escaping (String, [PendingMediaItem]) -> Void) {
        _items = State(initialValue: items)
        self.onSend = onSend
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if items.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 42))
                            .foregroundColor(.secondary)

                        Text("Нет выбранных медиа")
                            .font(.headline)

                        Text("Добавь фото или видео через кнопку +")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible(), spacing: 8),
                                    GridItem(.flexible(), spacing: 8)
                                ],
                                spacing: 8
                            ) {
                                ForEach(items) { item in
                                    ZStack(alignment: .topTrailing) {
                                        mediaCell(for: item)

                                        Button {
                                            removeItem(item)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 22))
                                                .foregroundColor(.white)
                                                .background(Color.black.opacity(0.35))
                                                .clipShape(Circle())
                                        }
                                        .padding(6)
                                    }
                                }
                            }
                            .padding(.horizontal)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Подпись")
                                    .font(.headline)

                                TextField("Добавить подпись...", text: $caption, axis: .vertical)
                                    .textFieldStyle(.roundedBorder)
                                    .lineLimit(3...6)
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 20)
                        }
                        .padding(.top, 16)
                    }
                }
            }
            .navigationTitle("Отправка медиа")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }

                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    PhotosPicker(
                        selection: $selectedPickerItems,
                        maxSelectionCount: 20,
                        matching: .any(of: [.images, .videos])
                    ) {
                        Image(systemName: "plus")
                            .font(.headline)
                    }

                    Button("Отправить") {
                        let currentItems = items
                        let currentCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
                        dismiss()
                        onSend(currentCaption, currentItems)
                    }
                    .disabled(items.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
        .onChange(of: selectedPickerItems) { newItems in
            loadSelectedItems(newItems)
        }
    }

    @ViewBuilder
    private func mediaCell(for item: PendingMediaItem) -> some View {
        if item.kind == .image, let image = item.image {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 140)
                .frame(maxWidth: .infinity)
                .clipped()
                .cornerRadius(12)
        } else {
            VStack(spacing: 10) {
                Image(systemName: "video.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.blue)

                Text(item.fileName)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }

    private func removeItem(_ item: PendingMediaItem) {
        items.removeAll { $0.id == item.id }
    }

    private func loadSelectedItems(_ pickerItems: [PhotosPickerItem]) {
        guard !pickerItems.isEmpty else { return }

        Task {
            var appended: [PendingMediaItem] = []

            for pickerItem in pickerItems {
                if let data = try? await pickerItem.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    appended.append(
                        PendingMediaItem(
                            image: uiImage,
                            videoURL: nil,
                            fileName: "photo.jpg",
                            kind: .image
                        )
                    )
                    continue
                }

                if let movieURL = try? await pickerItem.loadTransferable(type: URL.self) {
                    appended.append(
                        PendingMediaItem(
                            image: nil,
                            videoURL: movieURL,
                            fileName: movieURL.lastPathComponent,
                            kind: .video
                        )
                    )
                }
            }

            await MainActor.run {
                items.append(contentsOf: appended)
                selectedPickerItems = []
            }
        }
    }
}
