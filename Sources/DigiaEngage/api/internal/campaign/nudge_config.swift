import Foundation

// Ported from Android `NudgeConfig.kt`. A nudge campaign's `templateConfig.layout`
// is the exact native DUI `VWData` tree (root `digia/column`); it is decoded straight
// into the recursive renderer with no translation.

enum NudgeTemplateType: String, Equatable, Sendable {
    case bottomSheet
    case dialog

    static func from(_ value: String?) -> NudgeTemplateType {
        value == "dialog" ? .dialog : .bottomSheet
    }

    /// Analytics `display_style` value carried alongside nudge events.
    var displayStyle: String {
        switch self {
        case .bottomSheet: return "bottom_sheet"
        case .dialog: return "dialog"
        }
    }
}

struct NudgeContainerConfig: Equatable, Sendable {
    var bgColor: String = "#FFFFFF"
    var cornerRadius: CGFloat = 16
    var padding: CGFloat = 16
    var dismissOnOutsideTap: Bool = true
    var scrimColor: String = "#66000000"
    /// Bottom-sheet only: max height as a fraction of screen height.
    var maxHeightRatio: CGFloat = 0.7
    /// Bottom-sheet only: show the drag handle + enable drag-to-dismiss.
    var dragHandle: Bool = true
    /// Dialog only: width in points; nil = a sensible default width.
    var width: CGFloat?

    static func fromJson(_ json: [String: Any]?) -> NudgeContainerConfig {
        guard let json else { return NudgeContainerConfig() }
        var config = NudgeContainerConfig()
        config.bgColor = json.string("bgColor", default: config.bgColor)
        config.cornerRadius = CGFloat(json.double("cornerRadius", default: Double(config.cornerRadius)))
        config.padding = CGFloat(json.double("padding", default: Double(config.padding)))
        config.dismissOnOutsideTap = json.bool("dismissOnOutsideTap", default: config.dismissOnOutsideTap)
        config.scrimColor = json.string("scrimColor", default: config.scrimColor)
        config.maxHeightRatio = CGFloat(json.double("maxHeightRatio", default: Double(config.maxHeightRatio)))
        config.dragHandle = json.bool("dragHandle", default: config.dragHandle)
        if json["width"] != nil {
            config.width = CGFloat(json.double("width", default: 0))
        }
        return config
    }
}

struct NudgeConfig: Equatable, Sendable {
    let templateType: NudgeTemplateType
    let container: NudgeContainerConfig
    let layout: VWData

    static func fromJson(_ json: [String: Any]) -> NudgeConfig? {
        guard let layoutDict = json.object("layout") else { return nil }
        guard
            let data = try? JSONSerialization.data(withJSONObject: layoutDict),
            let layout = try? JSONDecoder().decode(VWData.self, from: data)
        else { return nil }
        return NudgeConfig(
            templateType: NudgeTemplateType.from(json.string("templateType")),
            container: NudgeContainerConfig.fromJson(json.object("container")),
            layout: layout
        )
    }
}

/// Active nudge state held on the overlay controller and rendered by `NudgeOverlayView`.
struct DigiaNudgePresentation: Equatable, Sendable {
    let config: NudgeConfig
    let payload: InAppPayload
}
