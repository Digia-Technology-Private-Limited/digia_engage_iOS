import Foundation

struct SetAppStateAction: Sendable {
    let actionType: ActionType = .setAppState
    let disableActionIf: ExprOr<Bool>?
    let data: [String: JSONValue]
}

@MainActor
struct SetAppStateProcessor {
    let processorType: ActionType = .setAppState

    func execute(action: SetAppStateAction, context: ActionProcessorContext) async throws {
        if let key = action.data.string("stateKey") ?? action.data.string("key") {
            let value = resolveDynamicValue(action.data["value"] ?? .null, context: context.scopeContext)
            try SDKInstance.shared.setAppState(key: key, value: value)
            return
        }

        if case let .array(updates)? = action.data["updates"] {
            for update in updates {
                guard case let .object(updateObject) = update else { continue }
                guard let key = updateObject.string("stateName")
                    ?? updateObject.string("stateKey")
                    ?? updateObject.string("key") else { continue }
                let value = resolveDynamicValue(updateObject["newValue"] ?? updateObject["value"] ?? .null, context: context.scopeContext)
                do {
                    try SDKInstance.shared.setAppState(key: key, value: value)
                } catch {
                    continue
                }
            }
            return
        }

        throw ActionExecutionError.unsupportedContext(processorType)
    }

    private func resolveDynamicValue(_ value: JSONValue, context: (any ExprContext)?) -> JSONValue {
        let resolved = ExpressionUtil.evaluateNestedExpressions(value, in: context)
        if resolved != value {
            return resolved
        }
        guard case let .string(raw) = value,
              raw.hasPrefix("${"),
              raw.hasSuffix("}") else {
            return resolved
        }
        let inner = String(raw.dropFirst(2).dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        if let number = NSExpression(format: inner).expressionValue(with: nil, context: nil) {
            return ExpressionUtil.jsonValue(from: number)
        }
        return resolved
    }
}
