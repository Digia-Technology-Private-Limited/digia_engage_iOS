import Foundation

struct SetStateAction: Sendable {
    let actionType: ActionType = .setState
    let disableActionIf: ExprOr<Bool>?
    let data: [String: JSONValue]
}

@MainActor
struct SetStateProcessor {
    let processorType: ActionType = .setState

    func execute(action: SetStateAction, context: ActionProcessorContext) async throws {
        guard let targetStore = targetStore(for: action, context: context) else {
            throw ActionExecutionError.unsupportedContext(processorType)
        }

        guard case let .array(updateArray)? = action.data["updates"] else {
            throw ActionExecutionError.unsupportedContext(processorType)
        }

        let rebuild = (ExpressionUtil.evaluateNestedExpressionsToAny(action.data["rebuild"], in: context.scopeContext) as? Bool) ?? false
        var updates: [String: JSONValue] = [:]
        for item in updateArray {
            guard case let .object(update)? = Optional(item) else { continue }
            guard let stateName = update.string("stateName") ?? update.string("key") else { continue }
            let value = ExpressionUtil.evaluateNestedExpressions(update["newValue"] ?? update["value"] ?? .null, in: context.scopeContext)
            updates[stateName] = value
        }

        targetStore.setValues(updates, notify: rebuild)
    }

    private func targetStore(for action: SetStateAction, context: ActionProcessorContext) -> StateContext? {
        if let name = action.data.string("stateContextName") {
            return SDKInstance.shared.localStateStore(named: name)
        }
        return context.localStateStore
    }
}
