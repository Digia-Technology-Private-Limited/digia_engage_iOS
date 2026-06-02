import Foundation

struct OpenUrlAction: Sendable {
    let actionType: ActionType = .openUrl
    let disableActionIf: ExprOr<Bool>?
    let data: [String: JSONValue]
}

@MainActor
struct OpenUrlProcessor {
    let processorType: ActionType = .openUrl

    func execute(action: OpenUrlAction, context: ActionProcessorContext) async throws {
        guard let rawURL = action.data["url"]?.deepEvaluate(in: context.scopeContext) as? String,
              let url = URL(string: rawURL),
              url.scheme != nil
        else { throw ActionExecutionError.unsupportedContext(processorType) }
        SDKInstance.shared.openURL(url)
    }
}
