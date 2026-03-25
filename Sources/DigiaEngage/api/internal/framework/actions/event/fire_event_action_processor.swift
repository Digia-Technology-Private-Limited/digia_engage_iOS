import Foundation

struct FireEventAction: Sendable {
    let actionType: ActionType = .fireEvent
    let disableActionIf: ExprOr<Bool>?
    let data: [String: JSONValue]
}

@MainActor
struct FireEventProcessor {
    let processorType: ActionType = .fireEvent

    func execute(action: FireEventAction, context _: ActionProcessorContext) async throws {
        guard let payload = SDKInstance.shared.controller.activePayload else {
            throw ActionExecutionError.unsupportedContext(processorType)
        }

        if case let .array(events)? = action.data["events"] {
            for item in events {
                guard case let .object(object) = item,
                      let name = object.string("name") else { continue }
                let event: DigiaExperienceEvent
                switch name.lowercased() {
                case "impressed": event = .impressed
                case "dismissed": event = .dismissed
                default: event = .clicked(elementID: object.string("elementId") ?? name)
                }
                SDKInstance.shared.controller.onEvent?(event, payload)
            }
            return
        }

        guard let eventName = action.data.string("eventName") else {
            throw ActionExecutionError.unsupportedContext(processorType)
        }
        let mappedEvent: DigiaExperienceEvent
        switch eventName.lowercased() {
        case "impressed": mappedEvent = .impressed
        case "dismissed": mappedEvent = .dismissed
        default: mappedEvent = .clicked(elementID: action.data.string("elementId"))
        }
        SDKInstance.shared.controller.onEvent?(mappedEvent, payload)
    }
}
