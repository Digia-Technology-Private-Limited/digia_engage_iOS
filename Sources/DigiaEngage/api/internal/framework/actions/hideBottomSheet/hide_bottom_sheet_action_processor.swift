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
        let controller = SDKInstance.shared.controller
        // A rendered nudge bottom sheet uses its own overlay channel, not the DSL
        // bottom-sheet manager. Route its dismiss buttons to the nudge dismissal.
        if controller.activeNudge != nil {
            controller.dismissNudge()
            return
        }
        if let transition = controller.bottomSheetTransition {
            transition.animateDismiss {
                if controller.bottomSheetRendersInHost {
                    controller.dismissBottomSheet(result: result)
                    SDKInstance.shared.didDismissBottomSheet()
                } else {
                    ViewControllerUtil.dismissPresented(animated: false) {
                        controller.dismissBottomSheet(result: result)
                        SDKInstance.shared.didDismissBottomSheet()
                    }
                }
            }
        } else {
            controller.dismissBottomSheet(result: result)
            SDKInstance.shared.didDismissBottomSheet()
            if !controller.bottomSheetRendersInHost {
                ViewControllerUtil.dismissPresented(animated: true)
            }
        }
    }
}
