import SwiftUI

struct FullScreenImageView: View {
    let image: Image
    let fileName: String?
    @Environment(\.dismiss) var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(scale)
                .offset(
                    x: offset.width / scale,
                    y: offset.height / scale
                )
                .gesture(
                    SimultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = lastScale * value
                            }
                            .onEnded { _ in
                                lastScale = scale
                                scale = max(1.0, min(scale, 5.0))
                                lastScale = scale
                            },
                        
                        DragGesture()
                            .onChanged { value in
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                    )
                )
                .ignoresSafeArea()
        }
        .toolbar(.hidden, for: .navigationBar)
        .overlay(
            VStack {
                HStack {
                    Spacer()
                    if let fileName = fileName {
                        Text(fileName)
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(8)
                    }
                    Spacer()
                    Button(action: {
                        withAnimation(.spring()) {
                            scale = 1.0
                            lastScale = 1.0
                            offset = .zero
                            lastOffset = .zero
                        }
                    }) {
                        Image(systemName: "arrow.down.left.and.arrow.up.right")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding()
                }
                .padding(.top)
                Spacer()
                Text("Щипок для масштаба • Свайп для перемещения")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(8)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(8)
                    .padding(.bottom, 40)
            }
        )
    }
}
