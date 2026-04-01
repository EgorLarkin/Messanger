import SwiftUI
import AVKit

struct VideoPlayerSheet: View {
    let url: URL

    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer
    @State private var dragOffset: CGFloat = 0

    init(url: URL) {
        self.url = url
        _player = State(initialValue: AVPlayer(url: url))
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VideoPlayer(player: player)
                .ignoresSafeArea()
                .offset(y: dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.height > 0 {
                                dragOffset = value.translation.height
                            }
                        }
                        .onEnded { value in
                            if value.translation.height > 140 {
                                player.pause()
                                dismiss()
                            } else {
                                withAnimation(.spring()) {
                                    dragOffset = 0
                                }
                            }
                        }
                )

            VStack {
                HStack {
                    Spacer()

                    Button {
                        player.pause()
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
        .onAppear {
            player.play()
        }
        .onDisappear {
            player.pause()
        }
    }
}
