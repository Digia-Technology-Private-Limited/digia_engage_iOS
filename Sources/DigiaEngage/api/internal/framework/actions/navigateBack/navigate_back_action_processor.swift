import Foundation

struct NavigateBackAction: Sendable {
    let actionType: ActionType = .navigateBack
    let disableActionIf: ExprOr<Bool>?
    let data: [String: JSONValue]
}

@MainActor
struct NavigateBackProcessor {
    let processorType: ActionType = .navigateBack

    func execute(action: NavigateBackAction, context: ActionProcessorContext) async throws {
        let maybe = (ExpressionUtil.evaluateNestedExpressionsToAny(
            action.data["maybe"], in: context.scopeContext
        ) as? Bool) ?? false

        let result = action.data["result"].map {
            ExpressionUtil.evaluateNestedExpressions($0, in: context.scopeContext)
        }

        let overlayController = SDKInstance.shared.controller
        let navController = SDKInstance.shared.navigationController

        // If a modal is active, dismiss it (with result) rather than popping the page stack.
        if overlayController.activeDialog != nil {
            overlayController.dismissDialog(result: result)
            ViewControllerUtil.dismissPresented()
            return
        }
        if overlayController.activeBottomSheet != nil {
            overlayController.dismissBottomSheet(result: result)
            ViewControllerUtil.dismissPresented()
            return
        }

        // Navigate back within the SwiftUI navigation stack.
        if maybe && navController.path.isEmpty { return }
        navController.pop(result: result)

        // Fallback for UIKit-embedded navigation only when host navigation is not mounted.
        if navController.path.isEmpty && !SDKInstance.shared.isHostMounted {
            ViewControllerUtil.popNavigation()
        }
    }
}
