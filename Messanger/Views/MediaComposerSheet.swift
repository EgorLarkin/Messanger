import SwiftUI
import UIKit

struct MediaComposerSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State var items: [PendingMediaItem]
    let onSend: (_ caption: String, _ items: [PendingMediaItem]) -> Void

    @State private var caption: String = ""
    @State private var showImagePicker = false
    @State private var pickedImage: UIImage?

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(items) { item in
                            ZStack(alignment: .topTrailing) {
                                preview(for: item)
                                    .frame(width: 180, height: 240)
                                    .background(Color.gray.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 16))

                                Button {
                                    items.removeAll { $0.id == item.id }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                        .background(Color.black.opacity(0.45))
                                        .clipShape(Circle())
                                }
                                .padding(8)
                            }
                        }

                        Button {
                            showImagePicker = true
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "plus")
                                    .font(.system(size: 28, weight: .semibold))

                                Text("Добавить")
                                    .font(.caption)
                            }
                            .foregroundColor(.blue)
                            .frame(width: 120, height: 240)
                            .background(Color.blue.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 260)

                TextField("Добавьте подпись...", text: $caption, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 16)
            .navigationTitle("Медиа")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Отправить") {
                        let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSend(trimmed, items)
                        dismiss()
                    }
                    .disabled(items.isEmpty)
                }
            }
            .sheet(isPresented: $showImagePicker, onDismiss: handlePickedImage) {
                ImagePicker(image: $pickedImage)
            }
        }
    }

    @ViewBuilder
    private func preview(for item: PendingMediaItem) -> some View {
        if let image = item.image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else if let url = item.videoURL {
            ZStack {
                Color.black.opacity(0.75)

                VStack(spacing: 10) {
                    Image(systemName: "video.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.white)

                    Text(url.lastPathComponent)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
            }
        } else if let url = item.fileURL {
            ZStack {
                Color.gray.opacity(0.2)

                VStack(spacing: 10) {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.blue)

                    Text(url.lastPathComponent)
                        .font(.caption2)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
            }
        } else {
            Color.gray.opacity(0.2)
        }
    }

    private func handlePickedImage() {
        guard let image = pickedImage else { return }
        items.append(PendingMediaItem(image: image, videoURL: nil, fileURL: nil, type: .image))
        pickedImage = nil
    }
}
