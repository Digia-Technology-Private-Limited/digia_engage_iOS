import SwiftUI

@MainActor
final class VWWrap: VirtualStatelessWidget<WrapProps> {
    override func render(_ payload: RenderPayload) -> AnyView {
        let resolvedChildren = makeChildren(payload: payload)
        guard !resolvedChildren.isEmpty else { return empty() }

        let spacing = CGFloat(payload.eval(props.spacing) ?? 0)
        let runSpacing = CGFloat(payload.eval(props.runSpacing) ?? 0)
        let axis = DigiaWrapAxis(rawValue: payload.eval(props.direction) ?? "horizontal") ?? .horizontal
        let itemAlignment = DigiaWrapAlignment(rawValue: payload.eval(props.wrapAlignment) ?? "start") ?? .start
        let runAlignment = DigiaWrapAlignment(rawValue: payload.eval(props.runAlignment) ?? "start") ?? .start
        let crossAlignment = DigiaWrapCrossAlignment(rawValue: payload.eval(props.wrapCrossAlignment) ?? "start") ?? .start
        let verticalDirection = DigiaVerticalDirection(rawValue: payload.eval(props.verticalDirection) ?? "down") ?? .down
        let clipBehavior = payload.eval(props.clipBehavior)

        var content = AnyView(
            DigiaWrapLayoutView(
                axis: axis,
                spacing: spacing,
                runSpacing: runSpacing,
                itemAlignment: itemAlignment,
                runAlignment: runAlignment,
                crossAlignment: crossAlignment,
                verticalDirection: verticalDirection,
                children: resolvedChildren
            )
        )

        if clipBehavior != nil, clipBehavior != "none" {
            content = AnyView(content.clipped())
        }

        return content
    }

    private func makeChildren(payload: RenderPayload) -> [AnyView] {
        guard let children, !children.isEmpty else { return [] }

        if let repeatedItems = resolveDataSource(payload: payload) {
            guard let template = children.first else { return [] }
            return repeatedItems.enumerated().map { index, item in
                template.toWidget(payload.copyWithChainedContext(WidgetUtil.loopExprContext(item, index: index, refName: refName)))
            }
        }

        return children.map { $0.toWidget(payload) }
    }

    private func resolveDataSource(payload: RenderPayload) -> [Any]? {
        guard let resolved = payload.evalAny(props.dataSource) else { return nil }
        return resolved as? [Any]
    }
}

private enum DigiaWrapAxis: String {
    case horizontal
    case vertical
}

private enum DigiaWrapAlignment: String {
    case start
    case end
    case center
    case spaceBetween
    case spaceAround
    case spaceEvenly
}

private enum DigiaWrapCrossAlignment: String {
    case start
    case end
    case center
}

private enum DigiaVerticalDirection: String {
    case up
    case down
}

private struct DigiaWrapLayoutView: View {
    let axis: DigiaWrapAxis
    let spacing: CGFloat
    let runSpacing: CGFloat
    let itemAlignment: DigiaWrapAlignment
    let runAlignment: DigiaWrapAlignment
    let crossAlignment: DigiaWrapCrossAlignment
    let verticalDirection: DigiaVerticalDirection
    let children: [AnyView]

    var body: some View {
        DigiaWrapLayout(
            axis: axis,
            spacing: spacing,
            runSpacing: runSpacing,
            itemAlignment: itemAlignment,
            runAlignment: runAlignment,
            crossAlignment: crossAlignment,
            verticalDirection: verticalDirection
        ) {
            ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                child
            }
        }
    }
}

private struct DigiaWrapLayout: Layout {
    let axis: DigiaWrapAxis
    let spacing: CGFloat
    let runSpacing: CGFloat
    let itemAlignment: DigiaWrapAlignment
    let runAlignment: DigiaWrapAlignment
    let crossAlignment: DigiaWrapCrossAlignment
    let verticalDirection: DigiaVerticalDirection

    struct CacheData {
        var arrangement = Arrangement(runs: [], maxMain: 0, totalCross: 0)
        var constrainedMain: CGFloat = .infinity
    }

    func makeCache(subviews _: Subviews) -> CacheData {
        CacheData()
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout CacheData) -> CGSize {
        cache = arrange(subviews: subviews, proposal: proposal)

        switch axis {
        case .horizontal:
            let width = proposal.width.map { min(cache.arrangement.maxMain, $0) } ?? cache.arrangement.maxMain
            return CGSize(width: width, height: cache.arrangement.totalCross)
        case .vertical:
            let height = proposal.height.map { min(cache.arrangement.maxMain, $0) } ?? cache.arrangement.maxMain
            return CGSize(width: cache.arrangement.totalCross, height: height)
        }
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout CacheData) {
        cache = arrange(subviews: subviews, proposal: proposal)
        guard !cache.arrangement.runs.isEmpty else { return }

        let containerMain = axis == .horizontal ? bounds.width : bounds.height
        let containerCross = axis == .horizontal ? bounds.height : bounds.width

        let runLayout = layoutOffsets(
            count: cache.arrangement.runs.count,
            contentExtent: cache.arrangement.totalCross,
            containerExtent: containerCross,
            baseSpacing: runSpacing,
            alignment: runAlignment
        )

        let runIndices: [Int]
        if axis == .horizontal, verticalDirection == .up {
            runIndices = Array(cache.arrangement.runs.indices.reversed())
        } else {
            runIndices = Array(cache.arrangement.runs.indices)
        }

        var runCrossCursor = runLayout.start
        for runIndex in runIndices {
            let run = cache.arrangement.runs[runIndex]

            let itemLayout = layoutOffsets(
                count: run.items.count,
                contentExtent: run.main,
                containerExtent: containerMain,
                baseSpacing: spacing,
                alignment: itemAlignment
            )

            let itemIndices: [Int]
            if axis == .vertical, verticalDirection == .up {
                itemIndices = Array(run.items.indices.reversed())
            } else {
                itemIndices = Array(run.items.indices)
            }

            var itemMainCursor = itemLayout.start
            for itemIndex in itemIndices {
                let item = run.items[itemIndex]
                let itemCrossOffset: CGFloat
                switch crossAlignment {
                case .start:
                    itemCrossOffset = 0
                case .center:
                    itemCrossOffset = (run.cross - item.cross) / 2
                case .end:
                    itemCrossOffset = run.cross - item.cross
                }

                let origin: CGPoint
                let childProposal: ProposedViewSize
                switch axis {
                case .horizontal:
                    origin = CGPoint(
                        x: bounds.minX + itemMainCursor,
                        y: bounds.minY + runCrossCursor + itemCrossOffset
                    )
                    childProposal = ProposedViewSize(width: item.size.width, height: item.size.height)
                case .vertical:
                    origin = CGPoint(
                        x: bounds.minX + runCrossCursor + itemCrossOffset,
                        y: bounds.minY + itemMainCursor
                    )
                    childProposal = ProposedViewSize(width: item.size.width, height: item.size.height)
                }

                subviews[item.index].place(at: origin, proposal: childProposal)

                itemMainCursor += item.main + itemLayout.betweenSpacing
            }

            runCrossCursor += run.cross + runLayout.betweenSpacing
        }
    }

    private func arrange(subviews: Subviews, proposal: ProposedViewSize) -> CacheData {
        let mainLimit = axis == .horizontal ? (proposal.width ?? .infinity) : (proposal.height ?? .infinity)

        var runs: [Run] = []
        var current = Run(items: [], main: 0, cross: 0)

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            let itemMain = axis == .horizontal ? size.width : size.height
            let itemCross = axis == .horizontal ? size.height : size.width
            let spacingBefore = current.items.isEmpty ? 0 : spacing
            let nextMain = current.main + spacingBefore + itemMain

            if !current.items.isEmpty, nextMain > mainLimit {
                runs.append(current)
                current = Run(items: [], main: 0, cross: 0)
            }

            let effectiveSpacing = current.items.isEmpty ? 0 : spacing
            current.items.append(Item(index: index, size: size, main: itemMain, cross: itemCross))
            current.main += effectiveSpacing + itemMain
            current.cross = max(current.cross, itemCross)
        }

        if !current.items.isEmpty {
            runs.append(current)
        }

        let maxMain = runs.map(\.main).max() ?? 0
        let totalCross = runs.reduce(CGFloat.zero) { partial, run in
            partial + run.cross
        } + max(0, CGFloat(max(runs.count - 1, 0))) * runSpacing

        return CacheData(
            arrangement: Arrangement(runs: runs, maxMain: maxMain, totalCross: totalCross),
            constrainedMain: mainLimit
        )
    }

    private func layoutOffsets(
        count: Int,
        contentExtent: CGFloat,
        containerExtent: CGFloat,
        baseSpacing: CGFloat,
        alignment: DigiaWrapAlignment
    ) -> (start: CGFloat, betweenSpacing: CGFloat) {
        guard count > 0 else { return (0, 0) }
        let extra = max(0, containerExtent - contentExtent)

        switch alignment {
        case .start:
            return (0, baseSpacing)
        case .end:
            return (extra, baseSpacing)
        case .center:
            return (extra / 2, baseSpacing)
        case .spaceBetween:
            guard count > 1 else { return (0, baseSpacing) }
            return (0, baseSpacing + extra / CGFloat(count - 1))
        case .spaceAround:
            let extraGap = extra / CGFloat(count)
            return (extraGap / 2, baseSpacing + extraGap)
        case .spaceEvenly:
            let extraGap = extra / CGFloat(count + 1)
            return (extraGap, baseSpacing + extraGap)
        }
    }

    struct Arrangement {
        let runs: [Run]
        let maxMain: CGFloat
        let totalCross: CGFloat
    }

    struct Run {
        var items: [Item]
        var main: CGFloat
        var cross: CGFloat
    }

    struct Item {
        let index: Int
        let size: CGSize
        let main: CGFloat
        let cross: CGFloat
    }
}
