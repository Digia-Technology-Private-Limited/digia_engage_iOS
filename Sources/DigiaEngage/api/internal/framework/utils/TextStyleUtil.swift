import SwiftUI
import UIKit

@MainActor
enum TextStyleUtil {
    private static let fallbackDescriptor = FontDescriptorProps(
        fontFamily: nil,
        weight: "regular",
        size: 14,
        height: 1.5,
        isItalic: false,
        style: false
    )

    static func font(
        textStyle: TextStyleProps?,
        appConfigStore: AppConfigStore,
        fontFactory: DUIFontFactory
    ) -> Font {
        font(
            descriptor: resolvedFontDescriptor(textStyle: textStyle, appConfigStore: appConfigStore),
            fontFactory: fontFactory
        )
    }

    static func font(
        descriptor: FontDescriptorProps?,
        fontFactory: DUIFontFactory
    ) -> Font {
        let size = descriptor?.size ?? 17
        let weight = To.fontWeight(descriptor?.weight)
        let italic = descriptor?.isItalic == true || descriptor?.style == true

        if let family = descriptor?.fontFamily, !family.isEmpty {
            return fontFactory.getFont(family, size: size, weight: weight, italic: italic)
        }

        return fontFactory.getDefaultFont(size: size, weight: weight, italic: italic)
    }

    static func uiFont(
        textStyle: TextStyleProps?,
        appConfigStore: AppConfigStore,
        fontFactory: DUIFontFactory
    ) -> UIFont {
        uiFont(
            descriptor: resolvedFontDescriptor(textStyle: textStyle, appConfigStore: appConfigStore),
            fontFactory: fontFactory
        )
    }

    static func uiFont(
        descriptor: FontDescriptorProps?,
        fontFactory: DUIFontFactory
    ) -> UIFont {
        let size = descriptor?.size ?? 17
        let weight = To.fontWeight(descriptor?.weight)
        let italic = descriptor?.isItalic == true || descriptor?.style == true

        if let family = descriptor?.fontFamily, !family.isEmpty {
            return fontFactory.getUIFont(family, size: size, weight: weight, italic: italic)
        }
        return fontFactory.getDefaultUIFont(size: size, weight: weight, italic: italic)
    }

    static func lineHeight(
        textStyle: TextStyleProps?,
        appConfigStore: AppConfigStore
    ) -> CGFloat? {
        guard let descriptor = resolvedFontDescriptor(textStyle: textStyle, appConfigStore: appConfigStore),
              let size = descriptor.size,
              let height = descriptor.height else {
            return nil
        }

        return CGFloat(size * height)
    }

    static func fontSize(
        textStyle: TextStyleProps?,
        appConfigStore: AppConfigStore
    ) -> CGFloat? {
        guard let descriptor = resolvedFontDescriptor(textStyle: textStyle, appConfigStore: appConfigStore),
              let size = descriptor.size else {
            return nil
        }

        return CGFloat(size)
    }

    static func resolvedFontDescriptor(
        textStyle: TextStyleProps?,
        appConfigStore: AppConfigStore
    ) -> FontDescriptorProps? {
        if let token = textStyle?.fontToken?.value,
           let tokenDescriptor = appConfigStore.themeFont(named: token) {
            return tokenDescriptor
        }

        if let inlineDescriptor = textStyle?.fontToken?.font,
           hasAnyInlineFontValue(inlineDescriptor) {
            return inlineDescriptor
        }

        return fallbackDescriptor
    }

    private static func hasAnyInlineFontValue(_ descriptor: FontDescriptorProps) -> Bool {
        descriptor.fontFamily != nil ||
            descriptor.weight != nil ||
            descriptor.size != nil ||
            descriptor.height != nil ||
            descriptor.isItalic != nil ||
            descriptor.style != nil
    }

    static func applyTextDecorations(
        to view: AnyView,
        backgroundColor: Color?,
        decoration: String?,
        decorationColor: Color
    ) -> AnyView {
        var current = view
        if decoration == "underline" {
            current = AnyView(current.underline(true, color: decorationColor))
        }
        if decoration == "linethrough" || decoration == "strikethrough" {
            current = AnyView(current.strikethrough(true, color: decorationColor))
        }
        if let backgroundColor {
            current = AnyView(current.background(backgroundColor))
        }
        if decoration == "overline" {
            current = AnyView(
                current.overlay(alignment: .topLeading) {
                    Rectangle()
                        .fill(decorationColor)
                        .frame(height: 1)
                        .offset(y: -1)
                }
            )
        }
        return current
    }

    static func makeTextGradient(
        from gradient: TextGradientProps?,
        resolveColor: (String?) -> Color?
    ) -> LinearGradient? {
        guard let gradient,
              let stops = gradient.colorList,
              !stops.isEmpty else {
            return nil
        }
        let colors = stops.compactMap { resolveColor($0.color) }
        guard !colors.isEmpty else { return nil }
        return LinearGradient(
            colors: colors,
            startPoint: To.unitPoint(gradient.begin) ?? .top,
            endPoint: To.unitPoint(gradient.end) ?? .bottom
        )
    }
}
