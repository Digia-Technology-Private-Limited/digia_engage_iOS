import Foundation

enum ActionExecutionError: Error, LocalizedError {
    case unsupportedContext(ActionType)

    var errorDescription: String? {
        switch self {
        case let .unsupportedContext(type):
            return "Action \(type.rawValue) requires runtime context that is not available on iOS yet."
        }
    }
}
