import SwiftUI

@MainActor
enum WidgetUtil {
    static func wrapInContainer(
        payload: RenderPayload,
        style: CommonStyle?,
        child: AnyView,
        skipSizing: Bool = false
    ) -> AnyView {
        guard let style else { return child }

        let borderRadius = resolveCornerRadius(style.borderRadius, payload: payload)
        var current = child

        if let padding = style.padding?.edgeInsets {
            current = AnyView(current.padding(padding))
        }

        if !skipSizing {
            current = applySizing(
                payload: payload,
                style: style,
                child: current
            )
        }

        current = AnyView(
            current.background(
                DigiaDecorationView(
                    payload: payload,
                    backgroundColor: payload.evalColor(style.bgColor),
                    border: style.border,
                    borderRadius: borderRadius
                )
            )
        )

        if let borderRadius {
            current = AnyView(current.clipShape(shape(for: borderRadius)))
        }

        if let clipBehavior = style.clipBehavior, clipBehavior != "none" {
            current = AnyView(current.clipped())
        }

        return current
    }

    static func wrapInAlign(
        value: String?,
        child: AnyView
    ) -> AnyView {
        guard let alignment = To.alignment(value) else { return child }
        return AnyView(child.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment))
    }

    static func applyMargin(
        style: CommonStyle?,
        child: AnyView
    ) -> AnyView {
        guard let margin = style?.margin?.edgeInsets else { return child }
        return AnyView(child.padding(margin))
    }

    static func wrapInTapGesture(
        payload: RenderPayload,
        actionFlow: ActionFlow?,
        child: AnyView
    ) -> AnyView {
        guard let actionFlow, !actionFlow.isEmpty else { return child }
        return AnyView(
            child.contentShape(Rectangle()).onTapGesture {
                payload.executeAction(actionFlow, triggerType: "onTap")
            }
        )
    }

    static func applySizing(
        payload: RenderPayload,
        style: CommonStyle,
        child: AnyView
    ) -> AnyView {
        let width = dimension(for: style.width, raw: style.widthRaw, payload: payload)
        let height = dimension(for: style.height, raw: style.heightRaw, payload: payload)

        var current = child

        if width.isIntrinsic || height.isIntrinsic {
            current = AnyView(
                current.fixedSize(
                    horizontal: width.isIntrinsic,
                    vertical: height.isIntrinsic
                )
            )
        }

        if width.isFill || height.isFill {
            current = AnyView(
                current.frame(
                    maxWidth: width.isFill ? .infinity : nil,
                    maxHeight: height.isFill ? .infinity : nil,
                    alignment: .topLeading
                )
            )
        }

        if width.value != nil || height.value != nil {
            current = AnyView(current.frame(width: width.value, height: height.value, alignment: .topLeading))
        }

        if width.percent != nil || height.percent != nil {
            current = AnyView(
                DigiaRelativeFrameView(
                    widthPercent: width.percent,
                    heightPercent: height.percent,
                    child: current
                )
            )
        }

        return current
    }

    static func dimension(
        for expr: ExprOr<Double>?,
        raw: String?,
        payload: RenderPayload
    ) -> ResolvedDimension {
        if let raw {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if trimmed == "intrinsic" {
                return ResolvedDimension(isIntrinsic: true)
            }
            if trimmed == "100%" {
                return ResolvedDimension(isFill: true)
            }
            if trimmed.hasSuffix("%"),
               let percent = Double(trimmed.dropLast()) {
                return ResolvedDimension(percent: percent / 100)
            }
            if let value = payload.eval(expr) ?? Double(trimmed) {
                return ResolvedDimension(value: value)
            }
        }

        if let value = payload.eval(expr) {
            return ResolvedDimension(value: value)
        }

        return ResolvedDimension()
    }

    static func resolveCornerRadius(
        _ rawValue: JSONValue?,
        payload: RenderPayload
    ) -> CornerRadiusProps? {
        resolveCornerRadius(rawValue, scopeContext: payload.scopeContext as any ExprContext)
    }

    static func resolveCornerRadius(
        _ rawValue: JSONValue?,
        scopeContext: (any ExprContext)?
    ) -> CornerRadiusProps? {
        guard let rawValue else { return nil }
        return To.cornerRadius(rawValue.deepEvaluate(in: scopeContext))
    }

    static func shape(for cornerRadius: CornerRadiusProps) -> AnyShape {
        if cornerRadius.isUniform {
            return AnyShape(RoundedRectangle(cornerRadius: cornerRadius.uniformValue, style: .continuous))
        }
        return AnyShape(DigiaRoundedRect(cornerRadius: cornerRadius))
    }

    static func loopExprContext(_ item: Any?, index: Int, refName: String?) -> any ScopeContext {
        let loopObject: [String: Any?] = [
            "currentItem": item,
            "index": index,
        ]
        var variables = loopObject
        if let refName {
            variables[refName] = loopObject
        }
        return BasicExprContext(variables: variables)
    }
}

struct ResolvedDimension: Equatable {
    let value: CGFloat?
    let isIntrinsic: Bool
    let isFill: Bool
    let percent: CGFloat?

    init(
        value: Double? = nil,
        isIntrinsic: Bool = false,
        isFill: Bool = false,
        percent: CGFloat? = nil
    ) {
        self.value = value.map { CGFloat($0) }
        self.isIntrinsic = isIntrinsic
        self.isFill = isFill
        self.percent = percent
    }
}

private struct DigiaRelativeFrameView: View {
    let widthPercent: CGFloat?
    let heightPercent: CGFloat?
    let child: AnyView

    var body: some View {
        GeometryReader { proxy in
            child.frame(
                width: widthPercent.map { proxy.size.width * $0 },
                height: heightPercent.map { proxy.size.height * $0 },
                alignment: .topLeading
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

private struct DigiaDecorationView: View {
    let payload: RenderPayload
    let backgroundColor: Color?
    let border: BorderStyle?
    let borderRadius: CornerRadiusProps?

    var body: some View {
        let shape = borderRadius.map { WidgetUtil.shape(for: $0) } ?? AnyShape(RoundedRectangle(cornerRadius: 0, style: .continuous))
        ZStack {
            if let backgroundColor {
                shape
                    .fill(backgroundColor)
            }

            if let border,
               let borderWidth = border.borderWidth,
               borderWidth > 0 {
                let strokeConfiguration = DigiaBorderStrokeConfiguration.resolve(border: border)
                shape
                    .stroke(
                        borderColor(border),
                        style: StrokeStyle(
                            lineWidth: borderWidth,
                            lineCap: strokeConfiguration.lineCap,
                            dash: strokeConfiguration.dashPattern
                        )
                    )
            }
        }
    }

    private func borderColor(_ border: BorderStyle) -> Color {
        payload.evalColor(border.borderColor) ?? .black
    }
}

struct DigiaBorderStrokeConfiguration: Equatable {
    let lineCap: CGLineCap
    let dashPattern: [CGFloat]

    static func resolve(border: BorderStyle) -> DigiaBorderStrokeConfiguration {
        let borderPattern = border.borderType?.borderPattern?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let borderWidth = CGFloat(border.borderWidth ?? 0)

        switch borderPattern {
        case "dotted":
            // Flutter's BorderWithPattern dotted implementation draws circular
            // dots spaced by (dot + 2 * dotSpacing). The closest StrokeStyle
            // approximation is a round-capped dash where the painted segment
            // is `thickness` and the gap is `2 * thickness`.
            let thickness = max(borderWidth, 1)
            return DigiaBorderStrokeConfiguration(
                lineCap: .round,
                dashPattern: [thickness, thickness * 2]
            )
        case "dashed":
            return DigiaBorderStrokeConfiguration(
                lineCap: To.strokeCap(border.borderType?.strokeCap),
                dashPattern: (border.borderType?.dashPattern ?? [3, 1]).map { CGFloat($0) }
            )
        default:
            return DigiaBorderStrokeConfiguration(
                lineCap: To.strokeCap(border.borderType?.strokeCap),
                dashPattern: []
            )
        }
    }
}
