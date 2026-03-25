import DigiaExpr
import Foundation

protocol DigiaValueStream: AnyObject, Sendable {
    var currentValue: Any? { get }
    @discardableResult
    func subscribe(_ onValue: @escaping @Sendable (Any?) -> Void) -> UUID
    func unsubscribe(_ token: UUID)
}

final class AppStateValueStream: DigiaValueStream, ExprInstance, @unchecked Sendable {
    private var listeners: [UUID: @Sendable (Any?) -> Void] = [:]
    private(set) var currentValue: Any?

    init(currentValue: Any?) {
        self.currentValue = currentValue
    }

    @discardableResult
    func subscribe(_ onValue: @escaping @Sendable (Any?) -> Void) -> UUID {
        let token = UUID()
        listeners[token] = onValue
        return token
    }

    func unsubscribe(_ token: UUID) {
        listeners.removeValue(forKey: token)
    }

    func publish(_ value: Any?) {
        currentValue = value
        for listener in listeners.values {
            listener(value)
        }
    }

    func getField(_ name: String) throws -> ExprValue? {
        switch name {
        case "value":
            return ExprValue.from(currentValue)
        default:
            throw ExpressionError.undefinedProperty(name)
        }
    }
}

final class AppStateExprContext: ScopeContext {
    let name: String = "appState"
    var enclosing: (any ExprContext)?
    private let values: [String: Any?]
    private let streams: [String: Any?]

    init(values: [String: Any?], streams: [String: Any?], enclosing: (any ExprContext)? = nil) {
        self.values = values
        self.streams = streams
        self.enclosing = enclosing
    }

    func getValue(_ key: String) -> ExprLookupResult {
        if key == "appState" {
            let merged = values.merging(streams) { _, rhs in rhs }
            return ExprLookupResult(found: true, value: .map(merged.mapValues { ExprValue.from($0) }))
        }

        if let value = values[key] {
            return ExprLookupResult(found: true, value: ExprValue.from(value))
        }

        if let stream = streams[key] {
            return ExprLookupResult(found: true, value: ExprValue.from(stream))
        }

        return enclosing?.getValue(key) ?? ExprLookupResult(found: false, value: nil)
    }

    func copyAndExtend(newVariables: [String: Any?]) -> any ScopeContext {
        DefaultScopeContext(name: name, variables: newVariables, enclosing: self)
    }
}
