import SwiftUI

@MainActor
final class VWStack: VirtualStatelessWidget<StackProps> {
    override func render(_ payload: RenderPayload) -> AnyView {
        let children = self.children ?? []
        guard !children.isEmpty else { return empty() }

        let alignment = stackAlignment

        let nonPositionedChildren = children.filter { positionedProps(for: $0) == nil }

        // If no non-positioned children, fall back to a plain ZStack.
        if nonPositionedChildren.isEmpty {
            var stack = AnyView(plainLayer(children: children, payload: payload, alignment: alignment))
            if props.fit == "expand" {
                stack = AnyView(stack.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment))
            }
            return AnyView(stack)
        }

        // Base view: only non-positioned children determine the stack's layout size.
        var base = AnyView(plainLayer(children: nonPositionedChildren, payload: payload, alignment: alignment))
        if props.fit == "expand" {
            base = AnyView(base.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment))
        }

        // The index of the first non-positioned child in the original order.
        // Positioned children whose index is less than this are rendered behind
        // the base (via .background); those after are rendered in front (.overlay).
        let firstNonPositionedIndex = children.firstIndex { positionedProps(for: $0) == nil } ?? children.count

        var result = base
        for (index, child) in children.enumerated() {
            guard let position = positionedProps(for: child) else { continue }

            let top    = payload.eval(position.top).map    { CGFloat($0) }
            let bottom = payload.eval(position.bottom).map { CGFloat($0) }
            let left   = payload.eval(position.left).map   { CGFloat($0) }
            let right  = payload.eval(position.right).map  { CGFloat($0) }
            let widthConstraint  = payload.eval(position.width).map  { CGFloat($0) }
            let heightConstraint = payload.eval(position.height).map { CGFloat($0) }

            let cornerAlignment = positionedAlignment(
                top: top, bottom: bottom,
                left: left, right: right,
                stackAlignment: alignment
            )

            var view = child.toWidget(payload)

            // Explicit size from position props.
            if widthConstraint != nil || heightConstraint != nil {
                view = AnyView(view.frame(width: widthConstraint, height: heightConstraint))
            }

            // Stretch to fill the distance between two anchors on an axis.
            if left != nil, right != nil, widthConstraint == nil {
                view = AnyView(view.frame(maxWidth: .infinity, alignment: .leading))
            }
            if top != nil, bottom != nil, heightConstraint == nil {
                view = AnyView(view.frame(maxHeight: .infinity, alignment: .top))
            }

            // Offset from the corner anchor.
            // For left/top: positive value = move away from that edge.
            // For right/bottom: negative value = overflow outside that edge.
            let dx: CGFloat = left.map { $0 } ?? right.map  { -$0 } ?? 0
            let dy: CGFloat = top.map  { $0 } ?? bottom.map { -$0 } ?? 0

            let positionedView = AnyView(view.offset(x: dx, y: dy))

            if index < firstNonPositionedIndex {
                // Behind: use .background so non-positioned children render on top.
                result = AnyView(result.background(alignment: cornerAlignment) { positionedView })
            } else {
                // In front: use .overlay.
                result = AnyView(result.overlay(alignment: cornerAlignment) { positionedView })
            }
        }

        return AnyView(result.clipped())
    }

    // A plain ZStack layer (used for the non-positioned base and the all-positioned fallback).
    private func plainLayer(
        children: [VirtualWidget],
        payload: RenderPayload,
        alignment: Alignment
    ) -> some View {
        ZStack(alignment: alignment) {
            ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                child.toWidget(payload)
            }
        }
    }

    private var stackAlignment: Alignment {
        To.alignment(props.childAlignment) ?? .topLeading
    }

    private func positionedProps(for child: VirtualWidget) -> PositionedProps? {
        (child as? VirtualLeafStatelessWidgetProtocol)?.parentPropsValue?.position
    }

    private func positionedAlignment(
        top: CGFloat?,
        bottom: CGFloat?,
        left: CGFloat?,
        right: CGFloat?,
        stackAlignment: Alignment
    ) -> Alignment {
        let vertical: VerticalAnchor   = top != nil    ? .top    : (bottom != nil ? .bottom  : verticalAnchor(from: stackAlignment))
        let horizontal: HorizontalAnchor = left != nil ? .leading : (right != nil  ? .trailing : horizontalAnchor(from: stackAlignment))
        return alignment(horizontal: horizontal, vertical: vertical)
    }

    private func horizontalAnchor(from alignment: Alignment) -> HorizontalAnchor {
        switch alignment {
        case .topLeading, .leading, .bottomLeading: return .leading
        case .topTrailing, .trailing, .bottomTrailing: return .trailing
        default: return .center
        }
    }

    private func verticalAnchor(from alignment: Alignment) -> VerticalAnchor {
        switch alignment {
        case .topLeading, .top, .topTrailing: return .top
        case .bottomLeading, .bottom, .bottomTrailing: return .bottom
        default: return .center
        }
    }

    private func alignment(horizontal: HorizontalAnchor, vertical: VerticalAnchor) -> Alignment {
        switch (vertical, horizontal) {
        case (.top, .leading):    return .topLeading
        case (.top, .center):     return .top
        case (.top, .trailing):   return .topTrailing
        case (.center, .leading): return .leading
        case (.center, .center):  return .center
        case (.center, .trailing):return .trailing
        case (.bottom, .leading): return .bottomLeading
        case (.bottom, .center):  return .bottom
        case (.bottom, .trailing):return .bottomTrailing
        }
    }
}

private enum HorizontalAnchor { case leading, center, trailing }
private enum VerticalAnchor   { case top, center, bottom }
