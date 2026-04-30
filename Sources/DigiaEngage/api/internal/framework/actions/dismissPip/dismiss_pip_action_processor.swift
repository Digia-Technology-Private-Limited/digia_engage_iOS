import Foundation

struct DismissPipAction: Sendable {
    let actionType: ActionType = .dismissPip
    let disableActionIf: ExprOr<Bool>?
    let data: [String: JSONValue]
}

@MainActor
struct DismissPipProcessor {
    let processorType: ActionType = .dismissPip

    func execute(action: DismissPipAction, context: ActionProcessorContext) async throws {
        SDKInstance.shared.controller.dismissPip()
    }
}
