import Foundation

struct Variable: Decodable, Equatable, Sendable {
    let type: String
    let defaultValue: JSONValue?

    enum CodingKeys: String, CodingKey {
        case type
        case `default`
        case defaultValue
    }

    init(type: String, defaultValue: JSONValue?) {
        self.type = type
        self.defaultValue = defaultValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        defaultValue = try container.decodeIfPresent(JSONValue.self, forKey: .default)
            ?? container.decodeIfPresent(JSONValue.self, forKey: .defaultValue)
    }

    func resolvedValue(in context: (any ExprContext)?) -> JSONValue {
        let fallback = defaultValue ?? defaultValueForType(type)
        return ExpressionUtil.evaluateNestedExpressions(fallback, in: context)
    }

    private func defaultValueForType(_ rawType: String) -> JSONValue {
        switch rawType.lowercased() {
        case "number", "numeric":
            return .int(0)
        case "bool", "boolean":
            return .bool(false)
        case "json":
            return .object([:])
        case "list", "array":
            return .array([])
        default:
            return .string("")
        }
    }
}
