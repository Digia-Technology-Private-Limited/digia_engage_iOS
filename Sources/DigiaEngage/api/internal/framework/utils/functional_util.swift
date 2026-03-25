import Foundation

enum Functional {
    static func identity<T>(_ value: T) -> T {
        value
    }
}

extension Optional {
    func maybe<T>(_ transform: (Wrapped) throws -> T?) rethrows -> T? {
        guard let wrapped = self else { return nil }
        return try transform(wrapped)
    }
}
