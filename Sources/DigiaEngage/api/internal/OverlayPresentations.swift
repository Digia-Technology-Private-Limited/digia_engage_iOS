import SwiftUI

struct DigiaViewPresentation: Equatable, Sendable {
    let viewID: String
    let title: String?
    let text: String?
    let args: [String: JSONValue]
}

struct DigiaToastPresentation: Equatable, Sendable {
    let message: String
    let durationSeconds: Double
}

struct DigiaBottomSheetPresentation: Equatable, Sendable {
    let view: DigiaViewPresentation
    let barrierColor: Color
    let maxHeight: Double
    let sheetBackgroundColor: Color?
    let cornerRadius: CornerRadiusProps
    let borderColor: Color?
    let borderWidth: CGFloat?
    let borderStyle: String?
    let useSafeArea: Bool
    let showDragHandle: Bool

    init(
        view: DigiaViewPresentation,
        barrierColor: Color = Color.black.opacity(0.54),
        maxHeight: Double = 9.0 / 16.0,
        sheetBackgroundColor: Color? = nil,
        cornerRadius: CornerRadiusProps? = nil,
        borderColor: Color? = nil,
        borderWidth: CGFloat? = nil,
        borderStyle: String? = nil,
        useSafeArea: Bool = true,
        showDragHandle: Bool = false
    ) {
        self.view = view
        self.barrierColor = barrierColor
        self.maxHeight = maxHeight
        self.sheetBackgroundColor = sheetBackgroundColor
        self.cornerRadius = cornerRadius
            ?? CornerRadiusProps(topLeft: 28, topRight: 28, bottomRight: 0, bottomLeft: 0)
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.borderStyle = borderStyle
        self.useSafeArea = useSafeArea
        self.showDragHandle = showDragHandle
    }

    var effectiveBorderWidth: CGFloat {
        let style = borderStyle?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let isSolid = style == nil || style == "solid"
        guard isSolid else { return 0 }
        if let borderWidth, borderWidth > 0 { return borderWidth }
        if borderColor != nil { return 1 }
        return 0
    }

    var shouldDrawBorder: Bool {
        effectiveBorderWidth > 0 && borderColor != nil
    }
}

struct DigiaDialogPresentation: Equatable, Sendable {
    let view: DigiaViewPresentation
    let barrierDismissible: Bool
    let barrierColor: Color

    init(
        view: DigiaViewPresentation,
        barrierDismissible: Bool = true,
        barrierColor: Color = Color.black.opacity(0.54)
    ) {
        self.view = view
        self.barrierDismissible = barrierDismissible
        self.barrierColor = barrierColor
    }
}
