import Foundation

/// Pure builders that assemble the engage-event-matrix `properties` map for each
/// rendered campaign type, using the exact matrix snake_case keys. Free functions
/// (no SwiftUI/SDK-state dependencies) so the error-prone mapping logic is
/// unit-tested in isolation; renderers/orchestrators call these at the
/// `AnalyticsService.capture(eventName:payload:properties:)` site.
///
/// Mirrors the Android `EngageMatrix.kt` / Flutter `engage_matrix.dart`. Optional
/// keys are omitted entirely when their source is nil — keeps the on-wire payload
/// tight (the analytics service strips nothing, so builders must be precise).
enum EngageMatrix {

    /// Maps a `NudgeAction` to the matrix `action_type` token.
    static func actionTypeToken(_ action: NudgeAction) -> String {
        switch action {
        case .openUrl: return "url"
        case .openDeeplink: return "deeplink"
        case .dismiss: return "dismiss"
        case .share, .copyToClipboard: return "custom"
        }
    }

    /// The matrix `action_url` for an action, or nil for actions without a target.
    static func actionUrlOf(_ action: NudgeAction) -> String? {
        switch action {
        case .openUrl(let url), .openDeeplink(let url): return url
        default: return nil
        }
    }

    /// Properties for a nudge `Digia Experience Viewed`. `displayStyle` is required
    /// (`bottom_sheet` | `dialog`); trigger/screen context included only when known.
    static func nudgeViewed(
        displayStyle: String,
        screenName: String? = nil,
        triggerType: String? = nil,
        triggerEvent: String? = nil
    ) -> [String: Any] {
        var p: [String: Any] = ["display_style": displayStyle]
        if let screenName { p["screen_name"] = screenName }
        if let triggerType { p["trigger_type"] = triggerType }
        if let triggerEvent { p["trigger_event"] = triggerEvent }
        return p
    }

    /// Properties for a nudge `Digia Experience Clicked`. `element_id` is synthesised
    /// from the button's role (`cta_primary` / `cta_secondary`). `action_type`/
    /// `action_url` come from the button's first action.
    static func nudgeClicked(
        label: String,
        isPrimary: Bool,
        actions: [NudgeAction],
        timeToActionMs: Int? = nil
    ) -> [String: Any] {
        let position = isPrimary ? "primary" : "secondary"
        var p: [String: Any] = [
            "element_id": "cta_\(position)",
            "cta_label": label,
            "cta_position": position,
        ]
        if let action = actions.first {
            p["action_type"] = actionTypeToken(action)
            if let url = actionUrlOf(action) { p["action_url"] = url }
        }
        if let timeToActionMs { p["time_to_action_ms"] = timeToActionMs }
        return p
    }

    /// Properties for a nudge `Digia Experience Dismissed`. Both fields optional —
    /// surfaced only when the presentation layer knows the cause / view-time.
    static func nudgeDismissed(
        dismissReason: String? = nil,
        timeToDismissMs: Int? = nil
    ) -> [String: Any] {
        var p: [String: Any] = [:]
        if let dismissReason { p["dismiss_reason"] = dismissReason }
        if let timeToDismissMs { p["time_to_dismiss_ms"] = timeToDismissMs }
        return p
    }

    /// Properties for an inline/guide/survey container `Digia Experience Viewed`.
    /// `displayStyle` is `carousel` | `story` | `tooltip` | `spotlight` | `standard`;
    /// `itemTotal` is the slide/story/step/question count.
    static func containerViewed(
        displayStyle: String,
        itemTotal: Int,
        screenName: String? = nil,
        triggerType: String? = nil,
        triggerEvent: String? = nil
    ) -> [String: Any] {
        var p: [String: Any] = [
            "display_style": displayStyle,
            "item_total": itemTotal,
        ]
        if let screenName { p["screen_name"] = screenName }
        if let triggerType { p["trigger_type"] = triggerType }
        if let triggerEvent { p["trigger_event"] = triggerEvent }
        return p
    }

    /// Properties shared by `Digia Step Viewed` / `Step Clicked` / `Step Dismissed`
    /// (inline frames and guide steps): the 0-based `itemIndex` within `itemTotal`,
    /// the container `displayStyle`, plus optional server `itemId` and (for clicks)
    /// the resolved `actionType`/`actionUrl`.
    static func step(
        displayStyle: String,
        itemIndex: Int,
        itemTotal: Int,
        itemId: String? = nil,
        actionType: String? = nil,
        actionUrl: String? = nil
    ) -> [String: Any] {
        var p: [String: Any] = [
            "display_style": displayStyle,
            "item_index": itemIndex,
            "item_total": itemTotal,
        ]
        if let itemId { p["item_id"] = itemId }
        if let actionType { p["action_type"] = actionType }
        if let actionUrl { p["action_url"] = actionUrl }
        return p
    }

    /// Properties for an `Digia Experience Completed` (a story/guide played through
    /// all frames/steps). `timeToCompleteMs` included only when known.
    static func completed(
        displayStyle: String,
        itemTotal: Int,
        timeToCompleteMs: Int? = nil
    ) -> [String: Any] {
        var p: [String: Any] = [
            "display_style": displayStyle,
            "item_total": itemTotal,
        ]
        if let timeToCompleteMs { p["time_to_complete_ms"] = timeToCompleteMs }
        return p
    }

    /// Properties for a survey `Digia Question Viewed` / `Question Answered` /
    /// `Question Skipped`: the 0-based `questionIndex` within `questionTotal` and the
    /// server `questionId`/`questionType`.
    static func question(
        questionIndex: Int,
        questionTotal: Int,
        questionId: String? = nil,
        questionType: String? = nil
    ) -> [String: Any] {
        var p: [String: Any] = [
            "item_index": questionIndex,
            "item_total": questionTotal,
        ]
        if let questionId { p["question_id"] = questionId }
        if let questionType { p["question_type"] = questionType }
        return p
    }
}
