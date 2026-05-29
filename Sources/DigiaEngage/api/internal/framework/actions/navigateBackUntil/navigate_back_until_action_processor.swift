import Foundation

struct NavigateBackUntilAction: Sendable {
    let actionType: ActionType = .navigateBackUntil
    let disableActionIf: ExprOr<Bool>?
    let data: [String: JSONValue]
}

@MainActor
struct NavigateBackUntilProcessor {
    let processorType: ActionType = .navigateBackUntil

    func execute(action: NavigateBackUntilAction, context: ActionProcessorContext) async throws {
        let target = action.data["routeNameToPopUntil"]?.deepEvaluate(in: context.scopeContext) as? String
        guard let target else { throw ActionExecutionError.unsupportedContext(processorType) }
        let normalizedTarget = NavigationUtil.normalizedRoute(target)
        SDKInstance.shared.navigationController.popUntil { current in
            let normalizedCurrent = NavigationUtil.normalizedRoute(current)
            if normalizedCurrent == normalizedTarget { return true }
            if normalizedCurrent == normalizedTarget.trimmingCharacters(in: CharacterSet(charactersIn: "/")) { return true }
            if let page = context.appConfig.page(normalizedCurrent) {
                if page.slug == normalizedTarget || "/\(page.slug ?? "")" == normalizedTarget {
                    return true
                }
            }
            return false
        }
        if !SDKInstance.shared.isHostMounted {
            ViewControllerUtil.popToRoot()
        }
    }
}
