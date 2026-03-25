import SwiftUI
import UIKit

@MainActor
final class VWScratchCard: VirtualStatelessWidget<ScratchCardProps> {
    override func render(_ payload: RenderPayload) -> AnyView {
        guard let base = childOf("base"), let overlay = childOf("overlay") else {
            return empty()
        }

        let config = DigiaScratchCardConfig(
            width: props.width,
            height: props.height,
            brushSize: payload.eval(props.brushSize) ?? 20,
            revealFullAtPercent: max(0, min((payload.eval(props.revealFullAtPercent) ?? 75) / 100, 1)),
            isScratchingEnabled: payload.eval(props.isScratchingEnabled) ?? true,
            gridResolution: max(payload.eval(props.gridResolution) ?? 100, 1),
            enableTapToScratch: payload.eval(props.enableTapToScratch) ?? false,
            brushColor: payload.evalColor(props.brushColor) ?? .clear,
            isPaintMode: (payload.evalColor(props.brushColor).map { UIColor($0).cgColor.alpha > 0 }) ?? false,
            brushOpacity: max(0, min(payload.eval(props.brushOpacity) ?? 1, 1)),
            brushShape: DigiaScratchBrushShape(rawValue: payload.eval(props.brushShape)?.lowercased() ?? "") ?? .circle,
            enableHapticFeedback: payload.eval(props.enableHapticFeedback) ?? false,
            revealAnimationType: DigiaScratchRevealAnimationType(rawValue: payload.eval(props.revealAnimationType)?.lowercased() ?? "") ?? .none,
            animationDurationMs: max(payload.eval(props.animationDurationMs) ?? 500, 0),
            enableProgressAnimation: payload.eval(props.enableProgressAnimation) ?? false
        )

        return AnyView(
            DigiaScratchCardView(
                base: base.toWidget(payload),
                overlay: overlay.toWidget(payload),
                config: config,
                payload: payload,
                onScratchComplete: props.onScratchComplete.map { flow in
                    {
                        payload.executeAction(flow, triggerType: "onScratchComplete")
                    }
                }
            )
        )
    }
}

private struct DigiaScratchCardView: View {
    let base: AnyView
    let overlay: AnyView
    let config: DigiaScratchCardConfig
    let payload: RenderPayload
    let onScratchComplete: (() -> Void)?

    @State private var scratchedCells: [Bool]
    @State private var scratchedCount = 0
    @State private var contentSize: CGSize = .zero
    @State private var hasStartedScratching = false
    @State private var isRevealing = false
    @State private var isCompleted = false
    @State private var completionTriggered = false

    init(
        base: AnyView,
        overlay: AnyView,
        config: DigiaScratchCardConfig,
        payload: RenderPayload,
        onScratchComplete: (() -> Void)?
    ) {
        self.base = base
        self.overlay = overlay
        self.config = config
        self.payload = payload
        self.onScratchComplete = onScratchComplete
        let cellCount = max(config.gridResolution, 1) * max(config.gridResolution, 1)
        _scratchedCells = State(initialValue: Array(repeating: false, count: cellCount))
    }

    var body: some View {
        var current = AnyView(
            ZStack {
                if config.isPaintMode {
                    overlay

                    if shouldRenderOverlay {
                        ScratchCardPaintMaskShape(
                            scratchedCells: scratchedCells,
                            resolution: config.gridResolution
                        )
                        .fill(config.brushColor.opacity(config.brushOpacity))
                        .opacity(overlayOpacity)
                        .scaleEffect(overlayScale)
                        .offset(x: overlayOffset.width, y: overlayOffset.height)
                        .animation(overlayAnimation, value: revealAnimationProgress)
                    }
                } else {
                    if hasStartedScratching || isCompleted {
                        base
                    }

                    if shouldRenderOverlay {
                        overlay
                            .mask {
                                ScratchCardCutoutMaskShape(
                                    scratchedCells: scratchedCells,
                                    resolution: config.gridResolution
                                )
                                .fill(style: FillStyle(eoFill: true))
                            }
                            .opacity(overlayOpacity)
                            .scaleEffect(overlayScale)
                            .offset(x: overlayOffset.width, y: overlayOffset.height)
                            .animation(overlayAnimation, value: revealAnimationProgress)
                    }
                }
            }
            .background(SizeReader(size: $contentSize))
            .contentShape(Rectangle())
            .clipped()
            .gesture(dragGesture)
            .simultaneousGesture(tapGesture)
        )

        current = WidgetUtil.applySizing(
            payload: payload,
            style: CommonStyle(heightRaw: config.height, widthRaw: config.width),
            child: current
        )

        return current
    }

    private var totalCellCount: Int {
        scratchedCells.count
    }

    private var progress: Double {
        guard totalCellCount > 0 else { return 0 }
        return Double(scratchedCount) / Double(totalCellCount)
    }

    private var revealAnimationProgress: Double {
        if isCompleted {
            return 1
        }
        if config.enableProgressAnimation && isRevealing {
            return max(0, min(progress, 1))
        }
        return 0
    }

    private var shouldRenderOverlay: Bool {
        !(isCompleted && config.revealAnimationType == .none)
    }

    private var overlayOpacity: Double {
        switch config.revealAnimationType {
        case .fade, .zoomOut:
            return 1 - revealAnimationProgress
        default:
            return 1
        }
    }

    private var overlayScale: CGFloat {
        switch config.revealAnimationType {
        case .scale, .bounce:
            return max(0.001, 1 - revealAnimationProgress)
        case .zoomOut:
            return 1 + (0.5 * revealAnimationProgress)
        default:
            return 1
        }
    }

    private var overlayOffset: CGSize {
        switch config.revealAnimationType {
        case .slideUp:
            return CGSize(width: 0, height: -contentSize.height * revealAnimationProgress)
        case .slideDown:
            return CGSize(width: 0, height: contentSize.height * revealAnimationProgress)
        case .slideLeft:
            return CGSize(width: -contentSize.width * revealAnimationProgress, height: 0)
        case .slideRight:
            return CGSize(width: contentSize.width * revealAnimationProgress, height: 0)
        default:
            return .zero
        }
    }

    private var overlayAnimation: Animation {
        let duration = Double(config.animationDurationMs) / 1000
        switch config.revealAnimationType {
        case .bounce:
            return .interpolatingSpring(stiffness: 180, damping: 15)
        default:
            return .easeInOut(duration: duration)
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .local)
            .onChanged { value in
                scratch(at: value.location)
            }
    }

    private var tapGesture: some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                guard config.enableTapToScratch else { return }
                scratch(at: value.location)
            }
    }

    private func scratch(at location: CGPoint) {
        guard config.isScratchingEnabled, !isCompleted else { return }
        guard contentSize.width > 0, contentSize.height > 0 else { return }

        let cellWidth = contentSize.width / CGFloat(config.gridResolution)
        let cellHeight = contentSize.height / CGFloat(config.gridResolution)
        let averageCellSize = (cellWidth + cellHeight) / 2
        guard averageCellSize > 0 else { return }

        let brushRadiusCells = max((config.brushSize / 2) / averageCellSize, 0.5)
        let radius = Int(ceil(brushRadiusCells))
        let centerRow = Int((location.y / contentSize.height) * CGFloat(config.gridResolution))
        let centerCol = Int((location.x / contentSize.width) * CGFloat(config.gridResolution))

        var updatedCells = scratchedCells
        var updatedCount = scratchedCount

        for rowOffset in -radius...radius {
            for colOffset in -radius...radius {
                let normalizedRow = Double(rowOffset) / Double(brushRadiusCells)
                let normalizedCol = Double(colOffset) / Double(brushRadiusCells)

                guard shouldScratch(normalizedRow: normalizedRow, normalizedCol: normalizedCol) else {
                    continue
                }

                let row = centerRow + rowOffset
                let col = centerCol + colOffset
                guard row >= 0, row < config.gridResolution, col >= 0, col < config.gridResolution else {
                    continue
                }

                let index = (row * config.gridResolution) + col
                guard !updatedCells[index] else { continue }
                updatedCells[index] = true
                updatedCount += 1
            }
        }

        guard updatedCount != scratchedCount else { return }

        scratchedCells = updatedCells
        scratchedCount = updatedCount

        if !hasStartedScratching {
            hasStartedScratching = true
        }

        if config.enableHapticFeedback {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }

        let currentProgress = Double(updatedCount) / Double(max(totalCellCount, 1))
        if !isCompleted && currentProgress >= config.revealFullAtPercent {
            isRevealing = true
            isCompleted = true

            if config.enableHapticFeedback {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }

            if !completionTriggered {
                completionTriggered = true
                onScratchComplete?()
            }
        }
    }

    private func shouldScratch(normalizedRow: Double, normalizedCol: Double) -> Bool {
        if abs(normalizedRow) > 1 || abs(normalizedCol) > 1 {
            return false
        }

        switch config.brushShape {
        case .circle:
            return (normalizedRow * normalizedRow) + (normalizedCol * normalizedCol) <= 1
        case .square:
            return true
        case .diamond:
            return abs(normalizedRow) + abs(normalizedCol) <= 1
        case .star:
            let angle = atan2(normalizedRow, normalizedCol)
            let spikes = 5.0
            let innerRadius = 0.4
            let outerRadius = 1.0
            let radiusFactor = (abs(sin(angle * spikes)) * (outerRadius - innerRadius)) + innerRadius
            return sqrt((normalizedRow * normalizedRow) + (normalizedCol * normalizedCol)) <= radiusFactor
        case .heart:
            let x = normalizedCol
            let y = -normalizedRow
            let leftCircle = pow(x + 0.35, 2) + pow(y - 0.25, 2) <= 0.25
            let rightCircle = pow(x - 0.35, 2) + pow(y - 0.25, 2) <= 0.25
            let triangle = y <= 0.25 && y >= -0.9 && abs(x) <= (0.9 - (-y)) * 0.7
            return leftCircle || rightCircle || triangle
        }
    }
}

private struct DigiaScratchCardConfig {
    let width: String?
    let height: String?
    let brushSize: CGFloat
    let revealFullAtPercent: Double
    let isScratchingEnabled: Bool
    let gridResolution: Int
    let enableTapToScratch: Bool
    let brushColor: Color
    let isPaintMode: Bool
    let brushOpacity: Double
    let brushShape: DigiaScratchBrushShape
    let enableHapticFeedback: Bool
    let revealAnimationType: DigiaScratchRevealAnimationType
    let animationDurationMs: Int
    let enableProgressAnimation: Bool
}

private enum DigiaScratchBrushShape: String {
    case circle
    case square
    case star
    case heart
    case diamond
}

private enum DigiaScratchRevealAnimationType: String {
    case none
    case fade
    case scale
    case slideUp = "slideup"
    case slideDown = "slidedown"
    case slideLeft = "slideleft"
    case slideRight = "slideright"
    case bounce
    case zoomOut = "zoomout"
}

private struct ScratchCardPaintMaskShape: Shape {
    let scratchedCells: [Bool]
    let resolution: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()

        guard resolution > 0 else { return path }

        let cellWidth = rect.width / CGFloat(resolution)
        let cellHeight = rect.height / CGFloat(resolution)

        for row in 0..<resolution {
            for col in 0..<resolution {
                let index = (row * resolution) + col
                guard index < scratchedCells.count, scratchedCells[index] else { continue }
                path.addRect(
                    CGRect(
                        x: rect.minX + (CGFloat(col) * cellWidth),
                        y: rect.minY + (CGFloat(row) * cellHeight),
                        width: cellWidth,
                        height: cellHeight
                    )
                )
            }
        }

        return path
    }
}

private struct ScratchCardCutoutMaskShape: Shape {
    let scratchedCells: [Bool]
    let resolution: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)

        guard resolution > 0 else { return path }

        let cellWidth = rect.width / CGFloat(resolution)
        let cellHeight = rect.height / CGFloat(resolution)

        for row in 0..<resolution {
            for col in 0..<resolution {
                let index = (row * resolution) + col
                guard index < scratchedCells.count, scratchedCells[index] else { continue }
                path.addRect(
                    CGRect(
                        x: rect.minX + (CGFloat(col) * cellWidth),
                        y: rect.minY + (CGFloat(row) * cellHeight),
                        width: cellWidth,
                        height: cellHeight
                    )
                )
            }
        }

        return path
    }
}

private struct SizeReader: View {
    @Binding var size: CGSize

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .preference(key: SizePreferenceKey.self, value: proxy.size)
        }
        .onPreferenceChange(SizePreferenceKey.self) { value in
            size = value
        }
    }
}

private struct SizePreferenceKey: PreferenceKey {
    static let defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}
