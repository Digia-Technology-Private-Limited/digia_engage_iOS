import SwiftUI
import AVKit

// MARK: - Event constants

enum PipEvent {
    static let shown        = "pip_shown"
    static let videoStarted = "pip_video_started"
    static let videoFailed  = "pip_video_failed"
    static let play         = "pip_play_clicked"
    static let pause        = "pip_pause_clicked"
    static let mute         = "pip_mute_clicked"
    static let unmute       = "pip_unmute_clicked"
    static let expand       = "pip_expand_clicked"
    static let collapse     = "pip_collapse_clicked"
    static let close        = "pip_close_clicked"
    static let dismissed    = "pip_dismissed"
}

// MARK: - Position preset (mirrors Apxor vi_position)

enum PipPosition: String {
    case topLeft     = "tl"
    case topRight    = "tr"
    case bottomLeft  = "bl"
    case bottomRight = "br"
    case center      = "c"

    func resolvedOrigin(pipSize: CGSize, screenSize: CGSize) -> CGPoint {
        let pw = pipSize.width, ph = pipSize.height
        let sw = screenSize.width, sh = screenSize.height
        switch self {
        case .topLeft:     return CGPoint(x: sw * 0.02, y: sh * 0.05)
        case .topRight:    return CGPoint(x: sw - pw - sw * 0.02, y: sh * 0.05)
        case .bottomLeft:  return CGPoint(x: sw * 0.02, y: sh - ph - sh * 0.08)
        case .bottomRight: return CGPoint(x: sw - pw - sw * 0.02, y: sh - ph - sh * 0.08)
        case .center:      return CGPoint(x: (sw - pw) / 2, y: (sh - ph) / 2)
        }
    }

    static func from(_ string: String?) -> PipPosition? {
        guard let s = string?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else { return nil }
        if s == "center" { return .center }
        return PipPosition(rawValue: s)
    }
}

// MARK: - Screen filter (mirrors Apxor restriction_type)

struct PipScreenFilter {
    enum FilterType { case whitelist, blacklist }
    let type: FilterType
    let screenNames: Set<String>

    func isAllowed(_ screen: String) -> Bool {
        switch type {
        case .whitelist: return screenNames.isEmpty || screenNames.contains(screen)
        case .blacklist: return !screenNames.contains(screen)
        }
    }
}

// MARK: - Drag bounds (Digia differentiator)

struct PipDragBounds {
    var minXFraction: CGFloat = 0
    var maxXFraction: CGFloat = 1
    var minYFraction: CGFloat = 0
    var maxYFraction: CGFloat = 1
}

// MARK: - PipRequest

struct PipRequest {
    // Content
    let componentId: String
    let args: [String: JSONValue]?
    let videoUrl: String?

    // Position
    let position: PipPosition?
    let startX: CGFloat
    let startY: CGFloat

    // Size
    let widthPt: CGFloat
    let heightPt: CGFloat
    let cornerRadius: CGFloat
    let backgroundColor: Color

    // Controls
    let showClose: Bool
    let expandable: Bool
    let autoPlay: Bool
    let looping: Bool
    let muted: Bool

    // Timing
    let delayMs: Double
    let autoDismissMs: Double

    // Screen
    let screenFilter: PipScreenFilter?
    let closeOnScreenChange: Bool

    // Drag
    let dragBounds: PipDragBounds?

    // Animation
    let animationDurationMs: Double

    // Callbacks
    let onEvent: ((String, [String: Any]) -> Void)?
    let onDismiss: ((Any?) -> Void)?

    init(
        componentId: String = "",
        args: [String: JSONValue]? = nil,
        videoUrl: String? = nil,
        position: PipPosition? = nil,
        startX: CGFloat = 0.7,
        startY: CGFloat = 0.1,
        widthPt: CGFloat = 200,
        heightPt: CGFloat = 120,
        cornerRadius: CGFloat = 12,
        backgroundColor: Color = .black,
        showClose: Bool = true,
        expandable: Bool = true,
        autoPlay: Bool = true,
        looping: Bool = false,
        muted: Bool = false,
        delayMs: Double = 0,
        autoDismissMs: Double = 0,
        screenFilter: PipScreenFilter? = nil,
        closeOnScreenChange: Bool = false,
        dragBounds: PipDragBounds? = nil,
        animationDurationMs: Double = 300,
        onEvent: ((String, [String: Any]) -> Void)? = nil,
        onDismiss: ((Any?) -> Void)? = nil
    ) {
        self.componentId        = componentId
        self.args               = args
        self.videoUrl           = videoUrl
        self.position           = position
        self.startX             = startX
        self.startY             = startY
        self.widthPt            = widthPt
        self.heightPt           = heightPt
        self.cornerRadius       = cornerRadius
        self.backgroundColor    = backgroundColor
        self.showClose          = showClose
        self.expandable         = expandable
        self.autoPlay           = autoPlay
        self.looping            = looping
        self.muted              = muted
        self.delayMs            = delayMs
        self.autoDismissMs      = autoDismissMs
        self.screenFilter       = screenFilter
        self.closeOnScreenChange = closeOnScreenChange
        self.dragBounds         = dragBounds
        self.animationDurationMs = animationDurationMs
        self.onEvent            = onEvent
        self.onDismiss          = onDismiss
    }
}
