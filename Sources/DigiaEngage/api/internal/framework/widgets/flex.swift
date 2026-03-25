import Foundation
import SwiftUI

@MainActor
final class VWFlex: VirtualStatelessWidget<FlexProps> {
    enum Direction {
        case horizontal
        case vertical
    }

    let direction: Direction

    init(
        direction: Direction,
        props: FlexProps,
        commonProps: CommonProps?,
        parentProps: ParentProps?,
        childGroups: [String: [VirtualWidget]]?,
        parent: VirtualWidget?,
        refName: String?
    ) {
        self.direction = direction
        super.init(
            props: props,
            commonProps: commonProps,
            parentProps: parentProps,
            childGroups: childGroups,
            parent: parent,
            refName: refName
        )
    }

    override func render(_ payload: RenderPayload) -> AnyView {
        let childViews = resolvedChildren(payload: payload)
        guard !childViews.isEmpty else { return empty() }

        let spacing = CGFloat(props.spacing ?? 0)
        let startSpacing = CGFloat(props.startSpacing ?? 0)
        let endSpacing = CGFloat(props.endSpacing ?? 0)
        let mainAxisAlignment = To.mainAxisAlignment(props.mainAxisAlignment)
        let crossAxisAlignment = props.crossAxisAlignment ?? "center"
        let mainAxisSize = props.mainAxisSize ?? "max"

        // Use a custom Layout to match Flutter's Flex/Row/Column sizing
        // semantics (Expanded/Flexible) and alignment distribution.
        let content = AnyView(
            DigiaFlexLayoutView(
                direction: direction,
                mainAxisAlignment: mainAxisAlignment,
                crossAxisAlignment: crossAxisAlignment,
                mainAxisSize: mainAxisSize,
                spacing: spacing,
                startSpacing: startSpacing,
                endSpacing: endSpacing,
                children: childViews
            )
        )

        let framed: AnyView
        if props.mainAxisSize == "max" {
            switch direction {
            case .vertical:
                // Column with mainAxisSize.max should expand on main axis (height).
                framed = AnyView(content.frame(maxHeight: .infinity, alignment: stackAlignment()))
            case .horizontal:
                // Row with mainAxisSize.max should expand on main axis (width).
                framed = AnyView(content.frame(maxWidth: .infinity, alignment: stackAlignment()))
            }
        } else {
            framed = content
        }

        if props.isScrollable == true {
            let scrollContent: AnyView
            switch direction {
            case .horizontal:
                // Keep the row content at intrinsic width; viewport sizing is adjusted
                // below based on mainAxisSize to mirror Flutter behavior.
                scrollContent = AnyView(content.fixedSize(horizontal: true, vertical: false))
            case .vertical:
                scrollContent = AnyView(content.fixedSize(horizontal: false, vertical: true))
            }

            var scrollView = AnyView(
                ScrollView(direction == .vertical ? .vertical : .horizontal, showsIndicators: false) {
                    scrollContent
                }
            )

            // For static (non data-driven) horizontal rows with mainAxisSize=min,
            // preserve intrinsic viewport width to match Flutter shrink-wrapping.
            // Data-driven rows (e.g., swipe strips/carousels) should keep the
            // available viewport width so horizontal scrolling remains usable.
            let hasResolvedDataSource = resolveDataSource(payload: payload) != nil
            if direction == .horizontal,
               props.mainAxisSize == "min",
               !hasResolvedDataSource {
                scrollView = AnyView(scrollView.fixedSize(horizontal: true, vertical: false))
            }

            return scrollView
        }

        return framed
    }

    func repeatedChildren(from children: [VirtualWidget], payload: RenderPayload) -> [AnyView] {
        guard let childToRepeat = children.first else {
            return []
        }

        guard let dataSource = resolveDataSource(payload: payload) else {
            return children.map { renderChild($0, payload: payload) }
        }

        return dataSource.enumerated().map { index, item in
            let context = WidgetUtil.loopExprContext(item, index: index, refName: refName)
            return renderChild(childToRepeat, payload: payload.copyWithChainedContext(context))
        }
    }

    private func resolvedChildren(payload: RenderPayload) -> [AnyView] {
        let baseChildren = children ?? []
        if resolveDataSource(payload: payload) != nil {
            return repeatedChildren(from: baseChildren, payload: payload)
        }
        return baseChildren.map { renderChild($0, payload: payload) }
    }

    private func renderChild(_ child: VirtualWidget, payload: RenderPayload) -> AnyView {
        var view = child.toWidget(payload)

        guard let childProps = (child as? VirtualLeafStatelessWidgetProtocol)?.parentPropsValue,
              let expansion = childProps.expansion,
              let type = expansion.type.flatMap(DigiaFlexFitType.init(rawValue:)) else {
            return view
        }

        let flexValue = Double(payload.eval(expansion.flexValue) ?? 1)

        if type == .tight {
            switch direction {
            case .horizontal:
                view = AnyView(view.frame(maxWidth: .infinity, alignment: .topLeading))
            case .vertical:
                view = AnyView(view.frame(maxHeight: .infinity, alignment: .topLeading))
            }
        }

        // Provide layout metadata for DigiaFlexLayout via LayoutValueKey.
        return AnyView(
            view
                .layoutValue(key: DigiaFlexLayout.FlexKey.self, value: Int(max(1, flexValue)))
                .layoutValue(key: DigiaFlexLayout.FitKey.self, value: type)
        )
    }

    private func resolveDataSource(payload: RenderPayload) -> [Any]? {
        switch props.dataSource {
        case let .array(values):
            return values.map(\.anyValue)
        case let .string(value):
            guard ExpressionUtil.hasExpression(value),
                  let resolved = ExpressionUtil.evaluateAny(value, context: payload.scopeContext) else {
                return nil
            }
            return resolved as? [Any]
        default:
            return nil
        }
    }

    private func stackAlignment() -> Alignment {
        switch (direction, props.mainAxisAlignment, props.crossAxisAlignment) {
        case (.vertical, "end", "end"):
            return .bottomTrailing
        case (.vertical, "end", "center"):
            return .bottom
        case (.vertical, "end", _):
            return .bottomLeading
        case (.vertical, "center", "end"):
            return .trailing
        case (.vertical, "center", "center"):
            return .center
        case (.vertical, "center", _):
            return .leading
        case (.horizontal, "end", "start"):
            return .topTrailing
        case (.horizontal, "end", "end"):
            return .bottomTrailing
        case (.horizontal, "end", _):
            return .trailing
        case (.horizontal, "center", "start"):
            return .top
        case (.horizontal, "center", "end"):
            return .bottom
        case (.horizontal, "center", _):
            return .center
        case (.horizontal, _, "start"):
            return .topLeading
        case (.horizontal, _, "end"):
            return .bottomLeading
        default:
            return .topLeading
        }
    }
}

// MARK: - Flex Layout (Flutter-like)

private struct DigiaFlexLayoutView: View {
    let direction: VWFlex.Direction
    let mainAxisAlignment: DigiaMainAxisAlignment
    let crossAxisAlignment: String
    let mainAxisSize: String
    let spacing: CGFloat
    let startSpacing: CGFloat
    let endSpacing: CGFloat
    let children: [AnyView]

    var body: some View {
        DigiaFlexLayout(
            direction: direction,
            mainAxisAlignment: mainAxisAlignment,
            crossAxisAlignment: crossAxisAlignment,
            mainAxisSize: mainAxisSize,
            spacing: spacing,
            startSpacing: startSpacing,
            endSpacing: endSpacing
        ) {
            ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                child
            }
        }
    }
}

private struct DigiaFlexLayout: Layout {
    struct FlexKey: LayoutValueKey { static let defaultValue: Int = 0 }
    struct FitKey: LayoutValueKey { static let defaultValue: DigiaFlexFitType? = nil }

    let direction: VWFlex.Direction
    let mainAxisAlignment: DigiaMainAxisAlignment
    let crossAxisAlignment: String
    let mainAxisSize: String
    let spacing: CGFloat
    let startSpacing: CGFloat
    let endSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let measured = measure(proposal: proposal, subviews: subviews)
        return measured.containerSize
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let measured = measure(proposal: ProposedViewSize(bounds.size), subviews: subviews)

        let mainAvailable = measured.mainAvailable
        let totalFixed = measured.totalFixedMain
        let totalFlex = measured.totalFlex
        let baseSpacingTotal = measured.baseSpacingTotal

        let remaining = max(0, mainAvailable - totalFixed - baseSpacingTotal - startSpacing - endSpacing)

        // Allocate space per flex factor.
        var allocations = Array(repeating: CGFloat(0), count: subviews.count)
        if totalFlex > 0, remaining > 0 {
            for idx in measured.flexIndices {
                let flex = CGFloat(max(1, subviews[idx][FlexKey.self]))
                allocations[idx] = remaining * (flex / CGFloat(totalFlex))
            }
        }

        // Compute main-axis offsets for mainAxisAlignment.
        let contentMain = startSpacing + endSpacing + baseSpacingTotal + totalFixed + allocations.reduce(0, +)

        let freeSpace = max(0, mainAvailable - contentMain)
        let (leadingGap, betweenExtra, trailingGap) = gaps(for: mainAxisAlignment, itemCount: subviews.count, freeSpace: freeSpace)

        var cursor = mainStart(in: bounds) + leadingGap + startSpacing

        for i in subviews.indices {
            let fit = subviews[i][FitKey.self]
            let isFlex = measured.flexIndices.contains(i)

            let cross = measured.boundedCross
            let crossSize = cross ?? (crossAxisAlignment == "stretch" ? measured.crossAvailable : nil)

            let proposed = proposalForChild(
                isFlex: isFlex,
                fit: fit,
                allocatedMain: allocations[i],
                cross: crossSize
            )

            let childSize = subviews[i].sizeThatFits(proposed)

            let finalMain: CGFloat
            if isFlex, fit == .tight {
                finalMain = allocations[i] > 0 ? allocations[i] : childMain(childSize)
            } else if isFlex {
                finalMain = allocations[i] > 0 ? min(childMain(childSize), allocations[i]) : childMain(childSize)
            } else {
                finalMain = childMain(childSize)
            }

            let finalCross: CGFloat = (crossAxisAlignment == "stretch")
                ? (crossSize ?? childCross(childSize))
                : childCross(childSize)

            let origin = point(main: cursor, cross: crossOrigin(in: bounds, childCross: finalCross))
            let placeProposal = ProposedViewSize(
                width: direction == .horizontal ? finalMain : finalCross,
                height: direction == .horizontal ? finalCross : finalMain
            )
            subviews[i].place(at: origin, anchor: .topLeading, proposal: placeProposal)

            cursor += finalMain
            if i < subviews.count - 1 {
                cursor += spacing + betweenExtra
            }
        }

        // trailing spacing is implicitly satisfied by bounds.
        _ = trailingGap + endSpacing
    }

    // MARK: - Measurement helpers

    private struct Measurement {
        let containerSize: CGSize
        let mainAvailable: CGFloat
        let crossAvailable: CGFloat
        let boundedCross: CGFloat?
        let totalFixedMain: CGFloat
        let totalFlex: Int
        let flexIndices: [Int]
        let baseSpacingTotal: CGFloat
    }

    private func measure(proposal: ProposedViewSize, subviews: Subviews) -> Measurement {
        let boundedMain = main(proposal)
        let boundedCross = cross(proposal)

        var totalFixed: CGFloat = 0
        var flexTotal: Int = 0
        var flexIdx: [Int] = []

        for (i, sv) in subviews.enumerated() {
            let flex = sv[FlexKey.self]
            let fit = sv[FitKey.self]
            if flex > 0, fit != nil {
                flexTotal += flex
                flexIdx.append(i)
            } else {
                let p = proposalForChild(isFlex: false, fit: nil, allocatedMain: 0, cross: boundedCross)
                let size = sv.sizeThatFits(p)
                totalFixed += childMain(size)
            }
        }

        let spacingTotal = CGFloat(max(0, subviews.count - 1)) * spacing

        let intrinsicFlex: CGFloat = {
            var total: CGFloat = 0
            for i in flexIdx {
                let p = proposalForChild(isFlex: false, fit: nil, allocatedMain: 0, cross: boundedCross)
                let size = subviews[i].sizeThatFits(p)
                total += childMain(size)
            }
            return total
        }()

        let intrinsicMain = startSpacing + endSpacing + spacingTotal + totalFixed + intrinsicFlex

        let containerMain: CGFloat = {
            guard let boundedMain else {
                return intrinsicMain
            }

            if mainAxisSize == "max" || !flexIdx.isEmpty {
                return boundedMain
            }

            return min(intrinsicMain, boundedMain)
        }()

        let intrinsicCross: CGFloat = {
            var maxCross: CGFloat = 0
            for i in subviews.indices {
                let p = proposalForChild(isFlex: false, fit: nil, allocatedMain: 0, cross: boundedCross)
                let size = subviews[i].sizeThatFits(p)
                maxCross = max(maxCross, childCross(size))
            }
            return maxCross
        }()

        let containerCross: CGFloat = {
            if crossAxisAlignment == "stretch", let boundedCross {
                return boundedCross
            }
            if let boundedCross {
                return min(intrinsicCross, boundedCross)
            }
            return intrinsicCross
        }()

        let containerSize = size(main: containerMain, cross: containerCross)
        return Measurement(
            containerSize: containerSize,
            mainAvailable: containerMain,
            crossAvailable: containerCross,
            boundedCross: boundedCross,
            totalFixedMain: totalFixed,
            totalFlex: flexTotal,
            flexIndices: flexIdx,
            baseSpacingTotal: spacingTotal
        )
    }

    private func proposalForChild(isFlex: Bool, fit: DigiaFlexFitType?, allocatedMain: CGFloat, cross: CGFloat?) -> ProposedViewSize {
        let proposedMain = allocatedMain > 0 ? allocatedMain : nil
        switch direction {
        case .horizontal:
            if isFlex {
                let width = (fit == .tight) ? proposedMain : proposedMain
                return ProposedViewSize(width: width, height: cross)
            }
            return ProposedViewSize(width: nil, height: cross)
        case .vertical:
            if isFlex {
                let height = (fit == .tight) ? proposedMain : proposedMain
                return ProposedViewSize(width: cross, height: height)
            }
            return ProposedViewSize(width: cross, height: nil)
        }
    }

    // MARK: - Alignment helpers

    private func gaps(for alignment: DigiaMainAxisAlignment, itemCount: Int, freeSpace: CGFloat) -> (CGFloat, CGFloat, CGFloat) {
        guard itemCount > 0 else { return (0, 0, 0) }
        switch alignment {
        case .start:
            return (0, 0, freeSpace)
        case .end:
            return (freeSpace, 0, 0)
        case .center:
            let half = freeSpace / 2
            return (half, 0, half)
        case .spaceBetween:
            let between = itemCount > 1 ? freeSpace / CGFloat(itemCount - 1) : 0
            return (0, between, 0)
        case .spaceAround:
            let between = freeSpace / CGFloat(itemCount)
            return (between / 2, between, between / 2)
        case .spaceEvenly:
            let between = freeSpace / CGFloat(itemCount + 1)
            return (between, between, between)
        }
    }

    // MARK: - Axis helpers

    private func main(_ proposal: ProposedViewSize) -> CGFloat? {
        direction == .horizontal ? proposal.width : proposal.height
    }

    private func cross(_ proposal: ProposedViewSize) -> CGFloat? {
        direction == .horizontal ? proposal.height : proposal.width
    }

    private func childMain(_ size: CGSize) -> CGFloat {
        direction == .horizontal ? size.width : size.height
    }

    private func childCross(_ size: CGSize) -> CGFloat {
        direction == .horizontal ? size.height : size.width
    }

    private func size(main: CGFloat, cross: CGFloat) -> CGSize {
        direction == .horizontal ? CGSize(width: main, height: cross) : CGSize(width: cross, height: main)
    }

    private func mainStart(in bounds: CGRect) -> CGFloat {
        direction == .horizontal ? bounds.minX : bounds.minY
    }

    private func crossOrigin(in bounds: CGRect, childCross: CGFloat) -> CGFloat {
        switch crossAxisAlignment {
        case "end":
            return (direction == .horizontal ? bounds.maxY : bounds.maxX) - childCross
        case "center":
            let crossSize = direction == .horizontal ? bounds.height : bounds.width
            return (direction == .horizontal ? bounds.minY : bounds.minX) + (crossSize - childCross) / 2
        default:
            return direction == .horizontal ? bounds.minY : bounds.minX
        }
    }

    private func point(main: CGFloat, cross: CGFloat) -> CGPoint {
        direction == .horizontal ? CGPoint(x: main, y: cross) : CGPoint(x: cross, y: main)
    }
}
