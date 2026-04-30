import SwiftUI
import AVKit

// MARK: - PipOverlay

/// Floating draggable PiP overlay rendered inside DigiaHost's ZStack.
/// On drag end, snaps to the nearest corner (YouTube-style).
/// Back-press / swipe equivalent: collapse button collapses expanded PiP; close button dismisses.
struct PipOverlay: View {
    let request: PipRequest
    let onDismiss: () -> Void

    var body: some View {
        GeometryReader { geo in
            PipView(
                request: request,
                screenSize: geo.size,
                safeAreaInsets: geo.safeAreaInsets,
                onDismiss: onDismiss
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - PipView

private struct PipView: View {
    let request: PipRequest
    let screenSize: CGSize
    let safeAreaInsets: EdgeInsets
    let onDismiss: () -> Void

    @State private var offset: CGSize = .zero
    @State private var dragOffset: CGSize = .zero     // live delta while finger is down
    @State private var isDragging = false
    @State private var isExpanded = false
    @State private var isVisible  = false

    private var pipSize: CGSize { CGSize(width: request.widthPt, height: request.heightPt) }

    // Drag-allowed bounds — respect safe area so PiP stays below notch / above home indicator
    private var minX: CGFloat { screenSize.width  * (request.dragBounds?.minXFraction ?? 0) }
    private var maxX: CGFloat { screenSize.width  * (request.dragBounds?.maxXFraction ?? 1) - pipSize.width }
    private var minY: CGFloat {
        let fromBounds = screenSize.height * (request.dragBounds?.minYFraction ?? 0)
        return max(fromBounds, safeAreaInsets.top)
    }
    private var maxY: CGFloat {
        let fromBounds = screenSize.height * (request.dragBounds?.maxYFraction ?? 1) - pipSize.height
        let safeBottom = screenSize.height - safeAreaInsets.bottom - pipSize.height
        return min(fromBounds, safeBottom)
    }

    private var currentOffset: CGSize {
        CGSize(width: offset.width + dragOffset.width,
               height: offset.height + dragOffset.height)
    }

    var body: some View {
        let animDuration = request.animationDurationMs / 1000.0

        ZStack(alignment: .topLeading) {
            if isVisible {
                pipContent(animDuration: animDuration)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.85).combined(with: .opacity),
                        removal:   .scale(scale: 0.85).combined(with: .opacity)
                    ))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { setupInitialPosition() }
        .task {
            if request.delayMs > 0 {
                try? await Task.sleep(nanoseconds: UInt64(request.delayMs * 1_000_000))
            }
            withAnimation(.easeOut(duration: animDuration)) { isVisible = true }
            request.onEvent?(PipEvent.shown, [
                "pip_type":    request.videoUrl != nil ? "video" : "component",
                "componentId": request.componentId,
            ])
            if request.autoDismissMs > 0 {
                try? await Task.sleep(nanoseconds: UInt64(request.autoDismissMs * 1_000_000))
                request.onEvent?(PipEvent.dismissed, ["dismiss_type": "auto_dismiss"])
                onDismiss()
            }
        }
    }

    @ViewBuilder
    private func pipContent(animDuration: Double) -> some View {
        let width  = isExpanded ? screenSize.width  : request.widthPt
        let height = isExpanded ? screenSize.height : request.heightPt
        let ox     = isExpanded ? 0.0 : currentOffset.width
        let oy     = isExpanded ? 0.0 : currentOffset.height
        let radius = isExpanded ? 0.0 : request.cornerRadius

        Group {
            if request.videoUrl != nil {
                PipVideoView(
                    request:        request,
                    isExpanded:     isExpanded,
                    onToggleExpand: { toggleExpand(animDuration: animDuration) },
                    onDismiss:      {
                        request.onEvent?(PipEvent.close,     ["dismiss_type": "close_button"])
                        request.onEvent?(PipEvent.dismissed, ["dismiss_type": "close_button"])
                        onDismiss()
                    }
                )
            } else {
                PipComponentView(request: request, onDismiss: {
                    request.onEvent?(PipEvent.close,     ["dismiss_type": "close_button"])
                    request.onEvent?(PipEvent.dismissed, ["dismiss_type": "close_button"])
                    onDismiss()
                })
            }
        }
        .frame(width: width, height: height)
        .background(request.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .offset(x: ox, y: oy)
        .animation(.easeOut(duration: animDuration), value: isExpanded)
        .gesture(
            isExpanded ? nil : DragGesture(minimumDistance: 0)
                .onChanged { value in
                    isDragging = true
                    dragOffset = CGSize(
                        width:  value.translation.width,
                        height: value.translation.height
                    )
                }
                .onEnded { _ in
                    let current = currentOffset
                    let snapped = snapCorner(from: current)
                    withAnimation(.spring(response: animDuration, dampingFraction: 0.8)) {
                        offset = snapped
                        dragOffset = .zero
                    }
                    isDragging = false
                }
        )
    }

    // MARK: - Helpers

    private func setupInitialPosition() {
        if let preset = request.position {
            let origin = preset.resolvedOrigin(pipSize: pipSize, screenSize: screenSize)
            offset = CGSize(width: clampX(origin.x), height: clampY(origin.y))
        } else {
            let rawX = screenSize.width  * request.startX
            let rawY = screenSize.height * request.startY
            offset = CGSize(width: clampX(rawX), height: clampY(rawY))
        }
        // Snap initial position to nearest corner
        offset = snapCorner(from: offset)
    }

    private func toggleExpand(animDuration: Double) {
        let next = !isExpanded
        isExpanded = next
        request.onEvent?(next ? PipEvent.expand : PipEvent.collapse, ["source": "button"])
    }

    private func snapCorner(from current: CGSize) -> CGSize {
        let midX = (minX + max(minX, maxX)) / 2
        let midY = (minY + max(minY, maxY)) / 2
        let sx = (current.width  + pipSize.width  / 2) < midX ? minX : max(minX, maxX)
        let sy = (current.height + pipSize.height / 2) < midY ? minY : max(minY, maxY)
        return CGSize(width: sx, height: sy)
    }

    private func clampX(_ x: CGFloat) -> CGFloat { x.clamped(to: minX...max(minX, maxX)) }
    private func clampY(_ y: CGFloat) -> CGFloat { y.clamped(to: minY...max(minY, maxY)) }
}

// MARK: - PipVideoView

private struct PipVideoView: View {
    let request: PipRequest
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onDismiss: () -> Void

    @State private var player: AVPlayer?
    @State private var isPlaying   = false
    @State private var isMuted     = false
    @State private var isBuffering = true

    var body: some View {
        ZStack {
            if let player {
                VideoPlayer(player: player)
                    .disabled(true) // our own controls overlay
                    .onReceive(player.publisher(for: \.timeControlStatus)) { status in
                        isBuffering = (status == .waitingToPlayAtSpecifiedRate)
                        if status == .playing {
                            request.onEvent?(PipEvent.videoStarted, ["videoUrl": request.videoUrl ?? ""])
                        }
                    }
            }

            if isBuffering {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
            }

            // Controls
            VStack {
                HStack(spacing: 0) {
                    controlButton(icon: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill") {
                        isMuted.toggle()
                        player?.isMuted = isMuted
                        request.onEvent?(isMuted ? PipEvent.mute : PipEvent.unmute, [:])
                    }
                    controlButton(icon: isPlaying ? "pause.fill" : "play.fill") {
                        isPlaying.toggle()
                        isPlaying ? player?.play() : player?.pause()
                        request.onEvent?(isPlaying ? PipEvent.play : PipEvent.pause, [:])
                    }
                    if request.expandable {
                        controlButton(icon: isExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right") {
                            onToggleExpand()
                        }
                    }
                    if request.showClose {
                        controlButton(icon: "xmark") { onDismiss() }
                    }
                }
                .padding(4)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .onAppear { setupPlayer() }
        .onDisappear { player?.pause(); player = nil }
    }

    private func setupPlayer() {
        guard let urlStr = request.videoUrl, let url = URL(string: urlStr) else { return }
        let item = AVPlayerItem(url: url)
        let p = AVPlayer(playerItem: item)
        p.isMuted = request.muted
        if request.autoPlay { p.play() }
        if request.looping {
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { _ in p.seek(to: .zero); p.play() }
        }
        isMuted   = request.muted
        isPlaying = request.autoPlay
        player    = p
    }

    @ViewBuilder
    private func controlButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .foregroundColor(.white)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 28, height: 28)
        }
    }
}

// MARK: - PipComponentView

private struct PipComponentView: View {
    let request: PipRequest
    let onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            DUIFactory.shared.createComponent(request.componentId,args: request.args ?? [:])

//            DUIComponent(
//                componentID: request.componentId,
//                args: request.args ?? [:],
//               
//                parentStore: nil
//            )

            if request.showClose {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .foregroundColor(.white)
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 24, height: 24)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                        .padding(6)
                }
            }
        }
    }
}

// MARK: - Comparable clamp helper

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
