import SwiftUI
import AVKit
import AVFoundation

struct VideoPlayerView: View {
    let url: URL

    @State private var player: AVPlayer?

    var body: some View {
        Group {
            if let player = player {
                VideoPlayer(player: player)
                    .ignoresSafeArea(edges: .bottom)
                    .background(Color.black)
            } else {
                ZStack {
                    Color.black.ignoresSafeArea()
                    ProgressView("Загрузка видео...")
                        .tint(.white)
                        .foregroundColor(.white)
                }
            }
        }
        .background(Color.black)
        .onAppear {
            setupAudioSession()
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback, options: [])
            try session.setActive(true)
        } catch {
            print("❌ Failed to configure audio session: \(error.localizedDescription)")
        }
    }

    private func setupPlayer() {
        if url.isFileURL {
            let item = AVPlayerItem(url: url)
            let newPlayer = AVPlayer(playerItem: item)
            player = newPlayer
            newPlayer.isMuted = false
            newPlayer.volume = 1.0
            newPlayer.play()
            return
        }

        guard let token = AuthManager.shared.token, !token.isEmpty else {
            let item = AVPlayerItem(url: url)
            let newPlayer = AVPlayer(playerItem: item)
            player = newPlayer
            newPlayer.isMuted = false
            newPlayer.volume = 1.0
            newPlayer.play()
            return
        }

        let headers = [
            "Authorization": "Bearer \(token)"
        ]

        let options: [String: Any] = [
            "AVURLAssetHTTPHeaderFieldsKey": headers
        ]

        let asset = AVURLAsset(url: url, options: options)
        let item = AVPlayerItem(asset: asset)
        let newPlayer = AVPlayer(playerItem: item)
        player = newPlayer
        newPlayer.isMuted = false
        newPlayer.volume = 1.0
        newPlayer.play()
    }
}
