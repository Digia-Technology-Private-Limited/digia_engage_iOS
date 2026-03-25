import Foundation

struct DelayAction: Sendable {
    let actionType: ActionType = .delay
    let disableActionIf: ExprOr<Bool>?
    let data: [String: JSONValue]
}

@MainActor
struct DelayProcessor {
    let processorType: ActionType = .delay

    func execute(action: DelayAction, context _: ActionProcessorContext) async throws {
        let ms = action.data.int("durationInMs") ?? action.data.int("delayInMs") ?? action.data.int("duration") ?? 0
        if ms > 0 {
            try await Task.sleep(nanoseconds: UInt64(ms) * 1_000_000)
        }
    }
}
