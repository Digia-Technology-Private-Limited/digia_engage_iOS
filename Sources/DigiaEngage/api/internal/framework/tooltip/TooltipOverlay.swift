import SwiftUI

// MARK: - TooltipOverlay

/// Full-screen overlay rendered in DigiaHost's ZStack.
/// Tap outside the bubble dismisses the tooltip.
struct TooltipOverlay: View {
    let request: TooltipRequest
    let onDismiss: () -> Void

    var body: some View {
        GeometryReader { geo in
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { onDismiss() }

            TooltipBubble(
                request: request,
                screenSize: geo.size,
                onDismiss: onDismiss
            )
        }
    }
}

// MARK: - TooltipBubble

private struct TooltipBubble: View {
    let request: TooltipRequest
    let screenSize: CGSize
    let onDismiss: () -> Void

    // Subscribe to registry so the bubble repositions whenever the label's
    // frame changes (e.g. parent ScrollView scrolled while tooltip is visible).
    @ObservedObject private var labelRegistry = DigiaLabelRegistry.shared

    @State private var bubbleSize: CGSize = .zero
    @State private var bubbleMeasured: Bool = false

    private let arrowHeight: CGFloat = 10
    private let arrowBase:   CGFloat = 20

    private var targetRect: CGRect? {
        request.targetKey.flatMap { labelRegistry.frame(for: $0) }
    }

    private var resolvedPosition: TooltipPosition {
        if request.position != .auto { return request.position }
        guard let r = targetRect else { return .below }
        let candidates: [(CGFloat, TooltipPosition)] = [
            (r.minY,                        .above),
            (screenSize.height - r.maxY,    .below),
            (r.minX,                        .left),
            (screenSize.width  - r.maxX,    .right),
        ]
        return candidates.max { $0.0 < $1.0 }?.1 ?? .below
    }

    private var arrowColor: Color { ColorUtil.fromString(request.arrowColorHex) ?? .white }

    /// Fraction [0..1] along the bubble edge at which the arrow apex is drawn.
    ///
    /// 0.5 = centered. When the bubble is edge-clamped the fraction shifts so
    /// the apex still points at the target center.
    private var arrowFraction: CGFloat {
        guard let r = targetRect else { return 0.5 }
        let pos = resolvedPosition
        let bw  = bubbleSize.width
        let bh  = bubbleSize.height

        switch pos {
        case .above, .below:
            guard bw > 0 else { return 0.5 }
            let cx        = (r.minX + r.maxX) / 2
            let clampedCx = cx.clamped(bw / 2, screenSize.width - bw / 2)
            return (0.5 + (cx - clampedCx) / bw).clamped(0.1, 0.9)
        case .left, .right:
            guard bh > 0 else { return 0.5 }
            let cy        = (r.minY + r.maxY) / 2
            let clampedCy = cy.clamped(bh / 2, screenSize.height - bh / 2)
            return (0.5 + (cy - clampedCy) / bh).clamped(0.1, 0.9)
        case .auto:
            return 0.5
        }
    }

    var body: some View {
        let pos      = resolvedPosition
        let color    = arrowColor
        let rect     = targetRect
        let fraction = arrowFraction

        bubbleContent(pos: pos, arrowColor: color, arrowFraction: fraction)
            // cap width so DUI components that fill available width don't expand
            // to screen width inside the unconstrained GeometryReader
            .frame(maxWidth: 320)
            .fixedSize(horizontal: false, vertical: true)
            .background(GeometryReader { p in
                Color.clear.preference(key: _BubbleSizeKey.self, value: p.size)
            })
            .onPreferenceChange(_BubbleSizeKey.self) { size in
                bubbleSize = size
                bubbleMeasured = true
            }
            .opacity(bubbleMeasured ? 1 : 0)
            .position(center(for: pos, targetRect: rect))
    }

    @ViewBuilder
    private func bubbleContent(
        pos: TooltipPosition,
        arrowColor: Color,
        arrowFraction: CGFloat,
    ) -> some View {
        switch pos {
        case .above:
            component()
                .padding(.bottom, arrowHeight)
                .overlay(alignment: .bottom) {
                    arrowShape(.down, color: arrowColor, fraction: arrowFraction)
                }
        case .below:
            component()
                .padding(.top, arrowHeight)
                .overlay(alignment: .top) {
                    arrowShape(.up, color: arrowColor, fraction: arrowFraction)
                }
        case .left:
            component()
                .padding(.trailing, arrowHeight)
                .overlay(alignment: .trailing) {
                    arrowShape(.right, color: arrowColor, fraction: arrowFraction)
                }
        case .right:
            component()
                .padding(.leading, arrowHeight)
                .overlay(alignment: .leading) {
                    arrowShape(.left, color: arrowColor, fraction: arrowFraction)
                }
        case .auto:
            component()
        }
    }

    private func component() -> AnyView {
        DUIFactory.shared.createComponent(request.componentId, args: request.args ?? [:])
    }

    /// Returns the `.position()` center point for the bubble.
    ///
    /// `bubbleSize` is measured after padding, so it already includes `arrowHeight`.
    /// We offset the center by half the bubble size from the target edge so the
    /// arrow tip (at the padded edge) lands exactly on the target rect boundary.
    private func center(for pos: TooltipPosition, targetRect: CGRect?) -> CGPoint {
        guard let r = targetRect else {
            return CGPoint(x: screenSize.width / 2, y: screenSize.height / 2)
        }
        let cx = (r.minX + r.maxX) / 2
        let cy = (r.minY + r.maxY) / 2
        let bw = bubbleSize.width
        let bh = bubbleSize.height

        switch pos {
        case .above:
            // Arrow tip (bottom of bubble) must sit on r.minY → center.y = r.minY - bh/2
            let y = r.minY - bh / 2
            return CGPoint(
                x: cx.clamped(bw / 2, screenSize.width - bw / 2),
                y: max(y, bh / 2),
            )
        case .below:
            // Arrow tip (top of bubble) must sit on r.maxY → center.y = r.maxY + bh/2
            let y = r.maxY + bh / 2
            return CGPoint(
                x: cx.clamped(bw / 2, screenSize.width - bw / 2),
                y: min(y, screenSize.height - bh / 2),
            )
        case .left:
            // Arrow tip (right of bubble) must sit on r.minX → center.x = r.minX - bw/2
            let x = r.minX - bw / 2
            return CGPoint(
                x: max(x, bw / 2),
                y: cy.clamped(bh / 2, screenSize.height - bh / 2),
            )
        case .right:
            // Arrow tip (left of bubble) must sit on r.maxX → center.x = r.maxX + bw/2
            let x = r.maxX + bw / 2
            return CGPoint(
                x: min(x, screenSize.width - bw / 2),
                y: cy.clamped(bh / 2, screenSize.height - bh / 2),
            )
        case .auto:
            return CGPoint(x: cx, y: r.maxY + bh / 2)
        }
    }

    /// Draws a filled triangle whose apex sits at `fraction` along the bubble edge.
    ///
    /// The canvas spans the full bubble width (vertical arrows) or height (horizontal
    /// arrows) so the apex can point anywhere along the edge, not just within a fixed
    /// 20 px strip. The base of the triangle is always `arrowBase` wide.
    private func arrowShape(_ dir: _ArrowDir, color: Color, fraction: CGFloat = 0.5) -> some View {
        let isVertical = (dir == .up || dir == .down)
        let ab = arrowBase
        return Canvas { ctx, size in
            var path = Path()
            switch dir {
            case .up:
                let apexX = size.width * fraction
                let baseL = (apexX - ab / 2).clamped(0, size.width)
                let baseR = (apexX + ab / 2).clamped(0, size.width)
                path.move(to: CGPoint(x: apexX, y: 0))
                path.addLine(to: CGPoint(x: baseR, y: size.height))
                path.addLine(to: CGPoint(x: baseL, y: size.height))
            case .down:
                let apexX = size.width * fraction
                let baseL = (apexX - ab / 2).clamped(0, size.width)
                let baseR = (apexX + ab / 2).clamped(0, size.width)
                path.move(to: CGPoint(x: baseL, y: 0))
                path.addLine(to: CGPoint(x: baseR, y: 0))
                path.addLine(to: CGPoint(x: apexX, y: size.height))
            case .left:
                let apexY = size.height * fraction
                let baseT = (apexY - ab / 2).clamped(0, size.height)
                let baseB = (apexY + ab / 2).clamped(0, size.height)
                path.move(to: CGPoint(x: 0, y: apexY))
                path.addLine(to: CGPoint(x: size.width, y: baseT))
                path.addLine(to: CGPoint(x: size.width, y: baseB))
            case .right:
                let apexY = size.height * fraction
                let baseT = (apexY - ab / 2).clamped(0, size.height)
                let baseB = (apexY + ab / 2).clamped(0, size.height)
                path.move(to: CGPoint(x: size.width, y: apexY))
                path.addLine(to: CGPoint(x: 0, y: baseT))
                path.addLine(to: CGPoint(x: 0, y: baseB))
            }
            path.closeSubpath()
            ctx.fill(path, with: .color(color))
        }
        .frame(
            width:  isVertical ? nil : arrowHeight,
            height: isVertical ? arrowHeight : nil
        )
    }

    private enum _ArrowDir { case up, down, left, right }
}

// MARK: - Private preference key

private struct _BubbleSizeKey: PreferenceKey {
    static let defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let n = nextValue()
        if n != .zero { value = n }
    }
}
// MARK: - CGFloat clamp helper

private extension CGFloat {
    func clamped(_ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
        Swift.min(Swift.max(self, lo), hi)
    }
}
