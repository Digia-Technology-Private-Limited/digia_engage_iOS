import Foundation

struct ShowToastAction: Sendable {
    let actionType: ActionType = .showToast
    let disableActionIf: ExprOr<Bool>?
    let data: [String: JSONValue]
}

@MainActor
struct ShowToastProcessor {
    let processorType: ActionType = .showToast
    func execute(action: ShowToastAction, context: ActionProcessorContext) async throws {
        let resolvedMessage = ExpressionUtil.evaluateNestedExpressionsToAny(action.data["message"], in: context.scopeContext)
        let message = resolvedMessage.map { value -> String in
            if let string = value as? String { return string }
            return String(describing: value)
        } ?? ""
        guard !message.isEmpty else { return }

        let durationSeconds = (ExpressionUtil.evaluateNestedExpressionsToAny(action.data["duration"], in: context.scopeContext) as? Double)
            ?? (ExpressionUtil.evaluateNestedExpressionsToAny(action.data["duration"], in: context.scopeContext) as? Int).map(Double.init)
            ?? 2

        SDKInstance.shared.controller.showToast(
            DigiaToastPresentation(
                message: message,
                durationSeconds: max(durationSeconds, 0)
            )
        )
    }
}
