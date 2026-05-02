import SwiftUI

// MARK: - DigiaCoordinateSpaceName

/// The named SwiftUI coordinate space anchored on the DigiaHost ZStack.
/// Both digiaLabel (frame registration) and TooltipOverlay (bubble positioning)
/// use this name so they share the same origin without relying on .global.
enum DigiaCoordinateSpaceName {
    static let overlay = "digia_overlay"
}

// MARK: - TooltipPosition

enum TooltipPosition: String {
    case above = "above"
    case below = "below"
    case left  = "left"
    case right = "right"
    case auto  = "auto"

    static func from(_ string: String?) -> TooltipPosition {
        guard let s = string?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else { return .auto }
        return TooltipPosition(rawValue: s) ?? .auto
    }
}

// MARK: - TooltipRequest

struct TooltipRequest {
    let componentId: String
    let args: [String: JSONValue]?
    let targetKey: String?
    let position: TooltipPosition
    let arrowColorHex: String
    let onDismiss: ((Any?) -> Void)?

    init(
        componentId: String,
        args: [String: JSONValue]? = nil,
        targetKey: String? = nil,
        position: TooltipPosition = .auto,
        arrowColorHex: String = "#FFFFFF",
        onDismiss: ((Any?) -> Void)? = nil
    ) {
        self.componentId   = componentId
        self.args          = args
        self.targetKey     = targetKey
        self.position      = position
        self.arrowColorHex = arrowColorHex
        self.onDismiss     = onDismiss
    }
}
