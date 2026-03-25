import Foundation

struct SizedBoxProps: Codable, Equatable, Sendable {
    var width: ExprOr<Double>? = nil
    var height: ExprOr<Double>? = nil
}
