import Foundation

struct RebuildStateAction: Sendable {
    let actionType: ActionType = .rebuildState
    let disableActionIf: ExprOr<Bool>?
    let data: [String: JSONValue]
}

@MainActor
struct RebuildStateProcessor {
    let processorType: ActionType = .rebuildState

    func execute(action: RebuildStateAction, context: ActionProcessorContext) async throws {
        let targetStore: StateContext?
        if let name = action.data.string("stateContextName") {
            targetStore = SDKInstance.shared.localStateStore(named: name)
        } else {
            targetStore = context.localStateStore
        }
        guard let targetStore else {
            throw ActionExecutionError.unsupportedContext(processorType)
        }
        targetStore.triggerListeners()
    }
}
