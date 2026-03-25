import DigiaExpr

/// Extends BasicExprContext (from DigiaExpr) to satisfy ScopeContext.
/// copyAndExtend creates a new DefaultScopeContext with the extra variables, chaining self as enclosing.
extension BasicExprContext: ScopeContext {
    func copyAndExtend(newVariables: [String: Any?]) -> any ScopeContext {
        DefaultScopeContext(name: name, variables: newVariables, enclosing: self)
    }
}
