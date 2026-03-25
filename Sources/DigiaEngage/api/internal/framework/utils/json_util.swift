import Foundation

enum JsonUtil {
    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try JSONDecoder().decode(T.self, from: data)
    }

    static func tryDecode<T: Decodable>(_ type: T.Type, from data: Data) -> T? {
        try? JSONDecoder().decode(T.self, from: data)
    }

    static func object(from data: Data) throws -> JsonLike {
        guard let object = try JSONSerialization.jsonObject(with: data) as? JsonLike else {
            throw NSError(domain: "Digia.JsonUtil", code: 1)
        }
        return object
    }

    /// Returns the value for the first key found in `json`, optionally transformed by `parse`.
    static func tryKeys<T>(_ json: JsonLike, _ keys: [String], parse: ((Any?) -> T?)? = nil) -> T? {
        for key in keys {
            if let value = json[key] {
                return parse != nil ? parse?(value) : value as? T
            }
        }
        return nil
    }
}
