import Foundation

struct HideBottomSheetAction: Sendable {
    let actionType: ActionType = .hideBottomSheet
    let disableActionIf: ExprOr<Bool>?
    let data: [String: JSONValue]
}

@MainActor
struct HideBottomSheetProcessor {
    let processorType: ActionType = .hideBottomSheet

    func execute(action: HideBottomSheetAction, context: ActionProcessorContext) async throws {
        let result = action.data["result"].map {
            ExpressionUtil.evaluateNestedExpressions($0, in: context.scopeContext)
        }
        SDKInstance.shared.controller.dismissBottomSheet(result: result)
        SDKInstance.shared.didDismissBottomSheet()
        ViewControllerUtil.dismissPresented()
    }
}
