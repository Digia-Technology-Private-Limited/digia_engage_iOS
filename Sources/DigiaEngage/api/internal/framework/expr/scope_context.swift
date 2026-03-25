import DigiaExpr

/// Mirrors Flutter's ScopeContext abstract class.
/// A named, chainable expression evaluation context.
protocol ScopeContext: ExprContext {
    func copyAndExtend(newVariables: [String: Any?]) -> any ScopeContext
}