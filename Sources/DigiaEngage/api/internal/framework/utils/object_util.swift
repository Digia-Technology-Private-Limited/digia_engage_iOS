import Foundation

enum ObjectUtil {
    static func cast<T>(_ value: Any?, as type: T.Type = T.self) -> T? {
        value as? T
    }
}
