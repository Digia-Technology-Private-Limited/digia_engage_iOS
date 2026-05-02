import Foundation

// MARK: - ShowTooltipAction

struct ShowTooltipAction: Sendable {
    let actionType: ActionType = .showTooltip
    let disableActionIf: ExprOr<Bool>?
    let data: [String: JSONValue]
}

// MARK: - ShowTooltipProcessor

@MainActor
struct ShowTooltipProcessor {
    func execute(action: ShowTooltipAction, context: ActionProcessorContext) async throws {
        let d  = action.data
        let sc = context.scopeContext

        func str(_ key: String) -> String? { d[key]?.deepEvaluate(in: sc) as? String }

        let componentId   = str("componentId") ?? ""
        let targetKey = str("placementKey")
        let arrowColorHex = str("arrowColor") ?? "#FFFF00"
        let position      = TooltipPosition.from(str("position"))
        let args: [String: JSONValue]? = d["args"]?.objectValue

        let request = TooltipRequest(
            componentId:   componentId,
            args:          args,
            targetKey:     targetKey,
            position:      .above,
            arrowColorHex: arrowColorHex
        )

        SDKInstance.shared.controller.showTooltip(request)
    }
}

// MARK: - DismissTooltipAction

struct DismissTooltipAction: Sendable {
    let actionType: ActionType = .dismissTooltip
    let disableActionIf: ExprOr<Bool>?
    let data: [String: JSONValue]
}

// MARK: - DismissTooltipProcessor

@MainActor
struct DismissTooltipProcessor {
    func execute(action: DismissTooltipAction, context: ActionProcessorContext) async throws {
        SDKInstance.shared.controller.dismissTooltip()
    }
}
