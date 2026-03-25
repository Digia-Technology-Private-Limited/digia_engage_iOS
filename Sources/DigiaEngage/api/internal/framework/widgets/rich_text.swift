import SwiftUI

@MainActor
final class VWRichText: VirtualLeafStatelessWidget<RichTextProps> {
    override func render(_ payload: RenderPayload) -> AnyView {
        let spans = props.textSpans.compactMap { span -> DigiaRichTextSpanViewModel? in
            guard let value = payload.eval(span.text), !value.isEmpty else { return nil }
            let style = span.resolvedStyle ?? props.textStyle
            return DigiaRichTextSpanViewModel(
                text: value,
                style: style,
                action: span.onClick,
                payload: payload
            )
        }

        guard !spans.isEmpty else { return empty() }

        if let inlineText = inlineText(from: spans, payload: payload) {
            return configured(view: inlineText, payload: payload)
        }

        return configured(view: AnyView(
            DigiaWrappingFlowLayout(spacing: 0, lineSpacing: 0) {
                ForEach(Array(spans.enumerated()), id: \.offset) { _, span in
                    DigiaRichTextSpanView(span: span) {
                        payload.executeAction(span.action, triggerType: "onTap")
                    }
                }
            }
        ), payload: payload)
    }

    private func configured(view: AnyView, payload: RenderPayload) -> AnyView {
        var current = view

        if payload.eval(props.overflow) == "fade" {
            current = AnyView(
                current.mask(
                    LinearGradient(
                        colors: [.black, .black, .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            )
        }

        if let alignment = To.alignment(payload.eval(props.alignment)) {
            current = AnyView(current.frame(maxWidth: .infinity, alignment: alignment))
        }

        return current
    }

    private func inlineText(
        from spans: [DigiaRichTextSpanViewModel],
        payload: RenderPayload
    ) -> AnyView? {
        guard spans.allSatisfy(\.supportsInlineText) else { return nil }

        let combined = spans.reduce(nil as Text?) { partial, span in
            let segment = span.inlineText()
            if let partial {
                return partial + segment
            }
            return segment
        }

        guard let combined else { return nil }

        var current = AnyView(combined)
        current = AnyView(current.lineLimit(payload.eval(props.maxLines)))
        if payload.eval(props.overflow) == "ellipsis" {
            current = AnyView(current.truncationMode(.tail))
        }

        return AnyView(current.multilineTextAlignment(To.textAlignment(payload.eval(props.alignment))))
    }
}

@MainActor
private struct DigiaRichTextSpanViewModel: Identifiable {
    let id = UUID()
    let text: String
    let font: Font
    let textColor: Color
    let foreground: AnyShapeStyle
    let backgroundColor: Color?
    let decoration: String?
    let decorationColor: Color
    let action: ActionFlow?
    let usesGradient: Bool

    init(
        text: String,
        style: TextStyleProps?,
        action: ActionFlow?,
        payload: RenderPayload
    ) {
        self.text = text
        font = payload.resources.font(textStyle: style)
        let resolvedTextColor = payload.evalColor(style?.textColor) ?? .primary
        textColor = resolvedTextColor
        if let gradient = TextStyleUtil.makeTextGradient(from: style?.gradient, resolveColor: payload.resolveColor) {
            foreground = AnyShapeStyle(gradient)
            usesGradient = true
        } else {
            foreground = AnyShapeStyle(resolvedTextColor)
            usesGradient = false
        }
        backgroundColor = payload.evalColor(style?.textBackgroundColor)
        decoration = style?.textDecoration?.lowercased()
        decorationColor = payload.evalColor(style?.textDecorationColor) ?? resolvedTextColor
        self.action = action
    }

    var supportsInlineText: Bool {
        action == nil &&
        !usesGradient &&
        backgroundColor == nil &&
        decoration != "overline"
    }

    func inlineText() -> Text {
        var current = Text(text)
            .font(font)
            .foregroundColor(textColor)

        if decoration == "underline" {
            current = current.underline(true, color: decorationColor)
        }
        if decoration == "linethrough" || decoration == "strikethrough" {
            current = current.strikethrough(true, color: decorationColor)
        }

        return current
    }

}

@MainActor
private struct DigiaRichTextSpanView: View {
    let span: DigiaRichTextSpanViewModel
    let onTap: () -> Void

    var body: some View {
        var current = AnyView(
            Text(span.text)
                .font(span.font)
                .foregroundStyle(span.foreground)
                .fixedSize()
        )

        current = TextStyleUtil.applyTextDecorations(
            to: current,
            backgroundColor: span.backgroundColor,
            decoration: span.decoration,
            decorationColor: span.decorationColor
        )

        if let action = span.action, !action.isEmpty {
            current = AnyView(current.contentShape(Rectangle()).onTapGesture(perform: onTap))
        }

        return current
    }
}

private struct DigiaWrappingFlowLayout<Content: View>: View {
    let spacing: CGFloat
    let lineSpacing: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        _DigiaWrappingLayout(spacing: spacing, lineSpacing: lineSpacing) {
            content()
        }
    }
}

private struct _DigiaWrappingLayout: Layout {
    let spacing: CGFloat
    let lineSpacing: CGFloat

    init(spacing: CGFloat, lineSpacing: CGFloat) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if lineWidth + size.width > maxWidth, lineWidth > 0 {
                totalHeight += lineHeight + lineSpacing
                totalWidth = max(totalWidth, lineWidth - spacing)
                lineWidth = 0
                lineHeight = 0
            }

            lineWidth += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        totalHeight += lineHeight
        totalWidth = max(totalWidth, max(0, lineWidth - spacing))
        return CGSize(width: min(totalWidth, maxWidth), height: totalHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += lineHeight + lineSpacing
                lineHeight = 0
            }

            subview.place(
                at: CGPoint(x: x, y: y),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
