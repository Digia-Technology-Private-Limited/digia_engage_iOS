import DigiaExpr
import Foundation

// Module-wide typealiases so other files don't need to import DigiaExpr directly.
typealias ExprContext = DigiaExpr.ExprContext
typealias BasicExprContext = DigiaExpr.BasicExprContext
typealias ExprLookupResult = DigiaExpr.ExprLookupResult
typealias ExprValue = DigiaExpr.ExprValue
typealias ExprInstance = DigiaExpr.ExprInstance
typealias ExpressionError = DigiaExpr.ExpressionError

/// Mirrors Flutter's ExpressionUtil from expression_util.dart.
/// Also absorbs JSONValueResolver (Flutter's evaluateNestedExpressions).
enum ExpressionUtil {

    /// Returns true if the string contains or is an expression placeholder.
    static func hasExpression(_ value: Any?) -> Bool {
        guard let str = value as? String else { return false }
        return Expression.hasExpression(str) || Expression.isExpression(str)
    }

    /// Evaluates a raw expression string and casts to the requested type.
    static func evaluateExpression<T>(_ source: String, context: (any ExprContext)?) -> T? {
        try? Expression.eval(source, context) as? T
    }

    /// Evaluates an arbitrary value: if it is a String containing an expression, resolve it;
    /// otherwise cast directly to T.
    static func evaluate<T>(_ value: Any?, context: (any ExprContext)?) -> T? {
        if let str = value as? String, hasExpression(str) {
            return evaluateExpression(str, context: context)
        }
        return value as? T
    }

    /// Evaluates an expression string and returns the raw untyped result.
    static func evaluateAny(_ source: String, context: (any ExprContext)?) -> Any? {
        try? Expression.eval(source, context)
    }

    // MARK: - JSONValue recursive resolution (from json_value_resolver.swift)

    /// Recursively walks a JSONValue tree and resolves any embedded expression strings.
    static func evaluateNestedExpressions(_ value: JSONValue, in context: (any ExprContext)?) -> JSONValue {
        switch value {
        case let .string(raw):
            guard Expression.hasExpression(raw) || Expression.isExpression(raw) else {
                return .string(raw)
            }
            do {
                let resolved = try Expression.eval(raw, context)
                return jsonValue(from: resolved)
            } catch {
                return .string(raw)
            }
        case let .array(items):
            return .array(items.map { evaluateNestedExpressions($0, in: context) })
        case let .object(items):
            return .object(items.mapValues { evaluateNestedExpressions($0, in: context) })
        default:
            return value
        }
    }

    /// Same as `evaluateNestedExpressions` but returns `Any?` for the top-level string case,
    /// allowing expressions that resolve to non-string types.
    static func evaluateNestedExpressionsToAny(_ value: JSONValue?, in context: (any ExprContext)?) -> Any? {
        guard let value else { return nil }
        switch value {
        case let .string(raw):
            guard Expression.hasExpression(raw) || Expression.isExpression(raw) else {
                return raw
            }
            return try? Expression.eval(raw, context)
        default:
            return evaluateNestedExpressions(value, in: context).anyValue
        }
    }

    // MARK: - Any? → JSONValue conversion (companion to evaluateNestedExpressions)

    static func jsonValue(from value: Any?) -> JSONValue {
        switch value {
        case let v as JSONValue:
            return v
        case let v as String:
            return .string(v)
        case let v as Int:
            return .int(v)
        case let v as Int64:
            return .int(Int(v))
        case let v as Int32:
            return .int(Int(v))
        case let v as Double:
            return .double(v)
        case let v as Float:
            return .double(Double(v))
        case let v as Bool:
            return .bool(v)
        case let v as NSNumber:
            let d = v.doubleValue
            return floor(d) == d ? .int(v.intValue) : .double(d)
        case let v as [Any?]:
            return .array(v.map { jsonValue(from: $0) })
        case let v as [String: Any?]:
            return .object(v.mapValues { jsonValue(from: $0) })
        case nil:
            return .null
        default:
            return .string(String(describing: value))
        }
    }
}
