import Foundation

typealias JsonLike = [String: Any]

/// Mirrors Flutter's NodeType enum in types.dart.
enum NodeType: String {
    case widget
    case component

    static func fromString(_ raw: String?) -> NodeType {
        NodeType(rawValue: raw ?? "") ?? .widget
    }
}

private struct ExpressionObject: Decodable {
    let expr: String
}

enum ExprOr<Value: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
    case value(Value)
    case expression(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let value = try? container.decode(Value.self) {
            self = .value(value)
            return
        }

        if let expressionObject = try? container.decode(ExpressionObject.self) {
            self = .expression(expressionObject.expr)
            return
        }

        let expressionString = try container.decode(String.self)
        self = .expression(expressionString)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case let .value(value):
            try container.encode(value)
        case let .expression(expression):
            try container.encode(expression)
        }
    }
}

extension ExprOr where Value == String {
    func evaluate(in context: (any ExprContext)?) -> String? {
        switch self {
        case let .value(value):
            if ExpressionUtil.hasExpression(value) {
                if let resolved = ExpressionUtil.evaluateAny(value, context: context) {
                    return resolved as? String ?? String(describing: resolved)
                }
            }
            return value
        case let .expression(expression):
            if let resolved = ExpressionUtil.evaluateAny(expression, context: context) {
                return resolved as? String ?? String(describing: resolved)
            }
            return nil
        }
    }
}

extension ExprOr where Value == Bool {
    func evaluate(in context: (any ExprContext)?) -> Bool? {
        switch self {
        case let .value(value):
            return value
        case let .expression(expression):
            if let resolved = ExpressionUtil.evaluateAny(expression, context: context) {
                if let value = resolved as? Bool { return value }
                if let value = resolved as? String { return Bool(value) }
            }
            return nil
        }
    }
}

extension ExprOr where Value == Int {
    func evaluate(in context: (any ExprContext)?) -> Int? {
        switch self {
        case let .value(value):
            return value
        case let .expression(expression):
            if let resolved = ExpressionUtil.evaluateAny(expression, context: context) {
                if let value = resolved as? Int { return value }
                if let value = resolved as? Double { return Int(value) }
                if let value = resolved as? String { return Int(value) }
            }
            return nil
        }
    }
}

extension ExprOr where Value == Double {
    func evaluate(in context: (any ExprContext)?) -> Double? {
        switch self {
        case let .value(value):
            return value
        case let .expression(expression):
            if let resolved = ExpressionUtil.evaluateAny(expression, context: context) {
                if let value = resolved as? Double { return value }
                if let value = resolved as? Int { return Double(value) }
                if let value = resolved as? String { return Double(value) }
            }
            return nil
        }
    }
}

extension JSONValue {
    func deepEvaluate(in context: (any ExprContext)?) -> Any? {
        ExpressionUtil.evaluateNestedExpressionsToAny(self, in: context)
    }
}
