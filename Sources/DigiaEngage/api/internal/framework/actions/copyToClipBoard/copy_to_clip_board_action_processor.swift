import Foundation

struct CopyToClipBoardAction: Sendable {
    let actionType: ActionType = .copyToClipBoard
    let disableActionIf: ExprOr<Bool>?
    let data: [String: JSONValue]
}

@MainActor
struct CopyToClipBoardProcessor {
    let processorType: ActionType = .copyToClipBoard

    func execute(action: CopyToClipBoardAction, context: ActionProcessorContext) async throws {
        guard let text = (ExpressionUtil.evaluateNestedExpressionsToAny(action.data["message"], in: context.scopeContext) as? String)
            ?? (ExpressionUtil.evaluateNestedExpressionsToAny(action.data["text"], in: context.scopeContext) as? String)
            ?? (ExpressionUtil.evaluateNestedExpressionsToAny(action.data["value"], in: context.scopeContext) as? String)
        else {
            throw ActionExecutionError.unsupportedContext(processorType)
        }
        SDKInstance.shared.copyToClipboard(text)
    }
}
