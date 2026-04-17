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
        guard let text = (action.data["message"]?.deepEvaluate(in: context.scopeContext) as? String)
            ?? (action.data["text"]?.deepEvaluate(in: context.scopeContext) as? String)
            ?? (action.data["value"]?.deepEvaluate(in: context.scopeContext) as? String)
        else {
            throw ActionExecutionError.unsupportedContext(processorType)
        }
        SDKInstance.shared.copyToClipboard(text)
    }
}
