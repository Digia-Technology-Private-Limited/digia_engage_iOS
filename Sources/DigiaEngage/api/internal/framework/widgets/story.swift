import AVFoundation
import Combine
import SwiftUI


@MainActor
final class VWStory: VirtualStatelessWidget<StoryProps> {
    private var header: VirtualWidget? { childOf("header") }
    private var footer: VirtualWidget? { childOf("footer") }
    private var items: [VirtualWidget]? { childrenOf("items") }

    override func render(_ payload: RenderPayload) -> AnyView {
        let resolvedItems = makePages(payload: payload)
        guard !resolvedItems.isEmpty else { return empty() }

        let controller = payload.evalAny(props.controller) as? DigiaStoryController
        let indicator = ResolvedStoryIndicator(payload: payload, props: props.indicator)
        let initialIndex = payload.eval(props.initialIndex) ?? 0
        let restartOnCompleted = payload.eval(props.restartOnCompleted) ?? false
        let durationMillis = payload.eval(props.duration) ?? 3000
        let headerView = header?.toWidget(payload)
        let footerView = footer?.toWidget(payload)

        return AnyView(
            DigiaStoryView(
                pages: resolvedItems,
                initialIndex: initialIndex,
                repeatOnCompleted: restartOnCompleted,
                defaultDuration: max(Double(durationMillis) / 1000.0, 0.1),
                indicator: indicator,
                header: headerView,
                footer: footerView,
                controller: controller,
                onCompleted: props.onCompleted.map { flow in
                    { payload.executeAction(flow, triggerType: "onCompleted") }
                },
                onSlideStart: props.onSlideStart.map { flow in
                    { payload.executeAction(flow, triggerType: "onSlideStart") }
                },
                onSlideDown: props.onSlideDown.map { flow in
                    { payload.executeAction(flow, triggerType: "onSlideDown") }
                },
                onLeftTap: props.onLeftTap.map { flow in
                    {
                        payload.executeAction(flow, triggerType: "onLeftTap")
                        return true
                    }
                },
                onRightTap: props.onRightTap.map { flow in
                    {
                        payload.executeAction(flow, triggerType: "onRightTap")
                        return true
                    }
                },
                onPreviousCompleted: props.onPreviousCompleted.map { flow in
                    { payload.executeAction(flow, triggerType: "onPreviousCompleted") }
                },
                onStoryChanged: props.onStoryChanged.map { flow in
                    { index in
                        payload.executeAction(
                            flow,
                            triggerType: "onStoryChanged",
                            scopeContext: BasicExprContext(variables: ["index": index])
                        )
                    }
                }
            )
        )
    }

    private func makePages(payload: RenderPayload) -> [AnyView] {
        guard let items else { return [] }
        guard !items.isEmpty else { return [] }

        if let repeatedItems = resolveDataSource(payload: payload) {
            guard let template = items.first else { return [] }
            return repeatedItems.enumerated().map { index, item in
                template.toWidget(payload.copyWithChainedContext(createExprContext(item, index: index)))
            }
        }

        return items.map { $0.toWidget(payload) }
    }

    private func resolveDataSource(payload: RenderPayload) -> [Any]? {
        guard let resolved = payload.evalAny(props.dataSource) else { return nil }
        return resolved as? [Any]
    }

    private func createExprContext(_ item: Any?, index: Int) -> any ScopeContext {
        let storyObject: [String: Any?] = [
            "currentItem": item,
            "index": index,
        ]

        var variables = storyObject
        if let refName {
            variables[refName] = storyObject
        }
        return BasicExprContext(variables: variables)
    }
}

@MainActor
final class DigiaStoryController: ObservableObject {
    enum StoryAction: String {
        case play
        case pause
        case next
        case previous
        case mute
        case unMute
        case playCustomWidget
    }

    @Published fileprivate var storyStatus: StoryAction = .play
    @Published fileprivate var jumpIndex: Int?

    func play() { storyStatus = .play }
    func pause() { storyStatus = .pause }
    func next() { storyStatus = .next }
    func previous() { storyStatus = .previous }
    func mute() { storyStatus = .mute }
    func unMute() { storyStatus = .unMute }
    func playCustomWidget() { storyStatus = .playCustomWidget }
    func jumpTo(_ index: Int) { jumpIndex = index }

    func getField(_ name: String) -> Any? {
        switch name {
        case "isPaused":
            return storyStatus == .pause
        case "isMuted":
            return storyStatus == .mute
        default:
            return nil
        }
    }
}

@MainActor
struct ResolvedStoryIndicator {
    let activeColor: Color
    let completedColor: Color
    let disabledColor: Color
    let height: Double
    let borderRadius: Double
    let horizontalGap: Double
    let margin: EdgeInsets
    let alignment: Alignment
    let enableBottomSafeArea: Bool
    let enableTopSafeArea: Bool

    init(payload: RenderPayload, props: StoryIndicatorProps?) {
        activeColor = payload.evalColor(props?.activeColor) ?? .blue
        completedColor = payload.evalColor(props?.backgroundCompletedColor) ?? .white
        disabledColor = payload.evalColor(props?.backgroundDisabledColor) ?? .gray
        height = props?.height ?? 3.5
        borderRadius = props?.borderRadius ?? 4.0
        horizontalGap = props?.horizontalGap ?? 4.0
        margin = props?.margin?.edgeInsets ?? EdgeInsets(top: 14, leading: 10, bottom: 0, trailing: 10)
        alignment = To.alignment(props?.alignment) ?? .top
        enableBottomSafeArea = props?.enableBottomSafeArea ?? false
        // Flutter story indicators typically sit at a fixed top offset; default to
        // not adding safe-area insets to avoid double-counting with margin.
        enableTopSafeArea = props?.enableTopSafeArea ?? false
    }
}

@MainActor
final class StoryPlaybackCoordinator: ObservableObject {
    @Published private(set) var currentIndex: Int
    @Published private(set) var progress: Double = 0
    @Published private(set) var generation = UUID()

    let pageCount: Int
    let repeatOnCompleted: Bool
    let defaultDuration: Double

    private(set) var isPaused = false
    private(set) var didCompleteAllItems = false
    private(set) var mode: Mode = .detectingVideo
    private var countdownElapsed: Double = 0
    private var currentPlayer: AVPlayer?
    private var playerObserver: Any?
    private var endObserver: NSObjectProtocol?

    private let onCompleted: (@Sendable () -> Void)?
    private let onPreviousCompleted: (@Sendable () -> Void)?
    private let onStoryChanged: (@Sendable (Int) -> Void)?

    enum Mode: Equatable {
        case detectingVideo
        case countdown
        case video
    }

    init(
        pageCount: Int,
        initialIndex: Int,
        repeatOnCompleted: Bool,
        defaultDuration: Double,
        onCompleted: (@Sendable () -> Void)?,
        onPreviousCompleted: (@Sendable () -> Void)?,
        onStoryChanged: (@Sendable (Int) -> Void)?
    ) {
        self.pageCount = max(pageCount, 0)
        self.repeatOnCompleted = repeatOnCompleted
        self.defaultDuration = max(defaultDuration, 0.1)
        self.onCompleted = onCompleted
        self.onPreviousCompleted = onPreviousCompleted
        self.onStoryChanged = onStoryChanged
        if pageCount > 0 {
            self.currentIndex = min(max(initialIndex, 0), pageCount - 1)
        } else {
            self.currentIndex = 0
        }
        prepareCurrentPage(resetIndex: false)
    }

    func confirmNoVideoDetected(for generation: UUID) {
        guard generation == self.generation, mode == .detectingVideo else { return }
        // Called from a SwiftUI `.task` in the view tree; defer to avoid mutating
        // observable state during a view update pass.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.startCountdown()
        }
    }

    func registerVideoLoading(for generation: UUID) {
        guard generation == self.generation else { return }
        mode = .detectingVideo
        progress = 0
        countdownElapsed = 0
        didCompleteAllItems = false
    }

    func registerVideo(player: AVPlayer, duration: Double, autoPlay: Bool, generation: UUID) {
        guard generation == self.generation else { return }

        cleanupPlayer()
        currentPlayer = player
        mode = .video
        progress = 0

        let safeDuration = max(duration, 0.1)
        playerObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.05, preferredTimescale: 600), queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.mode == .video else { return }
                self.progress = min(max(time.seconds / safeDuration, 0), 1)
            }
        }

        if let item = player.currentItem {
            endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.advanceToNext()
                }
            }
        }

        if autoPlay && !isPaused {
            player.play()
        } else {
            player.pause()
        }
    }

    func tick(delta: Double) {
        guard mode == .countdown, !isPaused, !didCompleteAllItems else { return }
        countdownElapsed += delta
        progress = min(max(countdownElapsed / defaultDuration, 0), 1)
        if progress >= 1 {
            advanceToNext()
        }
    }

    func advanceToNext() {
        guard pageCount > 0 else { return }
        if currentIndex >= pageCount - 1 {
            if !didCompleteAllItems {
                didCompleteAllItems = true
                progress = 1
                onCompleted?()
            }
            if repeatOnCompleted {
                currentIndex = 0
                prepareCurrentPage(resetIndex: true)
                onStoryChanged?(currentIndex)
            }
            return
        }

        currentIndex += 1
        prepareCurrentPage(resetIndex: true)
        onStoryChanged?(currentIndex)
    }

    func moveToPrevious() {
        guard pageCount > 0 else { return }
        didCompleteAllItems = false
        if currentIndex <= 0 {
            prepareCurrentPage(resetIndex: true)
            startCountdown()
            onPreviousCompleted?()
            onStoryChanged?(currentIndex)
            return
        }

        currentIndex -= 1
        prepareCurrentPage(resetIndex: true)
        onStoryChanged?(currentIndex)
    }

    func jump(to index: Int) {
        guard pageCount > 0 else { return }
        didCompleteAllItems = false
        currentIndex = min(max(index, 0), pageCount - 1)
        prepareCurrentPage(resetIndex: true)
        onStoryChanged?(currentIndex)
    }

    func pause() {
        isPaused = true
        currentPlayer?.pause()
    }

    func resume() {
        isPaused = false
        if mode == .video {
            currentPlayer?.play()
        }
    }

    private func startCountdown() {
        cleanupPlayer()
        mode = .countdown
        countdownElapsed = 0
        progress = 0
        didCompleteAllItems = false
    }

    private func prepareCurrentPage(resetIndex: Bool) {
        cleanupPlayer()
        if resetIndex {
            progress = 0
        }
        countdownElapsed = 0
        mode = .detectingVideo
        generation = UUID()
        didCompleteAllItems = false
    }

    private func cleanupPlayer() {
        if let observer = playerObserver, let currentPlayer {
            currentPlayer.removeTimeObserver(observer)
        }
        playerObserver = nil

        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil

        currentPlayer?.pause()
        currentPlayer = nil
    }
}

private struct DigiaStoryView: View {
    let pages: [AnyView]
    let initialIndex: Int
    let repeatOnCompleted: Bool
    let defaultDuration: Double
    let indicator: ResolvedStoryIndicator
    let header: AnyView?
    let footer: AnyView?
    let controller: DigiaStoryController?
    let onCompleted: (@Sendable () -> Void)?
    let onSlideStart: (@Sendable () -> Void)?
    let onSlideDown: (@Sendable () -> Void)?
    let onLeftTap: (@Sendable () async -> Bool)?
    let onRightTap: (@Sendable () async -> Bool)?
    let onPreviousCompleted: (@Sendable () -> Void)?
    let onStoryChanged: (@Sendable (Int) -> Void)?

    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var coordinator: StoryPlaybackCoordinator
    @State private var didStartSlide = false

    init(
        pages: [AnyView],
        initialIndex: Int,
        repeatOnCompleted: Bool,
        defaultDuration: Double,
        indicator: ResolvedStoryIndicator,
        header: AnyView?,
        footer: AnyView?,
        controller: DigiaStoryController?,
        onCompleted: (@Sendable () -> Void)?,
        onSlideStart: (@Sendable () -> Void)?,
        onSlideDown: (@Sendable () -> Void)?,
        onLeftTap: (@Sendable () async -> Bool)?,
        onRightTap: (@Sendable () async -> Bool)?,
        onPreviousCompleted: (@Sendable () -> Void)?,
        onStoryChanged: (@Sendable (Int) -> Void)?
    ) {
        self.pages = pages
        self.initialIndex = initialIndex
        self.repeatOnCompleted = repeatOnCompleted
        self.defaultDuration = defaultDuration
        self.indicator = indicator
        self.header = header
        self.footer = footer
        self.controller = controller
        self.onCompleted = onCompleted
        self.onSlideStart = onSlideStart
        self.onSlideDown = onSlideDown
        self.onLeftTap = onLeftTap
        self.onRightTap = onRightTap
        self.onPreviousCompleted = onPreviousCompleted
        self.onStoryChanged = onStoryChanged
        _coordinator = StateObject(wrappedValue: StoryPlaybackCoordinator(
            pageCount: pages.count,
            initialIndex: initialIndex,
            repeatOnCompleted: repeatOnCompleted,
            defaultDuration: defaultDuration,
            onCompleted: onCompleted,
            onPreviousCompleted: onPreviousCompleted,
            onStoryChanged: onStoryChanged
        ))
    }

    var body: some View {
        GeometryReader { proxy in
            let bridge = StoryPlaybackBridge(coordinator: coordinator, generation: coordinator.generation)
            ZStack {
                Color.black
                    .ignoresSafeArea()

                currentPage(bridge: bridge)
                    // Match Flutter's Positioned.fill: give pages a tight size so
                    // shrink-wrapped content (e.g. images) still fills the story viewport.
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()

                // Drag-down gesture layer (kept behind tap zones). We intentionally
                // leave the left edge uncovered so UIKit interactive back-swipe
                // can still begin there.
                HStack(spacing: 0) {
                    Color.clear
                        .frame(width: 24)
                        .allowsHitTesting(false)

                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 10)
                                .onChanged { value in
                                    if !didStartSlide {
                                        didStartSlide = true
                                        onSlideStart?()
                                    }
                                    if value.translation.height > 24 {
                                        onSlideDown?()
                                    }
                                }
                                .onEnded { _ in
                                    didStartSlide = false
                                }
                        )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Tap zones (behind header/footer so inputs remain tappable).
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .frame(width: 72)
                        .onTapGesture {
                                Task {
                                let shouldProceed = await (onLeftTap?() ?? true)
                                guard shouldProceed else { return }
                                coordinator.moveToPrevious()
                            }
                        }
                        .accessibilityIdentifier("story.tap.previous")

                    Spacer(minLength: 0)

                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .frame(width: 72)
                        .onTapGesture {
                            Task {
                                let shouldProceed = await (onRightTap?() ?? true)
                                guard shouldProceed else { return }
                                coordinator.advanceToNext()
                            }
                        }
                        .accessibilityIdentifier("story.tap.next")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Indicator overlay (match Flutter defaults: top=14, horizontal=10, no safe-area inset).
                topOverlay(safeAreaInsets: proxy.safeAreaInsets)

                // Header overlay (Flutter uses SafeArea; keep it above indicator stack).
                if let header {
                    VStack(spacing: 0) {
                        header
                        Spacer(minLength: 0)
                    }
                    .padding(.top, indicator.enableTopSafeArea ? proxy.safeAreaInsets.top : 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }

                // Footer overlay (kept compact, above tap zones).
                if let footer {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        footer
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.bottom, indicator.enableBottomSafeArea ? proxy.safeAreaInsets.bottom : 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
            }
            .contentShape(Rectangle())
        }
        // Avoid forcing a full subtree rebuild on repeat; it resets image sizing state.
        .onReceive(Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()) { _ in
            // Avoid "Modifying state during view update" warnings by ensuring the
            // state mutation doesn't happen in the current update cycle.
            DispatchQueue.main.async {
                coordinator.tick(delta: 0.05)
            }
        }
        .onReceive(storyStatusPublisher) { status in
            switch status {
            case .play:
                coordinator.resume()
            case .pause:
                coordinator.pause()
            case .next:
                coordinator.advanceToNext()
            case .previous:
                coordinator.moveToPrevious()
            case .mute, .unMute, .playCustomWidget:
                break
            }
        }
        .onReceive(jumpIndexPublisher) { index in
            coordinator.jump(to: index)
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active:
                coordinator.resume()
            case .background:
                coordinator.pause()
            case .inactive:
                // .inactive fires for Control Center, notification banners, etc.
                // Don't pause for these transient events — only pause on true background.
                break
            @unknown default:
                break
            }
        }
    }

    private var storyStatusPublisher: AnyPublisher<DigiaStoryController.StoryAction, Never> {
        controller?.$storyStatus
            .removeDuplicates()
            .eraseToAnyPublisher()
            ?? Just(DigiaStoryController.StoryAction.play).eraseToAnyPublisher()
    }

    private var jumpIndexPublisher: AnyPublisher<Int, Never> {
        controller?.$jumpIndex
            .compactMap { $0 }
            .eraseToAnyPublisher()
            ?? Empty().eraseToAnyPublisher()
    }

    @ViewBuilder
    private func currentPage(bridge: StoryPlaybackBridge) -> some View {
        if pages.indices.contains(coordinator.currentIndex) {
            pages[coordinator.currentIndex]
                .environment(\.storyPlaybackBridge, bridge)
                .task(id: coordinator.generation) {
                    await Task.yield()
                    await MainActor.run {
                        coordinator.confirmNoVideoDetected(for: bridge.generation)
                    }
                }
        } else {
            EmptyView()
        }
    }

    private func topOverlay(safeAreaInsets: EdgeInsets) -> some View {
        DigiaStoryIndicatorView(
            totalItems: pages.count,
            currentIndex: coordinator.currentIndex,
            progress: coordinator.progress,
            indicator: indicator
        )
        .padding(indicator.margin)
        .padding(.top, indicator.enableTopSafeArea ? safeAreaInsets.top : 0)
        .padding(.bottom, indicator.enableBottomSafeArea ? safeAreaInsets.bottom : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: indicator.alignment)
    }
}

private struct DigiaStoryIndicatorView: View {
    let totalItems: Int
    let currentIndex: Int
    let progress: Double
    let indicator: ResolvedStoryIndicator

    var body: some View {
        let r = CGFloat(indicator.borderRadius)
        HStack(spacing: indicator.horizontalGap) {
            ForEach(Array(0..<max(totalItems, 0)), id: \.self) { index in
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: r, style: .continuous)
                            .fill(backgroundColor(for: index))
                        RoundedRectangle(cornerRadius: r, style: .continuous)
                            .fill(foregroundColor(for: index))
                            .frame(width: proxy.size.width * CGFloat(fillAmount(for: index)))
                    }
                }
                .frame(height: indicator.height)
            }
        }
    }

    private func fillAmount(for index: Int) -> Double {
        if index < currentIndex { return 1 }
        if index == currentIndex { return min(max(progress, 0), 1) }
        return 0
    }

    private func foregroundColor(for index: Int) -> Color {
        index <= currentIndex ? indicator.activeColor : .clear
    }

    private func backgroundColor(for index: Int) -> Color {
        if index < currentIndex {
            return indicator.completedColor
        }
        if index == currentIndex {
            return indicator.completedColor.opacity(0.35)
        }
        return indicator.disabledColor
    }
}

@MainActor
final class StoryPlaybackBridge {
    private weak var coordinator: StoryPlaybackCoordinator?
    let generation: UUID

    init(coordinator: StoryPlaybackCoordinator, generation: UUID) {
        self.coordinator = coordinator
        self.generation = generation
    }

    func videoDidStartLoading() {
        coordinator?.registerVideoLoading(for: generation)
    }

    func videoDidBecomeReady(player: AVPlayer, duration: Double, autoPlay: Bool) {
        coordinator?.registerVideo(player: player, duration: duration, autoPlay: autoPlay, generation: generation)
    }
}

private struct StoryPlaybackBridgeKey: EnvironmentKey {
    static let defaultValue: StoryPlaybackBridge?
        = nil
}

extension EnvironmentValues {
    var storyPlaybackBridge: StoryPlaybackBridge? {
        get { self[StoryPlaybackBridgeKey.self] }
        set { self[StoryPlaybackBridgeKey.self] = newValue }
    }
}
