import SwiftUI

struct ShowPipAction: Sendable {
    let actionType: ActionType = .showPip
    let disableActionIf: ExprOr<Bool>?
    let data: [String: JSONValue]
}

@MainActor
struct ShowPipProcessor {
    let processorType: ActionType = .showPip

    func execute(action: ShowPipAction, context: ActionProcessorContext) async throws {
        let d = action.data
        let sc = context.scopeContext

        func str(_ key: String) -> String? { d[key]?.deepEvaluate(in: sc) as? String }
        func bool(_ key: String, default def: Bool) -> Bool {
            (d[key]?.deepEvaluate(in: sc) as? Bool) ?? def
        }
        func dbl(_ key: String, default def: Double) -> Double {
            let v = d[key]?.deepEvaluate(in: sc)
            return (v as? Double) ?? (v as? Int).map(Double.init) ?? def
        }

        let componentId = str("componentId") ?? ""
        let videoUrl    = str("videoUrl")

        let args: [String: JSONValue]? = d["args"]?.objectValue

        let position = PipPosition.from(str("position"))

        let startX = CGFloat(dbl("startX", default: 0.7))
        let startY = CGFloat(dbl("startY", default: 0.1))

        let widthPt  = CGFloat(dbl("width",  default: dbl("widthPt",  default: 200)))
        let heightPt = CGFloat(dbl("height", default: dbl("heightPt", default: 120)))
        let cornerRadius = CGFloat(dbl("cornerRadius", default: 12))

        let backgroundColor = ColorUtil.fromString(str("backgroundColor")) ?? .black

        let showClose  = bool("showClose",  default: true)
        let expandable = bool("expandable", default: true)
        let autoPlay   = bool("autoPlay",   default: true)
        let looping    = bool("looping",    default: false)
        let muted      = bool("muted",      default: false)

        let delayMs       = dbl("delayMs",       default: 0)
        let autoDismissMs = dbl("autoDismissMs", default: 0)

        let closeOnScreenChange = bool("closeOnScreenChange", default: false)
        let animationDurationMs = dbl("animationDurationMs", default: 300)

        let screenFilter: PipScreenFilter? = {
            guard let sf = d["screenFilter"]?.objectValue else { return nil }
            let filterType: PipScreenFilter.FilterType =
                sf["type"]?.stringValue?.lowercased() == "whitelist" ? .whitelist : .blacklist
            let screens: Set<String> = {
                guard case let .array(arr) = sf["screens"] else { return [] }
                return Set(arr.compactMap { $0.stringValue })
            }()
            return PipScreenFilter(type: filterType, screenNames: screens)
        }()

        let dragBounds: PipDragBounds? = {
            guard let db = d["dragBounds"]?.objectValue else { return nil }
            func dbDbl(_ key: String, _ def: Double) -> CGFloat {
                let v = db[key]?.deepEvaluate(in: sc)
                return CGFloat((v as? Double) ?? (v as? Int).map(Double.init) ?? def)
            }
            return PipDragBounds(
                minXFraction: dbDbl("minX", 0),
                maxXFraction: dbDbl("maxX", 1),
                minYFraction: dbDbl("minY", 0),
                maxYFraction: dbDbl("maxY", 1)
            )
        }()

        let request = PipRequest(
            componentId: componentId,
            args: args,
            videoUrl: videoUrl,
            position: position,
            startX: startX,
            startY: startY,
            widthPt: widthPt,
            heightPt: heightPt,
            cornerRadius: cornerRadius,
            backgroundColor: backgroundColor,
            showClose: showClose,
            expandable: expandable,
            autoPlay: autoPlay,
            looping: looping,
            muted: muted,
            delayMs: delayMs,
            autoDismissMs: autoDismissMs,
            screenFilter: screenFilter,
            closeOnScreenChange: closeOnScreenChange,
            dragBounds: dragBounds,
            animationDurationMs: animationDurationMs
        )

        SDKInstance.shared.controller.showPip(request)
    }
}
