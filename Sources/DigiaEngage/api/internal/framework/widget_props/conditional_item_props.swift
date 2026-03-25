import Foundation

struct ConditionalItemProps: Codable, Equatable, Sendable {
    let condition: ExprOr<Bool>?
}
