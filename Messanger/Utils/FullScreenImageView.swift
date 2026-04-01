import SwiftUI

struct FullScreenImageView: View {
    let image: Image
    let fileName: String

    @Environment(\.dismiss) private var dismiss

    @State private var baseScale: CGFloat = 1
    @State private var pinchScale: CGFloat = 1

    @State private var baseOffset: CGSize = .zero
    @State private var dragOffset: CGSize = .zero

    private let minScale: CGFloat = 1
    private let maxScale: CGFloat = 4

    var currentScale: CGFloat {
        min(max(baseScale * pinchScale, minScale), maxScale)
    }

    var currentOffset: CGSize {
        CGSize(
            width: baseOffset.width + dragOffset.width,
            height: baseOffset.height + dragOffset.height
        )
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            image
                .resizable()
                .scaledToFit()
                .scaleEffect(currentScale)
                .offset(currentOffset)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(doubleTapGesture)
                .simultaneousGesture(magnificationGesture)
                .simultaneousGesture(dragGesture)

            VStack {
                HStack {
                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .padding()
                    }
                }

                Spacer()
            }
        }
        .statusBarHidden()
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                pinchScale = value
            }
            .onEnded { value in
                let newScale = min(max(baseScale * value, minScale), maxScale)
                baseScale = newScale
                pinchScale = 1

                if newScale <= 1 {
                    withAnimation(.spring()) {
                        baseOffset = .zero
                        dragOffset = .zero
                    }
                }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if currentScale > 1 {
                    dragOffset = value.translation
                } else {
                    dragOffset = CGSize(width: 0, height: value.translation.height)
                }
            }
            .onEnded { value in
                if currentScale > 1 {
                    baseOffset.width += value.translation.width
                    baseOffset.height += value.translation.height
                    dragOffset = .zero
                } else {
                    let dismissThreshold: CGFloat = 120
                    if abs(value.translation.height) > dismissThreshold {
                        dismiss()
                    } else {
                        withAnimation(.spring()) {
                            dragOffset = .zero
                            baseOffset = .zero
                        }
                    }
                }
            }
    }

    private var doubleTapGesture: some Gesture {
        TapGesture(count: 2)
            .onEnded {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    if currentScale > 1.2 {
                        baseScale = 1
                        pinchScale = 1
                        baseOffset = .zero
                        dragOffset = .zero
                    } else {
                        baseScale = 2.5
                        pinchScale = 1
                    }
                }
            }
    }
}
