import AVFoundation
import AVKit
import SwiftUI
import UIKit

@MainActor
final class VWVideoPlayer: VirtualLeafStatelessWidget<VideoPlayerProps> {
    override func render(_ payload: RenderPayload) -> AnyView {
        guard let rawValue = payload.evalAny(props.videoURL) as? String, !rawValue.isEmpty else {
            return empty()
        }

        return AnyView(
            DigiaVideoPlayerView(
                videoURL: rawValue,
                showControls: payload.eval(props.showControls) ?? true,
                preferredAspectRatio: payload.eval(props.aspectRatio),
                autoPlay: payload.eval(props.autoPlay) ?? true,
                looping: payload.eval(props.looping) ?? false
            )
        )
    }
}

struct DigiaVideoPlaybackBundle {
    let player: AVPlayer
    let looper: AVPlayerLooper?

    static func make(url: URL, looping: Bool) -> DigiaVideoPlaybackBundle {
        let item = AVPlayerItem(url: url)
        if looping {
            let queuePlayer = AVQueuePlayer(playerItem: item)
            let looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
            return DigiaVideoPlaybackBundle(player: queuePlayer, looper: looper)
        }
        return DigiaVideoPlaybackBundle(player: AVPlayer(playerItem: item), looper: nil)
    }
}

@MainActor
final class DigiaVideoPlayerModel: ObservableObject {
    @Published private(set) var player: AVPlayer?
    @Published private(set) var aspectRatio: Double = 16 / 9
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private var playbackBundle: DigiaVideoPlaybackBundle?

    func load(urlString: String, preferredAspectRatio: Double?, looping: Bool) async {
        guard let url = resolvedURL(from: urlString) else {
            player = nil
            playbackBundle = nil
            errorMessage = "Unsupported video URL"
            aspectRatio = preferredAspectRatio ?? 16 / 9
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        let asset = AVURLAsset(url: url)

        do {
            let tracks = try await asset.loadTracks(withMediaType: .video)
            let naturalSize = try await tracks.first?.load(.naturalSize)
            let preferredTransform = try await tracks.first?.load(.preferredTransform)

            let resolvedAspectRatio: Double
            if let preferredAspectRatio {
                resolvedAspectRatio = preferredAspectRatio
            } else if let naturalSize {
                let transformed = naturalSize.applying(preferredTransform ?? .identity)
                let width = abs(transformed.width)
                let height = abs(transformed.height)
                resolvedAspectRatio = (width > 0 && height > 0) ? Double(width / height) : (16 / 9)
            } else {
                resolvedAspectRatio = 16 / 9
            }

            let bundle = DigiaVideoPlaybackBundle.make(url: url, looping: looping)
            playbackBundle = bundle
            player = bundle.player
            aspectRatio = resolvedAspectRatio
            isLoading = false
        } catch {
            player = nil
            playbackBundle = nil
            aspectRatio = preferredAspectRatio ?? 16 / 9
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func play() {
        player?.play()
    }

    func pause() {
        player?.pause()
    }

    private func resolvedURL(from rawValue: String) -> URL? {
        guard let url = URL(string: rawValue) else { return nil }
        guard let scheme = url.scheme?.lowercased() else { return nil }
        switch scheme {
        case "http", "https", "file":
            return url
        default:
            return nil
        }
    }
}

private struct DigiaVideoPlayerView: View {
    let videoURL: String
    let showControls: Bool
    let preferredAspectRatio: Double?
    let autoPlay: Bool
    let looping: Bool

    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = DigiaVideoPlayerModel()

    var body: some View {
        ZStack {
            if model.isLoading {
                ProgressView()
            } else if let errorMessage = model.errorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                    Text("Video initialization failed")
                    Text(errorMessage)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
            } else if let player = model.player {
                playerView(player: player)
            } else {
                EmptyView()
            }
        }
        .aspectRatio(preferredAspectRatio ?? model.aspectRatio, contentMode: .fit)
        .task(id: "\(videoURL)-\(looping)-\(preferredAspectRatio ?? -1)") {
            await model.load(urlString: videoURL, preferredAspectRatio: preferredAspectRatio, looping: looping)
            if autoPlay {
                model.play()
            }
        }
        .onDisappear {
            model.pause()
        }
        .onChange(of: scenePhase, initial: false) { _, phase in
            switch phase {
            case .active:
                if autoPlay {
                    model.play()
                }
            case .background, .inactive:
                model.pause()
            @unknown default:
                model.pause()
            }
        }
    }

    @ViewBuilder
    private func playerView(player: AVPlayer) -> some View {
        if showControls {
            DigiaAVPlayerControllerView(player: player, showControls: true, autoPlay: autoPlay)
        } else {
            DigiaAVPlayerLayerView(player: player, autoPlay: autoPlay)
        }
    }
}

private struct DigiaAVPlayerControllerView: UIViewControllerRepresentable {
    let player: AVPlayer
    let showControls: Bool
    let autoPlay: Bool

    func makeUIViewController(context _: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.showsPlaybackControls = showControls
        controller.entersFullScreenWhenPlaybackBegins = false
        controller.exitsFullScreenWhenPlaybackEnds = false
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context _: Context) {
        controller.player = player
        controller.showsPlaybackControls = showControls
        if autoPlay {
            player.play()
        } else {
            player.pause()
        }
    }
}

private struct DigiaAVPlayerLayerView: UIViewRepresentable {
    let player: AVPlayer
    let autoPlay: Bool

    func makeUIView(context _: Context) -> DigiaPlayerLayerContainer {
        let view = DigiaPlayerLayerContainer()
        view.playerLayer.videoGravity = .resizeAspect
        return view
    }

    func updateUIView(_ uiView: DigiaPlayerLayerContainer, context _: Context) {
        uiView.playerLayer.player = player
        if autoPlay {
            player.play()
        } else {
            player.pause()
        }
    }
}

private final class DigiaPlayerLayerContainer: UIView {
    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}
