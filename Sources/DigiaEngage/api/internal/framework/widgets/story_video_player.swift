import AVFoundation
import AVKit
import SwiftUI
import UIKit

@MainActor
final class VWStoryVideoPlayer: VirtualLeafStatelessWidget<StoryVideoPlayerProps> {
    override func render(_ payload: RenderPayload) -> AnyView {
        guard let videoURL = payload.eval(props.videoUrl), !videoURL.isEmpty else {
            return empty()
        }

        return AnyView(
            DigiaStoryVideoPlayerView(
                videoURL: videoURL,
                autoPlay: payload.eval(props.autoPlay) ?? true,
                looping: payload.eval(props.looping) ?? false,
                fit: payload.eval(props.fit)
            )
        )
    }
}

struct StoryVideoPlaybackBundle {
    let player: AVPlayer
    let looper: AVPlayerLooper?

    static func make(url: URL, looping: Bool) -> StoryVideoPlaybackBundle {
        let item = AVPlayerItem(url: url)
        if looping {
            let queuePlayer = AVQueuePlayer(playerItem: item)
            let looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
            return StoryVideoPlaybackBundle(player: queuePlayer, looper: looper)
        }

        return StoryVideoPlaybackBundle(player: AVPlayer(playerItem: item), looper: nil)
    }
}

@MainActor
final class StoryVideoPlayerModel: ObservableObject {
    @Published private(set) var player: AVPlayer?
    @Published private(set) var isLoading = false

    private var playbackBundle: StoryVideoPlaybackBundle?
    private var loadedDuration: Double?

    func load(urlString: String, looping: Bool) async {
        guard let url = URL(string: urlString), ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
            player = nil
            isLoading = false
            playbackBundle = nil
            return
        }

        isLoading = true
        let asset = AVURLAsset(url: url)
        do {
            let duration = try await asset.load(.duration)
            let bundle = StoryVideoPlaybackBundle.make(url: url, looping: looping)
            playbackBundle = bundle
            player = bundle.player
            loadedDuration = duration.seconds.isFinite && duration.seconds > 0 ? duration.seconds : nil
            isLoading = false

            if duration.seconds.isNaN || duration.seconds <= 0 {
                bundle.player.currentItem?.forwardPlaybackEndTime = .positiveInfinity
            }
        } catch {
            player = nil
            playbackBundle = nil
            loadedDuration = nil
            isLoading = false
        }
    }

    func currentDuration() -> Double? {
        loadedDuration
    }

    func pause() {
        player?.pause()
    }

    func play() {
        player?.play()
    }
}

private struct DigiaStoryVideoPlayerView: View {
    let videoURL: String
    let autoPlay: Bool
    let looping: Bool
    let fit: String?

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.storyPlaybackBridge) private var storyPlaybackBridge
    @StateObject private var model = StoryVideoPlayerModel()

    var body: some View {
        ZStack {
            if model.isLoading {
                ProgressView()
            } else if let player = model.player {
                DigiaStoryAVPlayerLayerView(
                    player: player,
                    videoGravity: videoGravity(for: fit)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            } else {
                EmptyView()
            }
        }
        .task(id: "\(videoURL)-\(looping)") {
            storyPlaybackBridge?.videoDidStartLoading()
            await model.load(urlString: videoURL, looping: looping)
            if let player = model.player {
                if storyPlaybackBridge == nil, autoPlay {
                    player.play()
                }
                registerIfNeeded(player: player)
            }
        }
        .onDisappear {
            model.pause()
        }
        .onChange(of: scenePhase) { phase in
            guard storyPlaybackBridge == nil else { return }
            switch phase {
            case .active:
                if autoPlay { model.play() }
            case .background, .inactive:
                model.pause()
            @unknown default:
                model.pause()
            }
        }
    }

    private func registerIfNeeded(player: AVPlayer) {
        guard let bridge = storyPlaybackBridge else { return }
        bridge.videoDidBecomeReady(player: player, duration: model.currentDuration() ?? 0.1, autoPlay: autoPlay)
    }

    private func videoGravity(for fit: String?) -> AVLayerVideoGravity {
        switch fit?.lowercased() {
        case "cover":
            return .resizeAspectFill
        case "fill":
            return .resize
        case "contain", "fitwidth", "fitheight", "scaledown", "none":
            return .resizeAspect
        default:
            return .resizeAspect
        }
    }
}

private struct DigiaStoryAVPlayerLayerView: UIViewRepresentable {
    let player: AVPlayer
    let videoGravity: AVLayerVideoGravity

    func makeUIView(context _: Context) -> DigiaStoryPlayerLayerContainer {
        let view = DigiaStoryPlayerLayerContainer()
        view.playerLayer.videoGravity = videoGravity
        return view
    }

    func updateUIView(_ uiView: DigiaStoryPlayerLayerContainer, context _: Context) {
        uiView.playerLayer.player = player
        uiView.playerLayer.videoGravity = videoGravity
    }
}

private final class DigiaStoryPlayerLayerContainer: UIView {
    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}
