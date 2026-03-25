import Foundation

struct WrapProps: Decodable, Equatable, Sendable {
    let dataSource: JSONValue?
    let spacing: ExprOr<Double>?
    let wrapAlignment: ExprOr<String>?
    let wrapCrossAlignment: ExprOr<String>?
    let direction: ExprOr<String>?
    let runSpacing: ExprOr<Double>?
    let runAlignment: ExprOr<String>?
    let verticalDirection: ExprOr<String>?
    let clipBehavior: ExprOr<String>?
}
