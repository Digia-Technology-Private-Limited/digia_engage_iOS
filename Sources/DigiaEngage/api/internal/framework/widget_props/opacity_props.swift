import Foundation

struct OpacityProps: Decodable, Equatable, Sendable {
    let alwaysIncludeSemantics: ExprOr<Bool>?
    let opacity: ExprOr<Double>?
}
