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
        let resolvedMessage = action.data["message"]?.deepEvaluate(in: context.scopeContext)
        let message = resolvedMessage.map { value -> String in
            if let string = value as? String { return string }
            return String(describing: value)
        } ?? ""
        guard !message.isEmpty else { return }

        let rawDuration = action.data["duration"]?.deepEvaluate(in: context.scopeContext)
        let durationSeconds = (rawDuration as? Double) ?? (rawDuration as? Int).map(Double.init) ?? 2

        SDKInstance.shared.controller.showToast(
            DigiaToastPresentation(
                message: message,
                durationSeconds: max(durationSeconds, 0)
            )
        )
    }
}
