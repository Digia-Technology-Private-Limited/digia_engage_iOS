import SwiftUI
import UIKit

@MainActor
struct ResourceProvider {
    let fontFactory: DUIFontFactory
    let appConfigStore: AppConfigStore

    /// Resolves a color string to a SwiftUI Color.
    /// Checks the design token map first, then falls back to direct hex/rgba parsing.
    func getColor(_ value: String?) -> Color? {
        guard let value, !value.isEmpty else { return nil }
        if let tokenHex = appConfigStore.themeColor(named: value) {
            return ColorUtil.fromString(tokenHex)
        }
        return ColorUtil.fromString(value)
    }

    func font(textStyle: TextStyleProps?) -> Font {
        TextStyleUtil.font(textStyle: textStyle, appConfigStore: appConfigStore, fontFactory: fontFactory)
    }

    func uiFont(textStyle: TextStyleProps?) -> UIFont {
        TextStyleUtil.uiFont(textStyle: textStyle, appConfigStore: appConfigStore, fontFactory: fontFactory)
    }

    func lineHeight(textStyle: TextStyleProps?) -> CGFloat? {
        TextStyleUtil.lineHeight(textStyle: textStyle, appConfigStore: appConfigStore)
    }

    func fontSize(textStyle: TextStyleProps?) -> CGFloat? {
        TextStyleUtil.fontSize(textStyle: textStyle, appConfigStore: appConfigStore)
    }
}
