import Foundation

struct StreamBuilderProps: Codable, Equatable, Sendable {
    let controller: JSONValue?
    let initialData: JSONValue?
    let onSuccess: ActionFlow?
    let onError: ActionFlow?
}
