import Foundation

extension JSONValue {
    var stringValue: String? {
        guard case let .string(value) = self else { return nil }
        return value
    }

    var objectValue: [String: JSONValue]? {
        guard case let .object(value) = self else { return nil }
        return value
    }
}

extension Dictionary where Key == String, Value == JSONValue {
    func string(_ key: String) -> String? {
        guard case let .string(value)? = self[key] else { return nil }
        return value
    }

    func int(_ key: String) -> Int? {
        switch self[key] {
        case let .int(value):
            return value
        case let .string(value):
            return Int(value)
        default:
            return nil
        }
    }

    func object(_ key: String) -> [String: JSONValue]? {
        guard case let .object(value)? = self[key] else { return nil }
        return value
    }
}
