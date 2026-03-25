import Foundation

struct FlexProps: Codable, Equatable, Sendable {
    var spacing: Double? = nil
    var startSpacing: Double? = nil
    var endSpacing: Double? = nil
    var mainAxisAlignment: String? = nil
    var crossAxisAlignment: String? = nil
    var mainAxisSize: String? = nil
    var isScrollable: Bool? = nil
    var dataSource: JSONValue? = nil
}
