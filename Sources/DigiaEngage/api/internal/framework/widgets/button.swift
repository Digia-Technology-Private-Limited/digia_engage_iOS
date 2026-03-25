import SwiftUI

@MainActor
final class VWButton: VirtualLeafStatelessWidget<ButtonProps> {
    override func render(_ payload: RenderPayload) -> AnyView {
        let isDisabled = payload.eval(props.isDisabled) ?? (props.onClick == nil)
        let style = isDisabled ? props.disabledStyle : props.defaultStyle
        let disabledStyle = props.disabledStyle
        let font = payload.resources.font(textStyle: props.text?.textStyle)
        let resolvedLineHeight = payload.resources.lineHeight(textStyle: props.text?.textStyle)

        // Match Flutter's background resolution:
        // - Disabled uses disabledStyle.backgroundColor when provided
        // - Enabled uses defaultStyle.backgroundColor
        // - Otherwise fall back to Material-like defaults
        let background: Color = {
            if isDisabled, let disabledBg = disabledStyle?.backgroundColor {
                return payload.resolveColor(disabledBg)
                    ?? Self.materialDisabledBackground
            }
            if let normalBg = style?.backgroundColor {
                return payload.resolveColor(normalBg)
                    ?? Self.materialSurfaceContainerLow
            }
            return isDisabled ? Self.materialDisabledBackground : Self.materialSurfaceContainerLow
        }()
        let foreground = payload.resolveColor(isDisabled ? disabledStyle?.disabledTextColor : props.text?.textStyle?.textColor)
            ?? payload.resolveColor("contentPrimary")
            ?? .primary
        let contentText = payload.eval(props.text?.text) ?? "Button"
        // Use the same default padding as Flutter's button implementation
        let padding = style?.padding?.edgeInsets
            ?? EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12)
        let width = payload.eval(style?.width).map { CGFloat($0) }
        let height = payload.eval(style?.height).map { CGFloat($0) }
        let shape = resolvedShape()
        let elevation = isDisabled ? 0 : (style?.elevation ?? 0)
        let shadowColor = payload.resolveColor(style?.shadowColor) ?? .black.opacity(0.18)
        let alignment = To.alignment(style?.alignment) ?? .center
        let resolvedWidth = width.map { max($0, Self.minimumSize.width) }
        let resolvedHeight = height.map { max($0, Self.minimumSize.height) }
        // Match Flutter button sizing:
        // - explicit fill width strings still expand
        // - otherwise a button only fills when the parent column stretches children
        let widthIsFillPercent = widthSpecifiedAsFill(style: style)
        let shouldFillWidth = resolvedWidth == nil && (
            widthIsFillPercent ||
            shouldFillWidthInParentFlex()
        )

        return AnyView(
            Button {
                // Avoid SwiftUI's default disabled opacity by handling
                // the disabled state manually.
                guard !isDisabled else { return }
                payload.executeAction(self.props.onClick, triggerType: "onPressed")
            } label: {
                makeLabel(
                    payload: payload,
                    contentText: contentText,
                    font: font,
                    resolvedLineHeight: resolvedLineHeight,
                    foreground: foreground,
                    padding: padding,
                    alignment: alignment,
                    resolvedWidth: resolvedWidth,
                    resolvedHeight: resolvedHeight,
                    shouldFillWidth: shouldFillWidth
                )
                    .background(background)
                    .clipShape(shape)
                    .overlay(shape.stroke(borderColor(payload: payload), lineWidth: borderLineWidth))
                    .shadow(
                        color: elevation > 0 ? shadowColor : .clear,
                        radius: CGFloat(elevation),
                        x: 0,
                        y: CGFloat(max(1, elevation / 2))
                    )
                    .contentShape(shape)
                    .frame(
                        minWidth: Self.minimumTapTarget.width,
                        minHeight: Self.minimumTapTarget.height,
                        alignment: .center
                    )
            }
            .allowsHitTesting(!isDisabled)
            .buttonStyle(.plain)
        )
    }

    private func makeLabel(
        payload: RenderPayload,
        contentText: String,
        font: Font,
        resolvedLineHeight: CGFloat?,
        foreground: Color,
        padding: EdgeInsets,
        alignment: Alignment,
        resolvedWidth: CGFloat?,
        resolvedHeight: CGFloat?,
        shouldFillWidth: Bool
    ) -> AnyView {
        let reservedLeadingWidth = reservedIconSlotWidth(for: props.leadingIcon)
        let reservedTrailingWidth = reservedIconSlotWidth(for: props.trailingIcon)

        var label = AnyView(
            HStack(spacing: 0) {
                if let reservedLeadingWidth {
                    Color.clear
                        .frame(width: reservedLeadingWidth, height: 1)
                        .accessibilityHidden(true)
                }

                Group {
                    let text = Text(contentText)
                        .font(font)
                        .foregroundStyle(foreground)
                        .lineLimit(payload.eval(props.text?.maxLines) ?? 1)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(minHeight: resolvedLineHeight, alignment: .center)
                        .layoutPriority(1)

                    if payload.eval(props.text?.overflow) == "ellipsis" {
                        text.truncationMode(.tail)
                    } else {
                        text
                    }
                }
                .frame(maxWidth: shouldFillWidth ? .infinity : nil, alignment: alignment)

                if let reservedTrailingWidth {
                    Color.clear
                        .frame(width: reservedTrailingWidth, height: 1)
                        .accessibilityHidden(true)
                }
            }
            .padding(padding)
            .frame(
                minWidth: Self.minimumSize.width,
                minHeight: Self.materialMinimumHeight,
                alignment: alignment
            )
        )

        if shouldFillWidth {
            label = AnyView(label.frame(maxWidth: .infinity, alignment: alignment))
        }

        return AnyView(label.frame(width: resolvedWidth, height: resolvedHeight, alignment: alignment))
    }

    private func reservedIconSlotWidth(for icon: ButtonIconProps?) -> CGFloat? {
        guard let icon else { return nil }
        return CGFloat(max(icon.iconSize ?? 24, 0))
    }

    private var borderLineWidth: CGFloat {
        guard props.shape?.borderStyle == "solid" else { return 0 }
        return CGFloat(props.shape?.borderWidth ?? 1)
    }

    private func borderColor(payload: RenderPayload) -> Color {
        guard borderLineWidth > 0 else { return .clear }
        return payload.resolveColor(props.shape?.borderColor) ?? .clear
    }

    private func resolvedShape() -> AnyShape {
        switch props.shape?.value {
        case "stadium":
            return AnyShape(Capsule())
        case "circle":
            return AnyShape(Circle())
        case "roundedRect":
            let radius = CGFloat(props.shape?.borderRadius?.edgeInsets.top ?? 0)
            return AnyShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        default:
            return AnyShape(Capsule())
        }
    }

    /// Returns true when the style's width is specified as a fill percentage (e.g. "100%").
    private func widthSpecifiedAsFill(style: ButtonVisualStyle?) -> Bool {
        guard case .expression(let raw) = style?.width else { return false }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed == "100%" || trimmed == "fill"
    }

    /// Matches Flutter's behavior where a button in a vertical Column fills width
    /// only when the parent stretches children across the cross axis.
    func shouldFillWidthInParentFlex() -> Bool {
        guard let flexParent = parent as? VWFlex else { return false }
        if flexParent.direction == .vertical {
            return flexParent.props.crossAxisAlignment == "stretch"
        }
        return false
    }

    private static let minimumSize = CGSize(width: 64, height: 40)
    private static let materialMinimumHeight: CGFloat = 40
    private static let minimumTapTarget = CGSize(width: 48, height: 48)
    private static let materialSurfaceContainerLow = Color(red: 247 / 255, green: 242 / 255, blue: 250 / 255)
    private static let materialDisabledBackground = Color(red: 29 / 255, green: 27 / 255, blue: 32 / 255).opacity(0.12)
}

