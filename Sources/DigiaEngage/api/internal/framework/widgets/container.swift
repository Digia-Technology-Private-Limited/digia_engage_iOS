import SwiftUI

@MainActor
final class VWContainer: VirtualStatelessWidget<ContainerProps> {
    override func toWidget(_ payload: RenderPayload) -> AnyView {
        if payload.eval(commonProps?.visibility) == false {
            return empty()
        }

        var current = render(payload)
        current = WidgetUtil.wrapInAlign(value: commonProps?.align, child: current)
        current = WidgetUtil.wrapInTapGesture(payload: payload, actionFlow: commonProps?.onClick, child: current)

        if let margin = props.margin?.edgeInsets {
            current = AnyView(current.padding(margin))
        }

        return current
    }

    override func render(_ payload: RenderPayload) -> AnyView {
        let width = payload.eval(props.width).map { CGFloat($0) }
        let height = payload.eval(props.height).map { CGFloat($0) }
        let minWidth = payload.eval(props.minWidth).map { CGFloat($0) }
        let minHeight = payload.eval(props.minHeight).map { CGFloat($0) }
        let maxWidth = payload.eval(props.maxWidth).map { CGFloat($0) }
        let maxHeight = payload.eval(props.maxHeight).map { CGFloat($0) }
        let borderBorderRadius = WidgetUtil.resolveCornerRadius(props.border?.borderRadius, payload: payload)
        let cornerRadius: CornerRadiusProps? = props.borderRadius
            ?? borderBorderRadius
        let shape: AnyShape
        if props.shape == "circle" {
            shape = AnyShape(Circle())
        } else if let cr = cornerRadius {
            shape = AnyShape(DigiaRoundedRect(cornerRadius: cr))
        } else {
            shape = AnyShape(RoundedRectangle(cornerRadius: 0, style: .continuous))
        }
        let shouldFillWidth = width == nil && shouldFillAvailableWidth
        let shouldFillHeight = height == nil && shouldFillAvailableHeight
        let fallbackMinWidth: CGFloat? = child == nil && width == nil && hasVisibleDecoration ? 1 : nil
        let fallbackMinHeight: CGFloat? = child == nil && height == nil && hasVisibleDecoration ? 1 : nil
        let childAlignment = To.alignment(props.childAlignment)

        var content = child?.toWidget(payload)
            ?? AnyView(
                Color.clear.frame(
                    minWidth: fallbackMinWidth,
                    minHeight: fallbackMinHeight
                )
            )
        if let padding = props.padding?.edgeInsets {
            content = AnyView(content.padding(padding))
        }

        let hasBoundedHeight = shouldFillHeight || height != nil || maxHeight != nil || minHeight != nil

        if let alignment = childAlignment {
            content = AnyView(
                content.frame(
                    maxWidth: .infinity,
                    maxHeight: hasBoundedHeight ? .infinity : nil,
                    alignment: alignment
                )
            )
        }

        let resolvedMinWidth = max(minWidth ?? width ?? 0, fallbackMinWidth ?? 0)
        let resolvedMinHeight = max(minHeight ?? height ?? 0, fallbackMinHeight ?? 0)
        let resolvedMaxWidth = width ?? maxWidth ?? (childAlignment != nil ? .infinity : (shouldFillWidth ? .infinity : nil))
        let resolvedMaxHeight = height ?? maxHeight ?? (shouldFillHeight ? .infinity : nil)

        var current = AnyView(
            content.frame(
                minWidth: resolvedMinWidth,
                idealWidth: width,
                maxWidth: resolvedMaxWidth,
                minHeight: resolvedMinHeight,
                idealHeight: height,
                maxHeight: resolvedMaxHeight,
                alignment: .topLeading
            )
        )

        current = AnyView(
            current.background {
                decoratedBackground(payload: payload, shape: shape)
            }
        )

        if let border = props.border,
           let borderWidth = border.borderWidth,
           borderWidth > 0 {
            let strokeConfiguration = DigiaBorderStrokeConfiguration.resolve(border: border)
            current = AnyView(
                current.overlay {
                    shape.stroke(
                        payload.evalColor(border.borderColor) ?? .black,
                        style: StrokeStyle(
                            lineWidth: borderWidth,
                            lineCap: strokeConfiguration.lineCap,
                            dash: strokeConfiguration.dashPattern
                        )
                    )
                }
            )
        }

        return current
    }

    private var shouldFillAvailableWidth: Bool {
        if parent is VWGridView {
            return true
        }

        if let flexParent = parent as? VWFlex,
           flexParent.direction == .horizontal,
           parentProps?.expansion?.type == DigiaFlexFitType.tight.rawValue {
            return true
        }

        if let flexParent = parent as? VWFlex,
           flexParent.direction == .vertical,
           flexParent.props.crossAxisAlignment == "stretch" {
            return true
        }

        if let stackParent = parent as? VWStack {
            if stackParent.props.fit == "expand", parentProps?.position == nil {
                return true
            }

            if let position = parentProps?.position,
               position.left != nil,
               position.right != nil,
               props.width == nil {
                return true
            }
        }

        return false
    }

    private var shouldFillAvailableHeight: Bool {
        if parent is VWGridView {
            return true
        }

        if let flexParent = parent as? VWFlex,
           flexParent.direction == .vertical,
           parentProps?.expansion?.type == DigiaFlexFitType.tight.rawValue {
            return true
        }

        if let flexParent = parent as? VWFlex,
           flexParent.direction == .horizontal,
           flexParent.props.crossAxisAlignment == "stretch" {
            return true
        }

        if let stackParent = parent as? VWStack {
            if stackParent.props.fit == "expand", parentProps?.position == nil {
                return true
            }

            if let position = parentProps?.position,
               position.top != nil,
               position.bottom != nil,
               props.height == nil {
                return true
            }
        }

        return false
    }

    private var hasVisibleDecoration: Bool {
        props.color != nil ||
        !(props.gradiant?.resolvedColors?.isEmpty ?? true) ||
        (props.border?.borderWidth ?? 0) > 0 ||
        !(props.shadow?.isEmpty ?? true)
    }

    @ViewBuilder
    private func containerBackground(payload: RenderPayload, shape: AnyShape) -> some View {
        if let gradient = gradientView(payload: payload) {
            shape.fill(gradient)
        } else if let color = payload.evalColor(props.color) {
            shape.fill(color)
        }
    }

    private func decoratedBackground(payload: RenderPayload, shape: AnyShape) -> AnyView {
        var background = AnyView(containerBackground(payload: payload, shape: shape))

        if let elevation = props.elevation, elevation > 0 {
            background = AnyView(
                background.shadow(
                    color: Color.black.opacity(0.18),
                    radius: elevation,
                    x: 0,
                    y: elevation / 2
                )
            )
        }

        return AnyView(
            ZStack {
                if let shadows = props.shadow {
                    ForEach(Array(shadows.enumerated()), id: \.offset) { _, shadow in
                        self.shadowLayer(payload: payload, shape: shape, shadow: shadow)
                    }
                }
                background
            }
        )
    }

    private func gradientView(payload: RenderPayload) -> LinearGradient? {
        guard let gradient = props.gradiant else { return nil }
        let startPoint = To.unitPoint(gradient.begin) ?? .leading
        let endPoint = To.unitPoint(gradient.end) ?? .trailing

        if let colorList = gradient.colorList, !colorList.isEmpty {
            let resolved = colorList.compactMap { item -> (Color, Double?)? in
                guard let color = item.color.flatMap(payload.resolveColor) else { return nil }
                return (color, item.stop)
            }
            guard !resolved.isEmpty else { return nil }
            let hasPositions = resolved.contains { $0.1 != nil }
            let stops: [Gradient.Stop] = resolved.enumerated().map { idx, pair in
                let location: CGFloat = hasPositions
                    ? CGFloat(pair.1 ?? (Double(idx) / Double(max(resolved.count - 1, 1))))
                    : CGFloat(idx) / CGFloat(max(resolved.count - 1, 1))
                return Gradient.Stop(color: pair.0, location: location)
            }
            return LinearGradient(gradient: Gradient(stops: stops), startPoint: startPoint, endPoint: endPoint)
        }

        guard let colors = gradient.colors?.compactMap(payload.resolveColor), !colors.isEmpty else {
            return nil
        }
        return LinearGradient(colors: colors, startPoint: startPoint, endPoint: endPoint)
    }

    @ViewBuilder
    private func shadowLayer(payload: RenderPayload, shape: AnyShape, shadow: ShadowStyle) -> some View {
        let shadowColor = payload.evalColor(shadow.color) ?? Color.black.opacity(0.2)
        let blur = CGFloat(max(0, payload.eval(shadow.blur) ?? 0))
        let spread = CGFloat(payload.eval(shadow.spreadRadius) ?? 0)
        let x = CGFloat(payload.eval(shadow.offset?.x) ?? 0)
        let y = CGFloat(payload.eval(shadow.offset?.y) ?? 0)

        shape
            .fill(shadowColor)
            .padding(-spread)
            .blur(radius: blur)
            .offset(x: x, y: y)
            .allowsHitTesting(false)
    }
}

