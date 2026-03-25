import SwiftUI

@MainActor
final class VWGridView: VirtualStatelessWidget<GridViewProps> {
    override func render(_ payload: RenderPayload) -> AnyView {
        guard let child else { return empty() }

        let items = resolveDataSource(payload: payload) ?? []
        let count = max(props.crossAxisCount ?? 2, 1)
        let spacing = props.mainAxisSpacing ?? 0
        let crossSpacing = props.crossAxisSpacing ?? 0

        if props.scrollDirection == "horizontal" {
            let rows = Array(repeating: GridItem(.flexible(), spacing: spacing), count: count)
            let content = AnyView(
                LazyHGrid(rows: rows, spacing: crossSpacing) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        child
                            .toWidget(payload.copyWithChainedContext(self.createExprContext(item, index: index)))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            )
            return props.allowScroll ?? true ? AnyView(ScrollView(.horizontal, showsIndicators: false) { content }) : content
        }

        let columns = Array(repeating: GridItem(.flexible(), spacing: crossSpacing), count: count)
        let content = AnyView(
            LazyVGrid(columns: columns, spacing: spacing) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    child
                        .toWidget(payload.copyWithChainedContext(self.createExprContext(item, index: index)))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        )

        return (props.allowScroll ?? true) ? AnyView(ScrollView(.vertical, showsIndicators: false) { content }) : content
    }

    private func resolveDataSource(payload: RenderPayload) -> [Any]? {
        switch props.dataSource {
        case let .array(values):
            return values.map(\.anyValue)
        case let .string(value):
            guard ExpressionUtil.hasExpression(value),
                  let resolved = ExpressionUtil.evaluateAny(value, context: payload.scopeContext) else {
                return nil
            }
            return resolved as? [Any]
        default:
            return nil
        }
    }

    private func createExprContext(_ item: Any?, index: Int) -> any ScopeContext {
        let gridObj: [String: Any?] = [
            "currentItem": item,
            "index": index,
        ]
        var variables = gridObj
        if let refName {
            variables[refName] = gridObj
        }
        return BasicExprContext(variables: variables)
    }
}
