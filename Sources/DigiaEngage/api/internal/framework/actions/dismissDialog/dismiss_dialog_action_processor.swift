import Foundation

struct DismissDialogAction: Sendable {
    let actionType: ActionType = .dismissDialog
    let disableActionIf: ExprOr<Bool>?
    let data: [String: JSONValue]
}

@MainActor
struct DismissDialogProcessor {
    let processorType: ActionType = .dismissDialog

    func execute(action: DismissDialogAction, context: ActionProcessorContext) async throws {
        let result = action.data["result"].map {
            ExpressionUtil.evaluateNestedExpressions($0, in: context.scopeContext)
        }
        // A rendered nudge dialog uses its own overlay channel, not the DSL dialog
        // manager. Route its dismiss buttons to the nudge dismissal.
        if SDKInstance.shared.controller.activeNudge != nil {
            SDKInstance.shared.controller.dismissNudge()
            return
        }
        SDKInstance.shared.controller.dismissDialog(result: result)
        SDKInstance.shared.didDismissDialog()
        ViewControllerUtil.dismissPresented()
    }
}
