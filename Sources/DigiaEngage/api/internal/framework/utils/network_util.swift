import Foundation

enum NetworkUtil {
    static func makeURL(_ value: String?) -> URL? {
        guard let value, !value.isEmpty else { return nil }
        return URL(string: value)
    }
}
