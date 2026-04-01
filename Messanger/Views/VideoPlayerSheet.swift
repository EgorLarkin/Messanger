import SwiftUI
import AVKit

struct VideoPlayerSheet: View {
    let url: URL

    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer

    init(url: URL) {
        self.url = url
        _player = State(initialValue: AVPlayer(url: url))
    }

    var body: some View {
        NavigationView {
            VideoPlayer(player: player)
                .background(Color.black)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Видео")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Закрыть") {
                            player.pause()
                            dismiss()
                        }
                    }
                }
                .onAppear {
                    player.play()
                }
                .onDisappear {
                    player.pause()
                }
        }
    }
}
