import DigiaExpr
import Foundation

/// Mirrors Flutter's StateScopeContext.
final class StateScopeContext: ScopeContext {
    let name: String
    var enclosing: (any ExprContext)?

    private let stateContext: StateContext
    private let variables: [String: Any?]

    init(
        stateContext: StateContext,
        variables: [String: Any?] = [:],
        enclosing: (any ExprContext)? = nil
    ) {
        self.stateContext = stateContext
        self.variables = variables
        self.enclosing = enclosing
        name = stateContext.namespace ?? ""
    }

    func getValue(_ key: String) -> ExprLookupResult {
        if let value = variables[key] {
            return ExprLookupResult(found: true, value: ExprValue.from(value))
        }

        if key == "state" || (!name.isEmpty && key == name) {
            return ExprLookupResult(found: true, value: .map(stateContext.stateVariables.mapValues { ExprValue.from($0.anyValue) }))
        }

        if let value = stateContext.getValue(key) {
            return ExprLookupResult(found: true, value: ExprValue.from(value.anyValue))
        }

        return enclosing?.getValue(key) ?? ExprLookupResult(found: false, value: nil)
    }

    func copyAndExtend(newVariables: [String: Any?]) -> any ScopeContext {
        DefaultScopeContext(name: name, variables: newVariables, enclosing: self)
    }
}
