import Foundation

enum DateUtil {
    static func parseISO8601(_ value: String) -> Date? {
        ISO8601DateFormatter().date(from: value)
    }
}
