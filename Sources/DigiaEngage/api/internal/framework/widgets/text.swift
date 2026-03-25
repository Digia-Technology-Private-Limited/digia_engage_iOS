import SwiftUI
import UIKit

@MainActor
final class VWText: VirtualLeafStatelessWidget<TextProps> {
    override func render(_ payload: RenderPayload) -> AnyView {
        guard let text = payload.eval(props.text) else { return empty() }

        let font = payload.resources.font(textStyle: props.textStyle)
        let resolvedLineHeight = payload.resources.lineHeight(textStyle: props.textStyle)
        let resolvedFontSize = payload.resources.fontSize(textStyle: props.textStyle)
        let textColor = payload.evalColor(props.textStyle?.textColor) ?? .primary
        let backgroundColor = payload.evalColor(props.textStyle?.textBackgroundColor)
        let decoration = props.textStyle?.textDecoration?.lowercased()
        let decorationColor = payload.evalColor(props.textStyle?.textDecorationColor) ?? textColor
        let lineLimit = payload.eval(props.maxLines)
        let alignment = payload.eval(props.alignment)
        let overflow = payload.eval(props.overflow)
        let hasGradient = !(props.textStyle?.gradient?.colorList?.isEmpty ?? true)
        let shouldExpandForParentStretch = (parent as? VWFlex)?.direction == .vertical &&
            (parent as? VWFlex)?.props.crossAxisAlignment == "stretch"
        let shouldExpandToAvailableWidth = commonProps?.style?.widthRaw == "100%" ||
            commonProps?.style?.width != nil ||
            lineLimit == 1 ||
            shouldExpandForParentStretch

        if !hasGradient, overflow != "marquee" {
            return renderUIKitText(
                text: text,
                payload: payload,
                resolvedLineHeight: resolvedLineHeight,
                resolvedFontSize: resolvedFontSize,
                textColor: textColor,
                backgroundColor: backgroundColor,
                decoration: decoration,
                decorationColor: decorationColor,
                lineLimit: lineLimit,
                alignment: alignment,
                overflow: overflow,
                expandToAvailableWidth: shouldExpandToAvailableWidth
            )
        }

        return renderSwiftUIText(
            text: text,
            font: font,
            resolvedLineHeight: resolvedLineHeight,
            resolvedFontSize: resolvedFontSize,
            textColor: textColor,
            backgroundColor: backgroundColor,
            decoration: decoration,
            decorationColor: decorationColor,
            lineLimit: lineLimit,
            alignment: alignment,
            overflow: overflow,
            payload: payload,
            expandToAvailableWidth: shouldExpandToAvailableWidth
        )
    }

    private func renderSwiftUIText(
        text: String,
        font: Font,
        resolvedLineHeight: CGFloat?,
        resolvedFontSize: CGFloat?,
        textColor: Color,
        backgroundColor: Color?,
        decoration: String?,
        decorationColor: Color,
        lineLimit: Int?,
        alignment: String?,
        overflow: String?,
        payload: RenderPayload,
        expandToAvailableWidth: Bool
    ) -> AnyView {
        let base = Text(text)
            .font(font)
            .lineLimit(lineLimit)
            .multilineTextAlignment(To.textAlignment(alignment))

        var current: AnyView
        if let gradient = TextStyleUtil.makeTextGradient(from: props.textStyle?.gradient, resolveColor: payload.resolveColor) {
            current = AnyView(
                base
                    .foregroundColor(.clear)
                    .overlay(gradient.mask(base))
            )
        } else {
            current = AnyView(base.foregroundStyle(textColor))
        }

        if let resolvedLineHeight {
            let lineSpacing = max(0, resolvedLineHeight - (resolvedFontSize ?? resolvedLineHeight))
            current = AnyView(current.lineSpacing(lineSpacing))

            if lineLimit == 1 {
                current = AnyView(current.frame(minHeight: resolvedLineHeight, alignment: .center))
            }
        }

        current = TextStyleUtil.applyTextDecorations(
            to: current,
            backgroundColor: backgroundColor,
            decoration: decoration,
            decorationColor: decorationColor
        )

        switch overflow {
        case "ellipsis":
            current = AnyView(current.truncationMode(.tail))
        case "fade":
            current = AnyView(
                current.mask(
                    LinearGradient(
                        colors: [.black, .black, .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            )
        case "marquee" where lineLimit == 1:
            current = AnyView(
                InternalMarquee(duration: 11, gap: 100) {
                    current.fixedSize(horizontal: true, vertical: false)
                }
            )
        case "visible":
            current = AnyView(current)
        case "clip":
            current = AnyView(current.clipped())
        default:
            break
        }

        if expandToAvailableWidth {
            current = AnyView(current.frame(maxWidth: .infinity, alignment: To.alignment(alignment) ?? .leading))
        }

        return current
    }

    private func renderUIKitText(
        text: String,
        payload: RenderPayload,
        resolvedLineHeight: CGFloat?,
        resolvedFontSize: CGFloat?,
        textColor: Color,
        backgroundColor: Color?,
        decoration: String?,
        decorationColor: Color,
        lineLimit: Int?,
        alignment: String?,
        overflow: String?,
        expandToAvailableWidth: Bool
    ) -> AnyView {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = To.uiTextAlignment(alignment)
        paragraph.lineBreakMode = To.uiLineBreakMode(overflow)
        if let resolvedLineHeight {
            paragraph.minimumLineHeight = resolvedLineHeight
            paragraph.maximumLineHeight = resolvedLineHeight
        }

        var attributes: [NSAttributedString.Key: Any] = [
            .font: payload.resources.uiFont(textStyle: props.textStyle),
            .foregroundColor: UIColor(textColor),
            .paragraphStyle: paragraph,
        ]

        if let backgroundColor {
            attributes[.backgroundColor] = UIColor(backgroundColor)
        }
        if decoration == "underline" {
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
            attributes[.underlineColor] = UIColor(decorationColor)
        }
        if decoration == "linethrough" || decoration == "strikethrough" {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            attributes[.strikethroughColor] = UIColor(decorationColor)
        }

        var current = AnyView(
            InternalTextLabel(
                attributedText: NSAttributedString(string: text, attributes: attributes),
                alignment: paragraph.alignment,
                numberOfLines: lineLimit ?? 0,
                lineBreakMode: paragraph.lineBreakMode,
                clipsToBounds: overflow != "visible",
                expandToAvailableWidth: expandToAvailableWidth
            )
        )

        current = TextStyleUtil.applyTextDecorations(
            to: current,
            backgroundColor: nil,
            decoration: decoration == "overline" ? "overline" : nil,
            decorationColor: decorationColor
        )

        if overflow == "fade" {
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

        if let minHeight = resolvedLineHeight ?? resolvedFontSize {
            current = AnyView(current.frame(minHeight: minHeight, alignment: .center))
        }

        if expandToAvailableWidth {
            current = AnyView(current.frame(maxWidth: .infinity, alignment: .leading))
        }

        return current
    }

}
